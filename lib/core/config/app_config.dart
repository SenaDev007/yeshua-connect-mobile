/// Configuration centrale de Yeshua Connect.
///
/// L'API est celle de la plateforme web du Mouvement Christ Libère :
/// toutes les routes `/api/yeshua-connect/*` y sont servies avec la même
/// session NextAuth que le navigateur.
library;

class AppConfig {
  AppConfig._();

  /// URL de base de la plateforme (production Vercel).
  static const String apiBaseUrl = 'https://mouvement-christ-libere.vercel.app';

  /// Clé SharedPreferences pour savoir si une session a déjà été ouverte.
  static const String kSessionFlagKey = 'yc_session_flag';

  // ── Polling (secondes) — même cadence que le web ──
  /// Rafraîchissement de la liste des conversations (≈ heartbeat présence).
  static const int conversationsPollSeconds = 10;

  /// Nouveaux messages d'un chat ouvert.
  static const int chatPollSeconds = 4;

  /// Détection des appels entrants (sonnerie).
  static const int incomingCallPollSeconds = 3;

  /// Statut d'un appel en cours (décroché / raccroché à distance).
  static const int callStatusPollSeconds = 2;
}
