/// Authentification : login/logout + session NextAuth.
library;

import '../api/api_client.dart';
import '../models/user_model.dart';
class AuthRepository {
  final ApiClient _api = ApiClient.instance;

  AuthRepository();

  Future<SessionUser> login(String pseudonyme, String password) =>
      _api.login(pseudonyme.trim(), password);

  Future<SessionUser?> session() => _api.fetchSession();

  Future<void> logout() => _api.logout();
}
