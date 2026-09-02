/// État d'authentification + session courante.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String pseudonyme, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(pseudonyme, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
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
