/// Authentification : login/logout + session NextAuth.
/// ⭐ V1.8 — `sessionDetaillee()` : distingue l'absence de session d'un
/// serveur injoignable (autorise la restauration hors-ligne par cache).
library;

import '../api/api_client.dart';
import '../models/user_model.dart';
class AuthRepository {
  final ApiClient _api = ApiClient.instance;

  AuthRepository();

  Future<SessionUser> login(String pseudonyme, String password) =>
      _api.login(pseudonyme.trim(), password);

  Future<SessionUser?> session() => _api.fetchSession();

  /// ⭐ V1.8 — Session avec diagnostic réseau (repli hors-ligne).
  Future<ResultatSession> sessionDetaillee() => _api.fetchSessionDetaillee();

  Future<void> logout() => _api.logout();
}
