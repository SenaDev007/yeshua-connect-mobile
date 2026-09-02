/// Racine de l'app : thème nuit/pourpre/or, localisation FR, routeur,
/// détection globale des appels entrants (sonnerie).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/incoming_call_controller.dart';

class YeshuaConnectApp extends ConsumerWidget {
  const YeshuaConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Yeshua Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => _IncomingCallGate(child: child),
    );
  }
}

/// Surveille les appels entrants POUR MOI (polling `?incoming=1`) et
/// ouvre l'écran de sonnerie plein écran dès qu'un appel sonne.
///
/// ⭐ L'écran affiche le nom de L'APPELANT (V1.1) — voir
/// `IncomingCallModel.displayTitle`.
class _IncomingCallGate extends ConsumerWidget {
  const _IncomingCallGate({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<IncomingCallState>(incomingCallProvider, (previous, next) {
      final appel = next.actuel;
      if (appel == null) return;

      final router = GoRouter.of(context);
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      // Une seule sonnerie à la fois : on n'écrase pas les écrans d'appel.
      if (loc == '/app/appel-entrant' || loc == '/app/appel') return;
      router.go('/app/appel-entrant');
    });

    return child ?? const SizedBox.shrink();
  }
}
