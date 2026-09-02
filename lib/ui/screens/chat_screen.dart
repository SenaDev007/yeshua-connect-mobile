/// Écran de conversation (chat) : fil de messages, envoi, pagination
/// « plus ancien », bouton d'appel 📞/🎥, panneau des membres.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation_model.dart';
import '../../state/auth_controller.dart';
import '../../state/call_controller.dart';
import '../../state/chat_controller.dart';
import '../../state/conversations_controller.dart';
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
  bool _autoScroll = true;

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
    try {
      await ref.read(chatProvider(widget.conversationId).notifier).envoyer(texte);
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
                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            showSender: showSender,
                          );
                        },
                      ),
          ),
          // ── Barre de saisie ──
          _barreSaisie(chat),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(
          children: [
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
          ],
        ),
      ),
    );
  }
}
