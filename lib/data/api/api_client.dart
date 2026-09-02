/// Client HTTP de Yeshua Connect.
///
/// Gère la session **NextAuth v5 (credentials)** exactement comme le
/// navigateur du web :
///
/// 1. `GET /api/auth/csrf` → jeton CSRF (cookie `authjs.csrf-token`) ;
/// 2. `POST /api/auth/callback/credentials` en form-urlencoded
///    (`csrfToken`, `pseudonyme`, `password`) → pose le cookie de session
///    JWT `authjs.session-token` (persisté dans un `PersistCookieJar`) ;
/// 3. toutes les requêtes `/api/yeshua-connect/*` partent avec ce cookie.
///
/// ⚠️ `userId` et rôle sont TOUJOURS décidés côté serveur — jamais envoyés
/// par le client.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../models/user_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  PersistCookieJar? _cookieJar;

  Future<void> ensureInitialized() async {
    if (_dio != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'YeshuaConnect-Mobile/1.1 (Flutter)',
      },
      // NextAuth répond souvent par des 3xx (redirections de callback) —
      // on les suit et on valide le statut final.
      validateStatus: (status) => status != null && status >= 200 && status < 400,
    ))..interceptors.add(CookieManager(_cookieJar!));
  }

  Dio get dio {
    final d = _dio;
    if (d == null) {
      throw StateError("ApiClient non initialisé — appeler ensureInitialized() d'abord");
    }
    return d;
  }

  // ═════════════════════════════════════════════════════════════════
  //  AUTHENTIFICATION
  // ═════════════════════════════════════════════════════════════════

  /// Ouvre la session NextAuth (credentials). Retourne l'utilisateur.
  Future<SessionUser> login(String pseudonyme, String password) async {
    await ensureInitialized();

    // 1) Jeton CSRF
    final csrfToken = await _fetchCsrfToken();
    if (csrfToken == null) {
      throw const ApiException('Impossible d\'obtenir le jeton de sécurité — réessayez.');
    }

    // 2) Callback credentials (form-urlencoded, comme le formulaire web)
    try {
      await dio.post<dynamic>(
        '/api/auth/callback/credentials',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          maxRedirects: 5,
        ),
        data: {
          'csrfToken': csrfToken,
          'pseudonyme': pseudonyme,
          'password': password,
          'callbackUrl': '/',
          'json': 'true',
        },
      );
    } on DioException catch (e) {
      throw ApiException(_messageDio(e));
    }

    // 3) Vérifie la session réellement posée
    final user = await fetchSession();
    if (user == null) {
      throw const ApiException(
        'Pseudonyme ou mot de passe incorrect — ou compte en attente de validation '
        'par un administrateur.',
      );
    }
    return user;
  }

  /// Lit la session courante (null si expirée/inexistante).
  Future<SessionUser?> fetchSession() async {
    await ensureInitialized();
    try {
      final response = await dio.get<dynamic>('/api/auth/session');
      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data is! Map || !data.containsKey('user')) return null;
      return SessionUser.fromSessionJson(Map<String, dynamic>.from(data));
    } on DioException {
      return null;
    }
  }

  /// Ferme la session (jette le cookie JWT).
  Future<void> logout() async {
    await ensureInitialized();
    final csrfToken = await _fetchCsrfToken();
    try {
      await dio.post<dynamic>(
        '/api/auth/signout',
        options: Options(contentType: Headers.formUrlEncodedContentType),
        data: {
          'csrfToken': csrfToken ?? '',
          'callbackUrl': '/',
          'json': 'true',
        },
      );
    } catch (_) {
      // Même en échec réseau : on purge localement.
    }
    await _cookieJar?.deleteAll();
  }

  Future<String?> _fetchCsrfToken() async {
    try {
      final response = await dio.get<dynamic>('/api/auth/csrf');
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        return data['csrfToken'] as String?;
      }
    } on DioException {
      return null;
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════
  //  REQUÊTES JSON UNIFORMES
  // ═════════════════════════════════════════════════════════════════

  /// GET JSON avec message d'erreur FR uniforme.
  Future<dynamic> getJson(String path, {Map<String, dynamic>? queryParameters}) async {
    await ensureInitialized();
    try {
      final response = await dio.get<dynamic>(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw ApiException(_messageDio(e));
    }
  }

  /// POST JSON avec message d'erreur FR uniforme.
  Future<dynamic> postJson(String path, {Object? body}) async {
    await ensureInitialized();
    try {
      final response = await dio.post<dynamic>(path, data: body);
      return response.data;
    } on DioException catch (e) {
      throw ApiException(_messageDio(e));
    }
  }

  String _messageDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String && (data['error'] as String).isNotEmpty) {
      return data['error'] as String;
    }
    if (data is String) {
      final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(data);
      if (m != null) return m.group(1)!;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Le serveur ne répond pas — vérifiez votre connexion.';
      case DioExceptionType.connectionError:
        return 'Connexion impossible — vérifiez votre accès internet.';
      default:
        break;
    }
    final status = e.response?.statusCode;
    if (status == 401) return 'Session expirée — reconnectez-vous.';
    if (status == 403) return 'Accès refusé.';
    if (status == 404) return 'Introuvable.';
    if (status != null && status >= 500) return 'Erreur serveur ($status) — réessayez.';
    return 'Erreur réseau inattendue.';
  }
}
