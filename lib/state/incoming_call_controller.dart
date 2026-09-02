/// Contrôleur global des APPELS ENTRANts (sonnerie) — actif dès qu'on est
/// authentifié. Détecte un appel qui sonne pour moi via le polling
/// `GET /calls/signal?incoming=1` (3 s) et l'expose à l'UI.
///
/// ⭐ V1.1 : le modèle `IncomingCallModel` porte `isDirect` et
/// `initiatorName` (V3.20 serveur) — l'écran titre l'APPELANT.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/call_model.dart';
import '../data/repositories/calls_repository.dart';

class IncomingCallState {
  /// Appel qui sonne actuellement (null = rien).
  final IncomingCallModel? actuel;

  /// callId déjà traités pendant cette session (évite de re-sonner après
  /// un refus alors que le signal serveur retarde).
  final Set<String> traites;

  const IncomingCallState({this.actuel, this.traites = const {}});

  IncomingCallState copyWith({IncomingCallModel? actuel, Set<String>? traites}) =>
      IncomingCallState(actuel: actuel, traites: traites ?? this.traites);
}

class IncomingCallController extends StateNotifier<IncomingCallState> {
  final CallsRepository _repo = CallsRepository();
  Timer? _timer;

  IncomingCallController() : super(const IncomingCallState()) {
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.incomingCallPollSeconds),
      (_) => _poll(),
    );
    _poll();
  }

  Future<void> _poll() async {
    if (state.actuel != null) return; // une sonnerie à la fois
    try {
      final entrants = await _repo.entrants();
      for (final appel in entrants) {
        if (state.traites.contains(appel.callId)) continue;
        state = state.copyWith(actuel: appel);
        return;
      }
    } catch (_) {
      // Réseau instable : on retente au prochain tick.
    }
  }

  /// L'appel a été traité (accepté/refusé/expiré) → ne plus sonner.
  void terminer() {
    final actuel = state.actuel;
    if (actuel != null) {
      state = IncomingCallState(traites: {...state.traites, actuel.callId});
    } else {
      state = const IncomingCallState();
    }
  }

  /// Refus explicite depuis l'écran de sonnerie — côté serveur, termine
  /// l'appel sur un DIRECT (comme le web V3.1).
  Future<void> refuser(String callId) => _repo.refuser(callId);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final incomingCallProvider =
    StateNotifierProvider<IncomingCallController, IncomingCallState>(
        (ref) => IncomingCallController());
