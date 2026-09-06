/// État d'authentification + session courante.
library;

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/cache_local.dart';
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
  ///
  /// ⭐ V1.8 — MODE HORS-LIGNE : si le serveur est INJOIGNABLE (wifi coupé
  /// ou incident serveur) mais qu'une session a déjà été ouverte
  /// précédemment, on entre quand même avec la dernière session connue —
  /// les conversations/Bible/calendrier sont servis depuis le cache local.
  /// Seuls les envois/appels/vidéos exigent alors la connexion.
  Future<void> _restoreSession() async {
    await ApiClient.instance.ensureInitialized();
    final resultat = await _repo.sessionDetaillee();
    final user = resultat.utilisateur;
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _memoriserSession(user);
      // ⭐ V1.4 — Notifications push : ré-enregistre l'appareil (le token
      // a pu tourner pendant que l'app était fermée).
      unawaited(PushService.instance.registerIfAuthenticated());
      return;
    }
    if (resultat.reseauInaccessible) {
      final cache = await CacheLocal.instance.charger(CacheLocal.cleSession);
      if (cache is Map && cache['user'] is Map) {
        try {
          final restaure = SessionUser.fromSessionJson(
              Map<String, dynamic>.from(cache));
          state = AuthState(status: AuthStatus.authenticated, user: restaure);
          // Pas d'enregistrement push hors ligne : inutile d'essayer.
          return;
        } catch (_) {/* cache illisible → écran de connexion */}
      }
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Serveur injoignable — l\u2019app s\u2019ouvre hors ligne dès qu\u2019une '
            'session a déjà été ouverte. Vérifiez internet pour vous connecter.',
      );
      return;
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Mémorise la session en cache local (entrée hors-ligne au prochain
  /// démarrage sans réseau).
  Future<void> _memoriserSession(SessionUser user) async {
    try {
      await CacheLocal.instance.sauvegarder(CacheLocal.cleSession, {
        'user': {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'image': user.image,
          'role': user.role,
        },
      });
    } catch (_) {}
  }

  Future<bool> login(String pseudonyme, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(pseudonyme, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      // ⭐ V1.8 — Session mémorisée pour l'entrée hors-ligne au prochain
      // lancement sans réseau.
      _memoriserSession(user);
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
    // ⭐ V1.8 — Purge la session mémorisée : l'entrée hors-ligne ne doit
    // PAS ressusciter un compte volontairement déconnecté.
    await CacheLocal.instance.supprimer(CacheLocal.cleSession);
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
