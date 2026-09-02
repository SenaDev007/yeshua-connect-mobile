/// Liste des conversations + polling (≈ heartbeat présence serveur).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/conversation_model.dart';
import '../data/repositories/conversations_repository.dart';
class ConversationsState {
  final List<ConversationModel> conversations;
  final bool chargement;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.chargement = false,
    this.error,
  });

  ConversationsState copyWith({
    List<ConversationModel>? conversations,
    bool? chargement,
    String? error,
    bool clearError = false,
  }) =>
      ConversationsState(
        conversations: conversations ?? this.conversations,
        chargement: chargement ?? this.chargement,
        error: clearError ? null : (error ?? this.error),
      );

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

class ConversationsController extends StateNotifier<ConversationsState> {
  final ConversationsRepository _repo = ConversationsRepository();
  Timer? _timer;

  ConversationsController() : super(const ConversationsState()) {
    rafraichir();
    // Polling — le GET sert aussi de heartbeat de présence (lastSeenAt).
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.conversationsPollSeconds),
      (_) => rafraichir(silencieux: true),
    );
  }

  Future<void> rafraichir({bool silencieux = false}) async {
    if (!silencieux) state = state.copyWith(chargement: true, clearError: true);
    try {
      final liste = await _repo.liste();
      state = ConversationsState(conversations: liste);
    } catch (e) {
      if (!silencieux) {
        state = state.copyWith(chargement: false, error: e.toString());
      }
      // En polling silencieux : on garde l'affichage courant.
    }
  }

  /// Marque lu et rafraîchit le compteur localement.
  Future<void> marquerLu(String conversationId) async {
    final updated = [
      for (final c in state.conversations)
        if (c.id == conversationId) c.copyWith(unreadCount: 0) else c,
    ];
    state = state.copyWith(conversations: updated);
    try {
      await _repo.marquerLu(conversationId);
    } catch (_) {
      // Non bloquant : le prochain polling resynchronise.
    }
  }

  /// Ouvre (ou retrouve) un privé avec un membre → id de conversation.
  Future<String> demarrerPrive(String targetUserId) => _repo.demarrerPrive(targetUserId);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsController, ConversationsState>(
        (ref) => ConversationsController());
