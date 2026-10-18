/// ⭐ V2.0 — Navigation : splash → accueil public (landing + tiroir) ;
/// Yeshua Connect (shell à onglets) sous `/app/connect` — connexion
/// requise ; pages de contenu du ministère PUBLIQUES (aucune connexion
/// requise, lisibles hors ligne depuis la base SQLite locale).
///
/// Le routeur est exposé via un [Provider] : il peut ÉCOUTER l'état
/// d'authentification (Riverpod) et déclencher ses `redirect` via un
/// `refreshListenable` (GoRouter exige un Listenable pur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/auth_controller.dart';
import '../../ui/screens/accueil_screen.dart';
import '../../ui/screens/annonces_ministere_screen.dart';
import '../../ui/screens/annonces_screen.dart';
import '../../ui/screens/adoration_screen.dart';
import '../../ui/screens/bible_screen.dart';
import '../../ui/screens/bloques_screen.dart';
import '../../ui/screens/calendar_screen.dart';
import '../../ui/screens/call_screen.dart';
import '../../ui/screens/chat_screen.dart';
import '../../ui/screens/contribuer_screen.dart';
import '../../ui/screens/conversations_screen.dart';
import '../../ui/screens/disperses_screen.dart';
import '../../ui/screens/enseignements_screen.dart';
import '../../ui/screens/home_shell.dart';
import '../../ui/screens/intercession_screen.dart';
import '../../ui/screens/incoming_call_screen.dart';
import '../../ui/screens/live_screen.dart';
import '../../ui/screens/login_screen.dart';
import '../../ui/screens/members_screen.dart';
import '../../ui/screens/profile_screen.dart';
import '../../ui/screens/programmes_screen.dart';
import '../../ui/screens/rendezvous_screen.dart';
import '../../ui/screens/search_screen.dart';
import '../../ui/screens/serviteur_screen.dart';
import '../../ui/screens/splash_screen.dart';
import '../../ui/screens/temoignages_screen.dart';
import '../../ui/screens/videos_screen.dart';
import '../../ui/screens/voice_channel_screen.dart';

/// Cache du statut d'auth — pont Riverpod → Listenable GoRouter.
class _AuthStatusCache extends ChangeNotifier {
  AuthStatus value = AuthStatus.unknown;

  /// Mise à jour publique (notifyListeners est protégé → encapsulé).
  void update(AuthStatus status) {
    if (value == status) return;
    value = status;
    notifyListeners();
  }
}

/// ⭐ V2.0 — Préfixes protégés (connexion requise) : uniquement la
/// COMMUNAUTÉ (messagerie, appels, recherche, profil) — tout le contenu
/// du ministère (témoignages, enseignements, vidéos, adoration, Bible,
/// calendrier, annonces, rendez-vous…) est PUBLIC, comme sur le site.
const _prefixesProteges = [
  '/app/connect',
  '/app/recherche',
  '/app/profil',
  '/app/appel',
];

bool _estProtege(String loc) {
  // Les routes tab du shell vivent sous /app/connect/* — les autres
  // préfixes couvrent les accès directs historiques.
  return _prefixesProteges.any((p) => loc == p || loc.startsWith('$p/'));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final cache = _AuthStatusCache();
  ref.listen<AuthState>(authProvider, (previous, next) {
    cache.update(next.status);
  });
  ref.onDispose(cache.dispose);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ═════════════════════════════════════════════════════════════
      //  ⭐ V2.0 — ACCUEIL PUBLIC (landing) + PAGES DU MINISTÈRE
      //  (aucune connexion requise — contenu servi par SQLite locale)
      // ═════════════════════════════════════════════════════════════
      GoRoute(
        path: '/app',
        builder: (context, state) => const AccueilScreen(),
        routes: [
          GoRoute(
            path: 'serviteur/:code',
            builder: (context, state) =>
                ServiteurScreen(code: state.pathParameters['code'] ?? 'afrika'),
          ),
          GoRoute(
            path: 'temoignages',
            builder: (context, state) => const TemoignagesScreen(),
          ),
          GoRoute(
            path: 'enseignements',
            builder: (context, state) => const EnseignementsScreen(),
          ),
          GoRoute(
            path: 'videos',
            builder: (context, state) => const VideosScreen(),
          ),
          GoRoute(
            path: 'adoration',
            builder: (context, state) => const AdorationScreen(),
          ),
          // Bible & calendrier : PUBLIQUES aussi sur le web — mêmes écrans
          // que les onglets de la communauté, servis ici SANS connexion.
          GoRoute(
            path: 'bible',
            builder: (context, state) => const BibleScreen(),
          ),
          GoRoute(
            path: 'calendrier',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: 'intercession',
            builder: (context, state) => const IntercessionScreen(),
          ),
          GoRoute(
            path: 'disperses',
            builder: (context, state) => const DispersesScreen(),
          ),
          GoRoute(
            path: 'contribuer',
            builder: (context, state) => const ContribuerScreen(),
          ),
          GoRoute(
            path: 'annonces',
            builder: (context, state) => const AnnoncesMinistereScreen(),
          ),
          GoRoute(
            path: 'rendez-vous',
            builder: (context, state) => const RendezVousScreen(),
          ),
        ],
      ),

      // ═════════════════════════════════════════════════════════════
      //  YESHUA CONNECT — communauté (connexion requise)
      // ═════════════════════════════════════════════════════════════
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // ── Onglet Discussions (+ chat, membres, appels) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/connect',
                builder: (context, state) => const ConversationsScreen(),
                routes: [
                  // ⭐ V1.5 — Live public (viewer, mode YouTube V3.22).
                  GoRoute(
                    path: 'live',
                    builder: (context, state) => const LiveScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) =>
                            LiveScreen(liveId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'chat/:id',
                    builder: (context, state) =>
                        ChatScreen(conversationId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'membres',
                        builder: (context, state) => MembersScreen(
                          conversationId: state.pathParameters['id']!,
                        ),
                      ),
                      // ⭐ Canaux vocaux persistants — écran dédié.
                      GoRoute(
                        path: 'canal-vocal',
                        builder: (context, state) => VoiceChannelScreen(
                          conversationId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'appel',
                    builder: (context, state) => const CallScreen(),
                  ),
                  GoRoute(
                    path: 'appel-entrant',
                    builder: (context, state) => const IncomingCallScreen(),
                  ),
                ],
              ),
            ],
          ),
          // ── Onglet Bible — écran dédié (parité web V2.6) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/connect/bible',
                builder: (context, state) => const BibleScreen(),
              ),
            ],
          ),
          // ── Onglet Calendrier biblique + Shofar (parité web V3.6) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/connect/calendrier',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          // ── Onglet Recherche ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/connect/recherche',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // ── Onglet Profil (moi + fiches membres) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/connect/profil',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  // ⭐ V1.5 — Routes statiques AVANT :userId (priorité de
                  // correspondance GoRouter = ordre de déclaration).
                  GoRoute(
                    path: 'bloques',
                    builder: (context, state) => const BloquesScreen(),
                  ),
                  GoRoute(
                    path: 'annonces',
                    builder: (context, state) => const AnnoncesScreen(),
                  ),
                  GoRoute(
                    path: 'programmes',
                    builder: (context, state) => const ProgrammesScreen(),
                  ),
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) =>
                        ProfileScreen(userId: state.pathParameters['userId']),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final status = cache.value;
      final loc = state.uri.toString();

      // Session pas encore restaurée : on laisse le splash travailler.
      if (status == AuthStatus.unknown || status == AuthStatus.loading) {
        return loc == '/' ? null : '/';
      }

      final connecte = status == AuthStatus.authenticated;
      final surEntree = loc == '/login' || loc == '/';

      // Contenu du ministère : PUBLIC — jamais de redirection forcée.
      if (_estProtege(loc) && !connecte) return '/login';
      if (connecte && surEntree) return '/app';
      return null;
    },
    refreshListenable: cache,
  );
});
