/// Écran de conversation (chat) : fil de messages, envoi, pagination
/// « plus ancien », bouton d'appel 📞/🎥, panneau des membres.
/// ⭐ V3.21 — INTERACTIONS COMPLÈTES DE PARITÉ WEB : réponse, réactions
/// (🙏 ✋ ❤️ 📖 🔥 ⭐), épinglage, modification, suppression, transfert,
/// pièces jointes (images/fichiers) et notes vocales.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/messages_repository.dart';
import '../../state/auth_controller.dart';
import '../../state/call_controller.dart';
import '../../state/chat_controller.dart';
import '../../state/conversations_controller.dart';
import '../../state/voice_channel_controller.dart';
import '../../state/call_media_controller.dart' show MediaProviderNomX;
import '../widgets/avatar_widget.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _saisieCtrl = TextEditingController();
  final _editionCtrl = TextEditingController();
  bool _autoScroll = true;

  // ⭐ V3.21 — Interactions de parité web.
  MessageModel? _reponseA;      // message auquel on répond
  bool _enregistre = false;     // note vocale en cours
  int _dureeVocale = 0;
  Timer? _chronoVocal;
  final AudioRecorder _enr = AudioRecorder();
  String? _cheminVocal;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _saisieCtrl.dispose();
    _editionCtrl.dispose();
    _chronoVocal?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 60) {
      _autoScroll = true;
    } else {
      _autoScroll = false;
    }
    if (_scrollCtrl.position.pixels <= 80) {
      ref.read(chatProvider(widget.conversationId).notifier).chargerPlusAnciens();
    }
  }

  void _scrollVersLeBas({bool anim = true}) {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (anim) {
      _scrollCtrl.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(position.maxScrollExtent);
    }
  }

  Future<void> _envoyer() async {
    final texte = _saisieCtrl.text.trim();
    if (texte.isEmpty) return;
    _saisieCtrl.clear();
    setState(() => _autoScroll = true);
    final reponse = _reponseA;
    setState(() => _reponseA = null);
    try {
      await ref.read(chatProvider(widget.conversationId).notifier).envoyer(
            texte,
            reponseA: reponse,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _appeler({bool video = false}) async {
    final moi = ref.read(authProvider).user;
    final meId = moi?.id;
    final conv = ref.read(conversationsProvider).conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    if (conv == null) return;
    try {
      await ref.read(activeCallProvider.notifier).appeler(
            conversationId: conv.id,
            conversationName:
                conv.isDirect ? (conv.otherOf(meId ?? '')?.name ?? conv.name) : conv.name,
            conversationAvatar:
                conv.isDirect ? conv.otherOf(meId ?? '')?.avatarUrl : conv.avatarUrl,
            myName: moi?.name ?? 'Moi',
            myAvatar: moi?.image,
            video: video,
          );
      if (mounted) context.push('/app/appel');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.conversationId));
    final meId = ref.watch(myIdProvider) ?? '';
    final conv = ref.watch(conversationsProvider).conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final isDirect = conv?.isDirect ?? false;

    // Nouveau message → scroll vers le bas (si on y était déjà).
    ref.listen(chatProvider(widget.conversationId), (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) && _autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollVersLeBas());
      }
    });

    final titre = isDirect
        ? (conv?.otherOf(meId)?.name ?? conv?.name ?? 'Conversation')
        : (conv?.name ?? 'Conversation');

    // ⭐ V3.21 — épinglés du fil (panneau raccourci).
    final epingles = _epingles(chat);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarWithPresence(
              photoUrl: isDirect ? conv?.otherOf(meId)?.avatarUrl : conv?.avatarUrl,
              name: titre,
              online: isDirect && (conv?.otherOf(meId)?.online ?? false),
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (isDirect) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.lock_outline, size: 12, color: AppColors.or),
                      ],
                    ],
                  ),
                  Text(
                    _sousTitre(conv, meId),
                    style: const TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appel audio',
            icon: const Icon(Icons.call_outlined, color: AppColors.or),
            onPressed: () => _appeler(video: false),
          ),
          IconButton(
            tooltip: 'Appel vidéo',
            icon: const Icon(Icons.videocam_outlined, color: AppColors.or),
            onPressed: () => _appeler(video: true),
          ),
          IconButton(
            tooltip: 'Membres',
            icon: const Icon(Icons.people_outline, color: AppColors.orPastel),
            onPressed: () => context.push('/app/chat/${widget.conversationId}/membres'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Bandeau confidentiel pour les privés (V3.20) ──
          if (isDirect)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.pourpre.withOpacity(0.5),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 13, color: AppColors.or),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Conversation privée — visible uniquement par vous deux',
                      style: TextStyle(color: AppColors.texteSecondaire, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          // ── ⭐ CANAL VOCAL PERSISTANT (parité web : VoiceChannelPanel) ──
          if (conv?.type == 'VOICE') _carteCanalVocal(context, ref),
          // ── Erreur d'envoi ──
          if (chat.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: AppColors.danger.withOpacity(0.15),
              child: Text(
                chat.error!,
                style: const TextStyle(color: AppColors.texte, fontSize: 12.5),
              ),
            ),
          // ── Fil de messages ──
          Expanded(
            child: chat.chargement
                ? const Center(child: CircularProgressIndicator(color: AppColors.or))
                : chat.messages.isEmpty
                    ? _vide()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: chat.messages.length + (chat.aToutCharge ? 0 : 1),
                        itemBuilder: (context, i) {
                          // En-tête « charger plus ancien » en position 0.
                          if (i == 0 && !chat.aToutCharge) {
                            return Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(
                                child: chat.chargementPlus
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.or,
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: () => ref
                                            .read(chatProvider(widget.conversationId).notifier)
                                            .chargerPlusAnciens(),
                                        child: const Text('Charger les messages plus anciens'),
                                      ),
                              ),
                            );
                          }
                          final idx = chat.aToutCharge ? i : i - 1;
                          final message = chat.messages[idx];
                          final precedent = idx > 0 ? chat.messages[idx - 1] : null;
                          final isMe = message.senderId == meId;
                          final showSender =
                              !isMe && (precedent?.senderId != message.senderId);
                          return GestureDetector(
                            onLongPress: () => _menuMessage(message, isMe),
                            child: MessageBubble(
                              message: message,
                              isMe: isMe,
                              showSender: showSender,
                              onReagir: (emoji) => ref
                                  .read(chatProvider(widget.conversationId).notifier)
                                  .reagir(message.id, emoji),
                            ),
                          );
                        },
                      ),
          ),
          // ⭐ V3.21 — Panneau « épinglés » (raccourci).
          if (epingles.isNotEmpty)
            _barreEpingles(epingles, meId),
          // ⭐ V3.21 — Bandeau de RÉPONSE (rappel du message auquel on
          // répond — même UX que le web).
          if (_reponseA != null) _barreReponse(),
          // ── Barre de saisie ──
          _barreSaisie(chat),
        ],
      ),
    );
  }

  /// Messages épinglés du fil (⭐ V3.21).
  List<MessageModel> _epingles(ChatState chat) =>
      chat.messages.where((m) => m.isPinned).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String _sousTitre(ConversationModel? conv, String meId) {
    if (conv == null) return '';
    if (conv.isDirect) {
      return conv.otherOf(meId)?.online == true ? 'en ligne' : 'privé';
    }
    final n = conv.participants.length;
    final enLigne = conv.enLigneHors(meId);
    if (enLigne > 0) return '$n membres · $enLigne en ligne';
    return '$n membres';
  }

  /// ⭐ Carte du canal vocal persistant (miroir du VoiceChannelPanel web) :
  /// état en direct (connecté, participants, fournisseur) + accès à
  /// l'écran dédié (rejoindre/quitter, micro, mode admin).
  Widget _carteCanalVocal(BuildContext context, WidgetRef ref) {
    final vocal = ref.watch(voiceChannelProvider);
    final estCeCanal = vocal.conversationId == widget.conversationId;
    final actifIci = estCeCanal && vocal.connecte;
    final nb = actifIci ? vocal.participants.length + 1 : 0;

    return InkWell(
      onTap: () => context.push('/app/chat/${widget.conversationId}/canal-vocal'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: actifIci ? AppColors.or.withOpacity(0.5) : AppColors.pourpreClair,
          ),
        ),
        child: Row(
          children: [
            Icon(
              actifIci ? Icons.graphic_eq : Icons.headphones,
              color: AppColors.or,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actifIci
                        ? 'Canal vocal — connecté${nb > 1 ? ' ($nb)' : ''}'
                        : 'Canal vocal — rejoindre',
                    style: const TextStyle(
                      color: AppColors.texte,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  if (actifIci)
                    Text(
                      'Réseau : ${vocal.fournisseur.libelle}'
                      '${vocal.videoMode ? ' · mode vidéo' : ''}'
                      '${vocal.basculeEnCours ? ' · bascule…' : ''}',
                      style: const TextStyle(
                        color: AppColors.texteSecondaire,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            if (actifIci && vocal.microCoupe)
              const Icon(Icons.mic_off, color: AppColors.danger, size: 18),
            const Icon(Icons.chevron_right, color: AppColors.texteSecondaire),
          ],
        ),
      ),
    );
  }

  Widget _vide() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand_outlined, size: 44, color: AppColors.texteEteint),
            SizedBox(height: 12),
            Text(
              'Envoyez le premier message',
              style: TextStyle(color: AppColors.texteSecondaire, fontSize: 14.5),
            ),
          ],
        ),
      );

  Widget _barreSaisie(ChatState chat) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // ⭐ V1.5 — Actions canal : sondage + message programmé.
                if (_estCanal())
                  IconButton(
                    tooltip: 'Sondage, message programmé…',
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.orPastel),
                    onPressed: chat.envoiEnCours ? null : _menuActions,
                  ),
                // ⭐ V3.21 — Pièce jointe (image/fichier, comme le web).
                IconButton(
                  tooltip: 'Joindre un fichier',
                  icon: const Icon(Icons.attach_file, color: AppColors.orPastel),
                  onPressed: chat.envoiEnCours ? null : _joindreFichier,
                ),
                Expanded(
                  child: TextField(
                    controller: _saisieCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _envoyer(),
                    decoration: InputDecoration(
                      hintText: 'Votre message…',
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: chat.envoiEnCours ? AppColors.texteEteint : AppColors.or,
                        ),
                        onPressed: chat.envoiEnCours ? null : _envoyer,
                      ),
                    ),
                  ),
                ),
                // ⭐ V3.21 — Note vocale (maintenir pour enregistrer).
                _boutonVocal(chat),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton note vocale : MAINTENIR pour enregistrer, relâcher pour envoyer
  /// (même geste que WhatsApp — parité web).
  Widget _boutonVocal(ChatState chat) {
    if (_enregistre) {
      return GestureDetector(
        onTapUp: (_) => _envoyerNoteVocale(),
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stop, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '${_dureeVocale}s',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onLongPressStart: (_) => _demarrerNoteVocale(),
      child: IconButton(
        tooltip: 'Maintenir pour enregistrer un message vocal',
        icon: const Icon(Icons.mic, color: AppColors.orPastel),
        onPressed: _demarrerNoteVocale,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ V3.21 — MENU CONTEXTUEL DU MESSAGE (long-press)
  // ═══════════════════════════════════════════════════════════

  void _menuMessage(MessageModel message, bool isMe) {
    final ctrl = ref.read(chatProvider(widget.conversationId).notifier);
    final convs = ref.read(conversationsProvider).conversations
        .where((c) => c.id != widget.conversationId)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // ── Rangée de réactions rapides (spirituelles, comme le web) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in const ['🙏', '✋', '❤️', '📖', '🔥', '⭐'])
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      ctrl.reagir(message.id, emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
            const Divider(color: AppColors.orFonce, height: 20),
            _ligneMenu(Icons.reply, 'Répondre', () {
              Navigator.pop(context);
              setState(() => _reponseA = message);
            }),
            _ligneMenu(
              message.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              message.isPinned ? 'Désépingler' : 'Épingler',
              () {
                Navigator.pop(context);
                ctrl.epingler(message.id);
              },
            ),
            if (isMe) ...[
              _ligneMenu(Icons.edit_outlined, 'Modifier', () {
                Navigator.pop(context);
                _dialogModifier(message);
              }),
            ],
            _ligneMenu(Icons.delete_outline, 'Supprimer', () {
              Navigator.pop(context);
              _dialogSupprimer(message, isMe);
            }),
            if (convs.isNotEmpty)
              _ligneMenu(Icons.shortcut, 'Transférer', () {
                Navigator.pop(context);
                _dialogTransferer(message, convs);
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ligneMenu(IconData icone, String libelle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icone, color: AppColors.or, size: 21),
      title: Text(
        libelle,
        style: const TextStyle(color: AppColors.texte, fontSize: 14.5),
      ),
      dense: true,
      onTap: onTap,
    );
  }

  void _dialogModifier(MessageModel message) {
    _editionCtrl.text = message.content;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.pourpre,
        title: const Text('Modifier le message',
            style: TextStyle(color: AppColors.texte, fontSize: 17)),
        content: TextField(
          controller: _editionCtrl,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(color: AppColors.texte),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .modifier(message.id, _editionCtrl.text);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _dialogSupprimer(MessageModel message, bool isMe) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.pourpre,
        title: const Text('Supprimer le message ?',
            style: TextStyle(color: AppColors.texte, fontSize: 17)),
        content: const Text(
          '« Supprimer pour moi » masque le message uniquement chez vous ; '
          '« Supprimer pour tous » l\'efface pour toute la conversation '
          '(réservé à l\'auteur et aux modérateurs).',
          style: TextStyle(color: AppColors.texteSecondaire, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .supprimer(message.id, pourToutLeMonde: false);
            },
            child: const Text('Pour moi'),
          ),
          if (isMe)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .supprimer(message.id, pourToutLeMonde: true);
              },
              child: const Text('Pour tous'),
            ),
        ],
      ),
    );
  }

  void _dialogTransferer(MessageModel message, List<ConversationModel> convs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: convs.length,
          itemBuilder: (context, i) => ListTile(
            leading: AvatarWidget(
              photoUrl: convs[i].avatarUrl,
              name: convs[i].name,
              size: 34,
            ),
            title: Text(
              convs[i].name,
              style: const TextStyle(color: AppColors.texte, fontSize: 14.5),
            ),
            onTap: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .transferer(message.id, convs[i].id)
                  .then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Message transféré vers ${convs[i].name}'),
                    ),
                  );
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Transfert impossible : $e')));
                }
              });
            },
          ),
        ),
      ),
    );
  }

  // ── Bandeau RÉPONSE (au-dessus de la saisie) ──
  Widget _barreReponse() {
    final r = _reponseA!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: const BoxDecoration(
        color: AppColors.pourpreClair,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border(left: BorderSide(color: AppColors.or, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.senderName,
                  style: const TextStyle(
                    color: AppColors.or,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.texteSecondaire),
            onPressed: () => setState(() => _reponseA = null),
          ),
        ],
      ),
    );
  }

  // ── Panneau épinglés (raccourci du fil) ──
  Widget _barreEpingles(List<MessageModel> epingles, String meId) {
    return Container(
      height: 42,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.or.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.or.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 14, color: AppColors.or),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Épinglé : ${epingles.first.content.isEmpty ? 'pièce jointe' : epingles.first.content}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.or, fontSize: 12),
            ),
          ),
          Text(
            '${epingles.length}',
            style: const TextStyle(
              color: AppColors.or,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // ⭐ V3.21 — PIÈCES JOINTES + NOTES VOCALES
  // ═══════════════════════════════════════════════════════

  Future<void> _joindreFichier() async {
    final resultat = await FilePicker.platform.pickFiles(withData: false);
    final chemin = resultat?.files.single.path;
    if (chemin == null) return;
    final nom = resultat?.files.single.name ?? 'fichier';
    final mime = resultat?.files.single.extension?.toLowerCase() ?? '';
    final type = mime.startsWith('png') ||
            mime.startsWith('jpg') ||
            mime.startsWith('jpeg') ||
            mime.startsWith('gif') ||
            mime.startsWith('webp')
        ? 'IMAGE'
        : (mime.startsWith('mp4') || mime.startsWith('mov') || mime.startsWith('webm')
            ? 'VIDEO'
            : 'FILE');
    final mimeComplet = type == 'IMAGE'
        ? 'image/$mime'
        : (type == 'VIDEO' ? 'video/$mime' : 'application/octet-stream');
    try {
      await ref
          .read(chatProvider(widget.conversationId).notifier)
          .envoyerPieceJointe(chemin, nom, type: type, mime: mimeComplet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
      }
    }
  }

  Future<void> _demarrerNoteVocale() async {
    if (_enregistre) return;
    try {
      if (!await _enr.hasPermission()) return;
      final dir = await Directory.systemTemp.createTemp('yc_voix');
      final chemin =
          '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _enr.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: chemin,
      );
      _cheminVocal = chemin;
      setState(() {
        _enregistre = true;
        _dureeVocale = 0;
      });
      _chronoVocal?.cancel();
      _chronoVocal = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _dureeVocale++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Micro indisponible : $e')));
      }
    }
  }

  Future<void> _envoyerNoteVocale() async {
    _chronoVocal?.cancel();
    if (!_enregistre) return;
    setState(() => _enregistre = false);
    final chemin = _cheminVocal;
    final duree = _dureeVocale;
    _cheminVocal = null;
    if (chemin == null || duree < 1) return; // trop court — on ignore
    try {
      final fichier = File(chemin);
      if (!await fichier.exists()) return;
      await ref
          .read(chatProvider(widget.conversationId).notifier)
          .envoyerNoteVocale(chemin, duree);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ V1.5 — ACTIONS DU CANAL : sondage + message programmé
  // (routes /polls et /scheduled-messages — parité web complète)
  // ═══════════════════════════════════════════════════════════

  /// Sondages et programmés : canaux/groupes uniquement (le web exige
  /// un channelId — les DM n'en sont pas).
  bool _estCanal() {
    final convs = ref.read(conversationsProvider).conversations;
    for (final c in convs) {
      if (c.id == widget.conversationId) return !c.isDirect;
    }
    return false;
  }

  void _menuActions() {
    showModalBottomSheet<void>(
      backgroundColor: AppColors.pourpre,
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.poll, color: AppColors.or),
              title: const Text('Créer un sondage'),
              subtitle: const Text(
                  'Question + options — la communauté vote en direct',
                  style: TextStyle(
                      color: AppColors.texteEteint, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                _dialogueSondage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_send, color: AppColors.or),
              title: const Text('Programmer un message'),
              subtitle: const Text(
                  'Envoi automatique à l\'heure choisie (cron serveur)',
                  style: TextStyle(
                      color: AppColors.texteEteint, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                _dialogueProgrammation();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Dialogue de création de sondage (question + 2..n options + multi).
  void _dialogueSondage() {
    final questionCtrl = TextEditingController();
    final options = [
      TextEditingController(),
      TextEditingController(),
    ];
    var multi = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogue) => AlertDialog(
          backgroundColor: AppColors.pourpre,
          title: const Text('Nouveau sondage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Question',
                      hintText: 'Ex. Quel jour pour la veillée ?'),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: options[i],
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                                labelText: 'Option ${i + 1}'),
                          ),
                        ),
                        if (options.length > 2)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.danger, size: 20),
                            onPressed: () =>
                                setDialogue(() => options.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: options.length >= 8
                        ? null
                        : () => setDialogue(
                            () => options.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter une option'),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  activeColor: AppColors.or,
                  title: const Text(
                    'Choix multiples autorisés',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  value: multi,
                  onChanged: (v) => setDialogue(() => multi = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit),
              onPressed: () async {
                final question = questionCtrl.text.trim();
                final libelles = options
                    .map((o) => o.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (question.isEmpty || libelles.length < 2) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Une question et au moins 2 options sont requises.')),
                  );
                  return;
                }
                try {
                  await MessagesRepository().creerSondage(
                    widget.conversationId,
                    question,
                    libelles,
                    isMulti: multi,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  // Recharge immédiate : le message POLL apparaît.
                  ref
                      .read(chatProvider(widget.conversationId).notifier)
                      .charger();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogue de programmation d'un message (contenu + date + heure).
  void _dialogueProgrammation() {
    final contenuCtrl = TextEditingController();
    var quand = DateTime.now().add(const Duration(hours: 1));

    // Fonctions locales (pas de getters locaux en Dart) — mises à jour
    // via setDialogue du StatefulBuilder.
    String dateCourt() =>
        '${quand.day.toString().padLeft(2, '0')}/${quand.month.toString().padLeft(2, '0')}/${quand.year}';
    String heureCourte() =>
        '${quand.hour.toString().padLeft(2, '0')}h${quand.minute.toString().padLeft(2, '0')}';

    Future<void> Function() choisirDate(StateSetter setDialogue) => () async {
          final d = await showDatePicker(
            context: context,
            initialDate: quand,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) {
            setDialogue(
              () => quand = DateTime(
                  d.year, d.month, d.day, quand.hour, quand.minute),
            );
          }
        };

    Future<void> Function() choisirHeure(StateSetter setDialogue) => () async {
          final h = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(quand),
          );
          if (h != null) {
            setDialogue(
              () => quand =
                  DateTime(quand.year, quand.month, quand.day, h.hour, h.minute),
            );
          }
        };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogue) => AlertDialog(
          backgroundColor: AppColors.pourpre,
          title: const Text('Programmer un message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contenuCtrl,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Message à envoyer'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.or),
                        onPressed: choisirDate(setDialogue),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          dateCourt(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.or),
                        onPressed: choisirHeure(setDialogue),
                        icon: const Icon(Icons.schedule, size: 16),
                        label: Text(
                          heureCourte(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Le message partira automatiquement à cette heure (cron serveur) — visible dans Profil → Messages programmés.',
                  style: TextStyle(
                      color: AppColors.texteEteint,
                      fontSize: 11.5,
                      height: 1.45),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit),
              onPressed: () async {
                final contenu = contenuCtrl.text.trim();
                if (contenu.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Le message est vide.')),
                  );
                  return;
                }
                if (!quand.isAfter(DateTime.now())) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Choisissez une heure future.')),
                  );
                  return;
                }
                try {
                  await MessagesRepository().programmer(
                    widget.conversationId,
                    contenu,
                    quand,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Programmé pour le ${dateCourt()} à ${heureCourte()}.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Programmer'),
            ),
          ],
        ),
      ),
    );
  }
}
