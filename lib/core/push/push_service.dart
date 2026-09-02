/// ⭐ V1.4 — Notifications push (FCM) de Yeshua Connect.
///
/// L'application est prévenue — MÊME FERMÉE ou en arrière-plan — quand :
///   • quelqu'un l'appelle en privé (notification haute priorité) ;
///   • elle reçoit un message privé.
///
/// ARCHITECTURE (identique au web, zéro secret dans l'APK) :
///   • Les identifiants Firebase PUBLICS arrivent par `--dart-define`
///     (FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_SENDER_ID,
///     FIREBASE_PROJECT_ID) — construisables sur la machine du pasteur SANS
///     google-services.json ;
///   • Le token FCM de l'appareil est envoyé au backend du projet mère
///     (POST /api/yeshua-connect/devices) qui seul détient la clé privée
///     du compte de service (Vercel) et déclenche les envois ;
///   • Sans identifiants fournis : le push se désactive PROPREMENT (aucune
///     erreur, tout le reste de l'app fonctionne à l'identique).
///
/// Android : les notifications envoyées par le serveur (payload
/// `notification`) s'affichent automatiquement dans le bac système quand
/// l'app est en arrière-plan/fermée — aucun plugin d'affichage requis.
/// iOS : nécessite APNs configuré côté Firebase (voir
/// deploy/push-notifications/README.md du dépôt web).
library;

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../data/api/api_client.dart';

/// Identifiants Firebase publics injectés au build :
/// flutter build apk --release --dart-define=FIREBASE_API_KEY=... etc.
const String _kApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const String _kAppId = String.fromEnvironment('FIREBASE_APP_ID');
const String _kSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const String _kProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

/// Le push est-il activé sur CE build ?
bool get pushConfigured =>
    _kApiKey.isNotEmpty &&
    _kAppId.isNotEmpty &&
    _kSenderId.isNotEmpty &&
    _kProjectId.isNotEmpty;

/// Handler d'arrière-plan (doit être une fonction de HAUT NIVEAU).
/// Les messages avec payload `notification` sont affichés par le système
/// AVANT même ce handler ; il sert aux messages data et au maintien du
/// canal FCM ouvert.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Rien à faire localement : la sonnerie d'appel et le badge de messages
  // sont repris par le polling au lancement de l'app.
}

/// État mutable du service (séparé de la classe pour permettre un
/// constructeur `const` — exigé par le linter `prefer_const_constructors`).
class _PushState {
  FirebaseMessaging? messaging;
  String? lastToken;
  bool registered = false;
}

final _PushState _state = _PushState();

class PushService {
  const PushService._();

  static const PushService instance = PushService._();

  bool get isAvailable => _state.messaging != null;

  /// Initialise Firebase + FCM si les identifiants sont fournis au build.
  /// À appeler UNE fois au démarrage (main) — silencieux si non configuré.
  Future<void> init() async {
    if (!pushConfigured) {
      // Pas d'identifiants → build sans push : tout le reste fonctionne.
      return;
    }
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _kApiKey,
          appId: _kAppId,
          messagingSenderId: _kSenderId,
          projectId: _kProjectId,
        ),
      );
      final messaging = FirebaseMessaging.instance;
      _state.messaging = messaging;

      // Messages reçus en arrière-plan (fonction de haut niveau).
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Rotation du token → ré-enregistrement au backend.
      messaging.onTokenRefresh.listen((_) {
        _state.registered = false;
        _state.lastToken = null;
        // Si une session est déjà ouverte, on ré-enregistre immédiatement.
        registerIfAuthenticated();
      });
    } catch (_) {
      // Firebase indisponible sur CET appareil/build → push désactivé,
      // aucune conséquence sur le reste de l'application.
      _state.messaging = null;
    }
  }

  /// Demande la permission de notification (Android 13+, iOS) puis
  /// enregistre le token au backend. À appeler APRÈS une connexion
  /// réussie (le serveur associe le token à l'utilisateur de la SESSION).
  Future<void> registerIfAuthenticated() async {
    final messaging = _state.messaging;
    if (messaging == null) return;

    try {
      // Permission (nécessaire Android 13+ / iOS) — si refusée, on n'insiste
      // pas : l'utilisateur pourra l'activer dans les réglages du téléphone.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token == _state.lastToken) return;
      _state.lastToken = token;

      // Enregistrement auprès du backend partagé (userId = session serveur,
      // JAMAIS envoyé depuis le mobile — même règle que partout).
      await ApiClient.instance.postJson(
        '/api/yeshua-connect/devices',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      _state.registered = true;
    } on ApiException {
      // Session expirée / réseau : retenté à la prochaine connexion.
    } catch (_) {
      // Best effort — jamais bloquant.
    }
  }

  /// Désactive l'appareil au backend (déconnexion volontaire : plus aucune
  /// notification envoyée jusqu'à la prochaine connexion).
  Future<void> unregister() async {
    final token = _state.lastToken;
    if (token == null || !_state.registered) return;
    try {
      await ApiClient.instance.deleteJson(
        '/api/yeshua-connect/devices',
        queryParameters: {'token': token},
      );
    } catch (_) {
      // Best effort.
    } finally {
      _state.registered = false;
    }
  }
}
