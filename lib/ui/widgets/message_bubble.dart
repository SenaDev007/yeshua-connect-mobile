/// Bulle d'un message : moi (pourpre clair, à droite) / autre (nuit
/// éclairci, à gauche, avec avatar + prénom en groupe).
///
/// Les CALL_LOG s'affichent en pastille centrée — même rendu que le web.
///
/// ⭐ V3.21 — Pièces jointes (image/vidéo/fichier), notes vocales (lecture
/// intégrée), sondages (vote), réactions CLIQUABLES (toggle), badge
/// « modifié », pastille épinglée — parité complète du web.
library;

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/message_model.dart';
import 'avatar_widget.dart';
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSender; // afficher avatar + nom (groupe, non-consécutif)

  /// ⭐ V3.21 — Réaction rapide : rappel servi par le parent (toggle).
  final void Function(String emoji)? onReagir;

  /// ⭐ V1.6 — VOTE DE SONDAGE : tap sur une option → vote serveur.
  /// (V1.5 affichait les options en texte inerte : aucun vote possible —
  /// écart de parité avec le web, corrigé.)
  final void Function(String pollId, String optionId)? onVoter;

  /// ⭐ V1.6 — Id de l'utilisateur courant : surligne MES votes dans le
  /// sondage (comme le web qui coche les options choisies).
  final String? monUserId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onReagir,
    this.onVoter,
    this.monUserId,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audio = AudioPlayer();
  bool _lectureVocale = false;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    if (message.isCallLog) {
      return _pastilleAppel();
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    final bulle = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? AppColors.bulleMoi : AppColors.bulleAutre,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rappel de réponse
          if (message.hasReply) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.nuit.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.replyToSenderName ?? '',
                    style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((message.replyToContent ?? '').isNotEmpty)
                    Text(
                      Formatters.apercu(message.replyToContent, max: 50),
                      style: const TextStyle(
                        color: AppColors.texteSecondaire,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          // Verset biblique : référence dorée + texte italique
          if (message.isVerse) ...[
            Text(
              message.verseRef ?? '',
              style: const TextStyle(
                color: AppColors.or,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
          ],
          // ⭐ V3.21 — SONDAGE : question + options votables (comptes temps réel).
          if (message.isPoll) _sondage(),
          // ⭐ V3.21 — NOTE VOCALE : lecteur intégré (bouton lecture + durée).
          if (message.isVoiceNote) _noteVocale(),
          // ⭐ V3.21 — PIÈCE JOINTE : image (pleine largeur) / vidéo / fichier.
          if (message.hasAttachment) _pieceJointe(),
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: TextStyle(
                color: AppColors.texte,
                fontSize: 14.5,
                height: 1.4,
                fontStyle: message.isVerse ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          if (message.isPinned) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 11, color: AppColors.or.withValues(alpha: 0.8)),
                const SizedBox(width: 3),
                Text(
                  'Épinglé',
                  style: TextStyle(
                    color: AppColors.or.withValues(alpha: 0.8),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.editedAt != null) ...[
                const Text(
                  'modifié ',
                  style: TextStyle(color: AppColors.texteEteint, fontSize: 10),
                ),
              ],
              // ⭐ V2.0 — OUTBOX « façon WhatsApp » : bulle en attente →
              // horloge pulsante à la place de l'heure + bulle translucide.
              if (message.enAttenteLocal)
                const Icon(Icons.access_time, size: 11, color: AppColors.or)
              else
                Text(
                  Formatters.heure(message.createdAt),
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 10.5),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (widget.showSender)
              AvatarWidget(
                photoUrl: message.senderAvatarUrl,
                name: message.senderName,
                size: 30,
              )
            else
              const SizedBox(width: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (widget.showSender && !isMe) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: AppColors.orPastel,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                bulle,
                // ⭐ V3.21 — Rangée de réactions (cliquer = toggle serveur).
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        for (final r in message.reactions)
                          InkWell(
                            onTap: widget.onReagir != null
                                ? () => widget.onReagir!(r.emoji)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.pourpreClair,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.orFonce),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.emoji,
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.count}',
                                    style: const TextStyle(
                                      color: AppColors.texteSecondaire,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Journal d'appel (CALL_LOG) : « Appel audio manqué » centré, discret.
  Widget _pastilleAppel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pourpre,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_missed, size: 13, color: AppColors.texteSecondaire),
                const SizedBox(width: 6),
                Text(
                  widget.message.content,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // ⭐ V3.21 — RENDUS DES NOUVEAUX TYPES DE CONTENU
  // ═════════════════════════════════════════════════════

  /// Note vocale : bouton lecture + durée — lecture intégrée (audioplayers).
  /// ⭐ V1.7 — data-URL (secours web sans R2) : les octets base64 sont
  /// écrits en fichier temporaire → DeviceFileSource (UrlSource ne sait
  /// pas lire les data:).
  Widget _noteVocale() {
    final url = _urlAbsolue(widget.message.attachmentUrl ?? widget.message.content);
    final duree = widget.message.voiceDuration ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (_lectureVocale) {
                await _audio.pause();
                if (mounted) setState(() => _lectureVocale = false);
                return;
              }
              try {
                final source = await _sourceAudio(url);
                await _audio.play(source);
                if (mounted) setState(() => _lectureVocale = true);
                _audio.onPlayerComplete.listen((_) {
                  if (mounted) setState(() => _lectureVocale = false);
                });
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lecture impossible')));
                }
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.or,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _lectureVocale ? Icons.pause : Icons.play_arrow,
                color: AppColors.nuit,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Vagues décoratives + durée.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎤 Message vocal',
                    style: TextStyle(
                        color: AppColors.or,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  duree > 0 ? Formatters.chrono(duree) : 'note vocale',
                  style: const TextStyle(
                      color: AppColors.texteSecondaire, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pièce jointe : image pleine largeur / vidéo (lecteur externe) /
  /// fichier (nom + taille + OUVERTURE).
  /// ⭐ V1.7 — images via ImageUniverselle : les data-URLs base64 (secours
  /// web sans R2) s'affichent ENFIN (avant : « Image indisponible »).
  /// Fichiers & vidéos : tap → ouverture (navigateur pour http, visionneuse
  /// système via fichier temporaire pour les data-URLs) — comme le web qui
  /// propose lecture + téléchargement.
  Widget _pieceJointe() {
    final m = widget.message;
    final url = _urlAbsolue(m.attachmentUrl!);
    if (m.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _apercuImage(context, url),
            child: ImageUniverselle(
              url: url,
              width: 240,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    // Vidéo / fichier : carte compacte TAPABLE (ouvrir).
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _ouvrirPieceJointe(url, m),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.pourpre,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.orFonce.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                m.isVideo ? Icons.videocam : Icons.insert_drive_file,
                color: AppColors.or,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.attachmentName ?? 'Fichier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${m.tailleLisible} — toucher pour ouvrir',
                      style: const TextStyle(
                          color: AppColors.texteSecondaire, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, size: 15, color: AppColors.orPastel),
            ],
          ),
        ),
      ),
    );
  }

  /// Sondage : question + options CLIQUABLES (tap = vote, comme le web —
  /// ⭐ V1.6 : avant, les options étaient du texte inerte et le vote était
  /// impossible sur mobile). Mes votes sont surlignés ; le rafraîchissement
  /// des compteurs vient du polling.
  Widget _sondage() {
    final poll = widget.message.poll!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, size: 14, color: AppColors.or),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: widget.onVoter != null
                    ? () => widget.onVoter!(poll.id, option.id)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _jaiVoteOption(option)
                        ? AppColors.or.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _jaiVoteOption(option)
                          ? AppColors.or
                          : AppColors.orFonce.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _jaiVoteOption(option)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: _jaiVoteOption(option)
                            ? AppColors.or
                            : AppColors.texteSecondaire,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          option.label,
                          style: const TextStyle(
                              color: AppColors.texte, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        '${option.voterIds.length}',
                        style: const TextStyle(
                            color: AppColors.texteSecondaire,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            poll.isMulti
                ? '${poll.totalVotes} vote(s) — choix multiples'
                : '${poll.totalVotes} vote(s)',
            style: const TextStyle(
                color: AppColors.texteSecondaire, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// ⭐ V1.6 — Ai-je voté pour cette option ? (surlignage + coche)
  bool _jaiVoteOption(PollOptionModel option) {
    final moi = widget.monUserId;
    return moi != null && option.voterIds.contains(moi);
  }

  /// Aperçu plein écran d'une image (lightbox comme le web).
  /// ⭐ V1.7 — ImageUniverselle : les data-URLs s'aperçoivent aussi.
  void _apercuImage(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, _, __) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: InteractiveViewer(
                child: ImageUniverselle(url: url),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Les URLs de pièces jointes arrivent parfois relatives (/api/…) — on
  /// les absolue contre l'API (R2 renvoie déjà des URLs complètes).
  String _urlAbsolue(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('data:')) return url;
    return '${AppConfig.apiBaseUrl}${url.startsWith('/') ? '' : '/'}$url';
  }

  // ═════════════════════════════════════════════════════════════
  // ⭐ V1.7 — OUVERTURE DES PIÈCES JOINTES (comme le web : lecture +
  // téléchargement). http(s) → navigateur/visionneuse ; data-URL →
  // fichier temporaire + ouverture système.
  // ═════════════════════════════════════════════════════════════

  Future<void> _ouvrirPieceJointe(String url, MessageModel m) async {
    try {
      final uri = await _versUriFichier(url, m);
      if (uri == null) throw 'URL illisible';
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune application ne peut ouvrir ce fichier')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ouverture impossible : $e')));
      }
    }
  }

  /// data-URL → fichier temporaire réutilisable (extension conservée) ;
  /// http(s) → Uri direct.
  Future<Uri?> _versUriFichier(String url, MessageModel m) async {
    if (url.startsWith('http')) return Uri.tryParse(url);
    if (!url.startsWith('data:')) return Uri.tryParse(url);

    // Extraire l'extension depuis le mime ou le nom.
    var ext = '';
    final mime = (m.attachmentMime ?? '').split(';').first.trim();
    final nom = m.attachmentName ?? '';
    final point = nom.lastIndexOf('.');
    if (point >= 0 && point < nom.length - 1) {
      ext = nom.substring(point + 1).toLowerCase();
    } else if (mime.contains('pdf')) {
      ext = 'pdf';
    } else if (mime.contains('sheet') || mime.contains('excel')) {
      ext = 'xlsx';
    } else if (mime.contains('word')) {
      ext = 'docx';
    } else if (mime.contains('zip')) {
      ext = 'zip';
    }

    final octets = octetsDataUrl(url);
    if (octets == null) return null;
    final dir = await getTemporaryDirectory();
    var nomBase = (m.attachmentName ?? 'piece-jointe')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    // Extension absente du nom ? La déduire du mime et l'ajouter.
    if (!nomBase.contains('.') && ext.isNotEmpty) nomBase = '$nomBase.$ext';
    final fichier = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$nomBase');
    await fichier.writeAsBytes(octets);
    // NB : file:// peut être refusé par Android 10+ (stockage cloisonné) —
    // le repli est un message clair ; les URLs http(s) passent, elles,
    // directement par le navigateur/visionneuse système.
    return Uri.file(fichier.path);
  }

  /// Source audio pour audioplayers : data-URL → fichier temporaire
  /// (DeviceFileSource), sinon UrlSource.
  Future<Source> _sourceAudio(String url) async {
    if (url.startsWith('data:')) {
      final octets = octetsDataUrl(url);
      if (octets != null) {
        final dir = await getTemporaryDirectory();
        final f = File(
            '${dir.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await f.writeAsBytes(octets);
        return DeviceFileSource(f.path);
      }
      throw 'Note vocale illisible';
    }
    return UrlSource(url);
  }
}
