/// État d'un chat ouvert : messages + polling + envoi + pagination.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/message_model.dart';
import '../data/repositories/messages_repository.dart';
class ChatState {
  final List<MessageModel> messages;
  final bool chargement;
  final bool chargementPlus;
  final bool envoiEnCours;
  final String? error;
  final bool aToutCharge; // plus rien de plus ancien à charger

  const ChatState({
    this.messages = const [],
    this.chargement = false,
    this.chargementPlus = false,
    this.envoiEnCours = false,
    this.error,
    this.aToutCharge = false,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? chargement,
    bool? chargementPlus,
    bool? envoiEnCours,
    String? error,
    bool clearError = false,
    bool? aToutCharge,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        chargement: chargement ?? this.chargement,
        chargementPlus: chargementPlus ?? this.chargementPlus,
        envoiEnCours: envoiEnCours ?? this.envoiEnCours,
        error: clearError ? null : (error ?? this.error),
        aToutCharge: aToutCharge ?? this.aToutCharge,
      );
}

/// Un contrôleur de chat PAR conversation ouverte (family).
class ChatController extends StateNotifier<ChatState> {
  final String conversationId;
  final MessagesRepository _repo = MessagesRepository();
  Timer? _timer;

  ChatController(this.conversationId) : super(const ChatState()) {
    charger();
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.chatPollSeconds),
      (_) => _poll(),
    );
  }

  /// Chargement initial (le bas de la conversation).
  Future<void> charger() async {
    state = state.copyWith(chargement: true, clearError: true);
    try {
      final messages = await _repo.messages(conversationId);
      state = ChatState(messages: messages, aToutCharge: messages.length < 50);
    } catch (e) {
      state = state.copyWith(chargement: false, error: e.toString());
    }
  }

  /// Polling : ne récupère que ce qui est PLUS RÉCENT que le dernier connu,
  /// et fusionne proprement (dédupliqué par id).
  Future<void> _poll() async {
    if (state.chargement || state.chargementPlus) return;
    try {
      final frais = await _repo.messages(conversationId);
      if (frais.isEmpty) return;
      final connus = state.messages.map((m) => m.id).toSet();
      final nouveaux = frais.where((m) => !connus.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (nouveaux.isEmpty) return;
      // Remplace aussi les bulles existantes (réactions/épinglage éventuels).
      final byId = {for (final m in state.messages) m.id: m};
      for (final m in frais) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: merged);
    } catch (_) {
      // Polling silencieux : on retente au prochain tick.
    }
  }

  /// « Charger plus ancien » au scroll vers le haut (cursor pagination).
  Future<void> chargerPlusAnciens() async {
    if (state.chargementPlus || state.aToutCharge || state.messages.isEmpty) return;
    state = state.copyWith(chargementPlus: true, clearError: true);
    try {
      final plusAnciens = await _repo.messages(
        conversationId,
        before: state.messages.first.id,
      );
      final connus = state.messages.map((m) => m.id).toSet();
      final nouveaux = plusAnciens.where((m) => !connus.contains(m.id)).toList();
      state = state.copyWith(
        messages: [...nouveaux, ...state.messages],
        chargementPlus: false,
        aToutCharge: plusAnciens.length < 50,
      );
    } catch (e) {
      state = state.copyWith(chargementPlus: false, error: e.toString());
    }
  }

  /// Envoie un message (optimiste puis remplacement par la réponse serveur).
  Future<void> envoyer(String content) async {
    final texte = content.trim();
    if (texte.isEmpty || state.envoiEnCours) return;
    state = state.copyWith(envoiEnCours: true, clearError: true);
    try {
      final message = await _repo.envoyer(conversationId, texte);
      final connus = state.messages.map((m) => m.id).toSet();
      if (!connus.contains(message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
      state = state.copyWith(envoiEnCours: false);
    } catch (e) {
      state = state.copyWith(envoiEnCours: false, error: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatController, ChatState, String>(
  (ref, conversationId) => ChatController(conversationId),
);
