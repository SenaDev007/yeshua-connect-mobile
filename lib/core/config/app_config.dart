/// Configuration centrale de Yeshua Connect.
///
/// ⭐ MÊME BACKEND QUE LE PROJET MÈRE — le dépôt GitHub du mobile est
/// séparé (`yeshua-connect-mobile`) mais l'application consomme
/// EXCLUSIVEMENT le backend du projet web `Mouvement-Christ-Libere` :
/// toutes les routes `/api/*` (auth NextAuth, conversations, appels,
/// arbitrage multimédia LiveKit → Agora → Daily, Bible, calendrier
/// biblique…) y sont servies avec la même session que le navigateur.
/// Aucune donnée n'est stockée ailleurs — Prisma/PostgreSQL du web,
/// rien de local.
///
/// L'URL est figée sur la production Vercel ; elle peut être surchargée
/// SANS toucher au code pour brancher un backend local de développement :
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
/// flutter build apk --release  # → production (défaut) sans dart-define
/// ```
library;

class AppConfig {
  AppConfig._();

  /// URL de base de la plateforme (production Vercel) — backend PARTAGÉ
  /// avec le projet mère `Mouvement-Christ-Libere`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mouvement-christ-libere.vercel.app',
  );

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
