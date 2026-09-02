/// Navigation : splash → login ⇄ app (coque à onglets persistants).
///
/// Le routeur est exposé via un [Provider] : il peut ÉCOUTER l'état
/// d'authentification (Riverpod) et déclencher ses `redirect` via un
/// `refreshListenable` (GoRouter exige un Listenable pur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/auth_controller.dart';
import '../../ui/screens/annonces_screen.dart';
import '../../ui/screens/bible_screen.dart';
import '../../ui/screens/bloques_screen.dart';
import '../../ui/screens/calendar_screen.dart';
import '../../ui/screens/call_screen.dart';
import '../../ui/screens/chat_screen.dart';
import '../../ui/screens/conversations_screen.dart';
import '../../ui/screens/home_shell.dart';
import '../../ui/screens/incoming_call_screen.dart';
import '../../ui/screens/live_screen.dart';
import '../../ui/screens/login_screen.dart';
import '../../ui/screens/members_screen.dart';
import '../../ui/screens/profile_screen.dart';
import '../../ui/screens/programmes_screen.dart';
import '../../ui/screens/search_screen.dart';
import '../../ui/screens/splash_screen.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // ── Onglet Discussions (+ chat, membres, appels) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app',
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
                path: '/app/bible',
                builder: (context, state) => const BibleScreen(),
              ),
            ],
          ),
          // ── Onglet Calendrier biblique + Shofar (parité web V3.6) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/calendrier',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          // ── Onglet Recherche ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/recherche',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // ── Onglet Profil (moi + fiches membres) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profil',
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

      if (!connecte && !surEntree) return '/login';
      if (connecte && surEntree) return '/app';
      return null;
    },
    refreshListenable: cache,
  );
});
