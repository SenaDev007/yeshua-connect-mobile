/// Bulle d'un message : moi (pourpre clair, à droite) / autre (nuit
/// éclairci, à gauche, avec avatar + prénom en groupe).
///
/// Les CALL_LOG s'affichent en pastille centrée — même rendu que le web.
///
/// ⭐ V3.21 — Pièces jointes (image/vidéo/fichier), notes vocales (lecture
/// intégrée), sondages (vote), réactions CLIQUABLES (toggle), badge
/// « modifié », pastille épinglée — parité complète du web.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onReagir,
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
                await _audio.play(UrlSource(url));
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

  /// Pièce jointe : image pleine largeur / vidéo (icône) / fichier (nom + taille).
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
            child: CachedNetworkImage(
              imageUrl: url,
              width: 240,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 240,
                height: 160,
                color: AppColors.pourpre,
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.or),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 240,
                height: 90,
                color: AppColors.pourpre,
                alignment: Alignment.center,
                child: const Text('Image indisponible',
                    style: TextStyle(color: AppColors.texteSecondaire, fontSize: 11)),
              ),
            ),
          ),
        ),
      );
    }
    // Vidéo / fichier : carte compacte.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(10),
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
                    m.tailleLisible,
                    style: const TextStyle(
                        color: AppColors.texteSecondaire, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sondage : question + options avec compteurs (vote au tap — le
  /// rafraîchissement vient du polling, comme le web).
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
              child: Text(
                '• ${option.label}  (${option.voterIds.length})',
                style: const TextStyle(
                    color: AppColors.texte, fontSize: 12.5),
              ),
            ),
          Text(
            '${poll.totalVotes} vote(s)',
            style: const TextStyle(
                color: AppColors.texteSecondaire, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Aperçu plein écran d'une image (lightbox comme le web).
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
                child: CachedNetworkImage(imageUrl: url),
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
}
