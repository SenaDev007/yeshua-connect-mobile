/// Racine de l'app : thème nuit/pourpre/or, localisation FR, routeur,
/// détection globale des appels entrants (sonnerie).
library;

import 'dart:async' show StreamSubscription, unawaited;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'state/contenu_controller.dart';
import 'state/incoming_call_controller.dart';

class ChristLibereApp extends ConsumerWidget {
  const ChristLibereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Christ Libère',
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
      builder: (context, child) =>
          _AnnonceGate(child: _IncomingCallGate(child: child)),
    );
  }
}

/// ⭐ V2.17 — ANNONCES DU MINISTÈRE : pont entre les notifications push
/// (PushService) et l'interface.
///
///   · App AU PREMIER PLAN quand l'annonce est publiée → SnackBar doré
///     « Nouvelle annonce du ministère » avec l'action « Ouvrir » (les
///     notifications système n'apparaissent pas d'elles-mêmes quand
///     l'app est ouverte).
///   · Ouverture d'une notification (app en arrière-plan ou terminée) →
///     navigation vers /app/annonces + resynchronisation immédiate du
///     contenu (l'annonce vient d'être publiée, le miroir SQLite local
///     ne l'a peut-être pas encore).
class _AnnonceGate extends ConsumerStatefulWidget {
  const _AnnonceGate({required this.child});

  final Widget? child;

  @override
  ConsumerState<_AnnonceGate> createState() => _AnnonceGateState();
}

class _AnnonceGateState extends ConsumerState<_AnnonceGate> {
  StreamSubscription<RemoteMessage>? _abonnementRecues;
  StreamSubscription<RemoteMessage>? _abonnementOuvertes;

  @override
  void initState() {
    super.initState();

    // Annonce reçue AU PREMIER PLAN → SnackBar (pas de navigation
    // forcée : l'utilisateur poursuit sa lecture, il ouvre s'il veut).
    _abonnementRecues = PushService.annoncesRecues.listen(_afficherSnackBar);

    // Ouverture d'une notification d'annonce → annonces du ministère.
    _abonnementOuvertes = PushService.annoncesOuvertes.listen((_) {
      if (mounted) _ouvrirAnnonces();
    });

    // App lancée DEPUIS une notification (elle était terminée) : le flux
    // a peut-être émis avant l'abonnement → cache consommé au démarrage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && PushService.prendreAnnonceInitiale() != null) {
        _ouvrirAnnonces();
      }
    });
  }

  @override
  void dispose() {
    _abonnementRecues?.cancel();
    _abonnementOuvertes?.cancel();
    super.dispose();
  }

  void _ouvrirAnnonces() {
    final router = GoRouter.of(context);
    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    // Jamais au beau milieu d'un appel (même garde que l'appel entrant).
    if (loc == '/app/appel-entrant' || loc == '/app/appel') return;

    // L'annonce vient d'être publiée : on resynchronise le miroir local
    // pour qu'elle apparaisse immédiatement (best-effort, hors ligne le
    // contenu existant s'affiche et la synchro reprendra plus tard).
    unawaited(ref.read(contenuProvider.notifier).synchroniser());

    router.go('/app/annonces');
  }

  void _afficherSnackBar(RemoteMessage message) {
    if (!mounted) return;
    final titre = message.notification?.title ?? 'Annonce du ministère';
    final corps = message.notification?.body;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.pourpre,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.orPastel,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            if (corps != null && corps.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                corps,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texteSecondaire,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
        action: SnackBarAction(
          label: 'Ouvrir',
          textColor: AppColors.or,
          onPressed: _ouvrirAnnonces,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
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
