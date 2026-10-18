/// Coque de l'app : barre inférieure (Discussions / Bible / Calendrier /
/// Recherche / Profil) reliée à un `StatefulShellRoute.indexedStack` (état
/// de chaque onglet préservé — même UX que le web).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../state/conversations_controller.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ⭐ V2.4 — RETOUR = ACCUEIL DU MINISTÈRE, JAMAIS une sortie de
      // l'application : depuis la communauté (racine de pile après un
      // login redirect, ou pile poussée), le bouton retour ramène
      // systématiquement à l'accueil public d'où l'on peut naviguer
      // entre tous les modules — au lieu de quitter Christ Libère.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/app');
      },
      child: Scaffold(
        backgroundColor: AppColors.nuit,
        // ⭐ V1.8 — bandeau doré « Mode hors-ligne » au-dessus du contenu :
        // visible dès que la connexion disparaît, disparaît dès qu'elle
        // revient (l'app continue d'afficher le cache local en dessous).
        body: Column(
          children: [
            const BandeauHorsLigne(),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.pourpre,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.or.withValues(alpha: 0.18),
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              icon: BadgeDiscussions(),
              selectedIcon: BadgeDiscussions(selected: true),
              label: 'Discussions',
            ),
            // ⭐ Bible — parité web V2.6 (BibleWorkspace intégré au chat).
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: AppColors.texteSecondaire),
              selectedIcon: Icon(Icons.menu_book, color: AppColors.or),
              label: 'Bible',
            ),
            // ⭐ Calendrier biblique + Shofar — parité web V3.6.
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: AppColors.texteSecondaire),
              selectedIcon: Icon(Icons.calendar_month, color: AppColors.or),
              label: 'Calendrier',
            ),
            NavigationDestination(
              icon: Icon(Icons.search, color: AppColors.texteSecondaire),
              selectedIcon: Icon(Icons.search, color: AppColors.or),
              label: 'Recherche',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.texteSecondaire),
              selectedIcon: Icon(Icons.person, color: AppColors.or),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône Discussions avec badge doré de non-lus (total).
class BadgeDiscussions extends ConsumerWidget {
  const BadgeDiscussions({super.key, this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(conversationsProvider).totalUnread;
    final icone = Icon(
      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
      color: selected ? AppColors.or : AppColors.texteSecondaire,
    );
    if (total <= 0) return icone;
    return Badge(
      backgroundColor: AppColors.or,
      textColor: AppColors.nuit,
      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      label: Text(total > 99 ? '99+' : '$total'),
      child: icone,
    );
  }
}

/// ⭐ V1.8 — Bandeau hors-ligne : suivi en direct de la connectivité.
/// Hors ligne → bandeau doré « dernières données enregistrées » ;
/// en ligne → hauteur nulle (invisible).
class BandeauHorsLigne extends StatefulWidget {
  const BandeauHorsLigne({super.key});

  @override
  State<BandeauHorsLigne> createState() => _BandeauHorsLigneState();
}

class _BandeauHorsLigneState extends State<BandeauHorsLigne> {
  bool _horsLigne = false;
  StreamSubscription<bool>? _abonnement;

  @override
  void initState() {
    super.initState();
    _horsLigne = !Connectivite.instance.enLigne;
    _abonnement = Connectivite.instance.flux.listen((enLigne) {
      if (mounted) setState(() => _horsLigne = !enLigne);
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_horsLigne) return const SizedBox.shrink();
    return const Material(
      color: AppColors.or,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 15, color: AppColors.nuit),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mode hors-ligne — affichage des dernières données enregistrées. '
                'Envois, appels et vidéos nécessitent internet.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.nuit,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
