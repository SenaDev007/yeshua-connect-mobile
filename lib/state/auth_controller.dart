/// État d'authentification + session courante.
library;

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/push_service.dart';
import '../data/api/api_client.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
enum AuthStatus { unknown, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final SessionUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, SessionUser? user, String? error}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo = AuthRepository();

  AuthController() : super(const AuthState()) {
    _restoreSession();
  }

  /// Au démarrage : la session JWT (cookie persistant) est-elle encore
  /// valide ? → restaure silencieusement l'utilisateur.
  Future<void> _restoreSession() async {
    await ApiClient.instance.ensureInitialized();
    final user = await _repo.session();
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
      // ⭐ V1.4 — Notifications push : ré-enregistre l'appareil (le token
      // a pu tourner pendant que l'app était fermée).
      unawaited(PushService.instance.registerIfAuthenticated());
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String pseudonyme, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(pseudonyme, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      // ⭐ V1.4 — Notifications push pour CET utilisateur (appels privés +
      // messages privés), même application fermée.
      unawaited(PushService.instance.registerIfAuthenticated());
      return true;
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    } catch (e) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Connexion impossible — réessayez.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    // ⭐ V1.4 — Désactive les notifications push de cet appareil (plus
    // rien ne sonne après une déconnexion volontaire).
    unawaited(PushService.instance.unregister());
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// userId courant — ⚠️ jamais envoyé à l'API (le serveur décide tout),
  /// uniquement pour l'affichage (bulles « moi » vs « autre »).
  String? get myId => state.user?.id;
}

final authProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());

/// userId courant — pour l'affichage uniquement.
final myIdProvider = Provider<String?>((ref) => ref.watch(authProvider).user?.id);
