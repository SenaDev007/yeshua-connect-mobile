/// Authentification : login/logout + session NextAuth.
/// ⭐ V1.8 — `sessionDetaillee()` : distingue l'absence de session d'un
/// serveur injoignable (autorise la restauration hors-ligne par cache).
/// ⭐ V2.10 — `register()` : inscription (parité web /register).
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

  /// ⭐ V2.10 — INSCRIPTION (parité web `/register`) : crée un compte
  /// MEMBRE auto-validé. Le serveur fait le reste : inscription
  /// automatique aux canaux publics, annonce « Baruch haba ! » dans le
  /// canal d'accueil, placement sur la carte des dispersés (pays →
  /// coordonnées, arrondies 0.1°).
  ///
  /// Erreurs serveur (400 mot de passe court / 409 email existant / 500)
  /// remontent en [ApiException] avec le message FR du serveur.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? pseudonyme,
    required String pays,
    String? ville,
    String langue = 'FR',
  }) async {
    await _api.postJson('/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      if (pseudonyme != null && pseudonyme.isNotEmpty)
        'pseudonyme': pseudonyme,
      'pays': pays,
      if (ville != null && ville.isNotEmpty) 'ville': ville,
      'langue': langue,
    });
    // 200 attendu : { success: true, userId, email, autoVerified: true }.
    // Aucune session n'est posée par /register — l'utilisateur se
    // connecte ensuite (comme sur le web).
  }
}
