/// Coque de l'app : barre inférieure (Discussions / Bible / Calendrier /
/// Recherche / Profil) reliée à un `StatefulShellRoute.indexedStack` (état
/// de chaque onglet préservé — même UX que le web).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/conversations_controller.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      body: navigationShell,
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
