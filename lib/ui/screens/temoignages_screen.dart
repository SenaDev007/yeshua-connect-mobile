/// ⭐ V2.0 — TÉMOIGNAGES (miroir de la page /temoignages du site).
///
/// Liste des témoignages CONFIRMÉS (Afrika et Pasteur Kongo) avec filtres
/// par thème et par serviteur, puis fiche de lecture complète.
///
/// HORS-LIGNE : tout vient de la base SQLite locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class TemoignagesScreen extends ConsumerStatefulWidget {
  const TemoignagesScreen({super.key});

  @override
  ConsumerState<TemoignagesScreen> createState() => _TemoignagesScreenState();
}

class _TemoignagesScreenState extends ConsumerState<TemoignagesScreen> {
  String? _theme;
  String _serviteur = 'all';

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageTemoignages(enfant: EtatPremiereSync());
    }

    final themes = contenu.temoignages
        .expand((t) => t.themes)
        .toSet()
        .toList()
      ..sort();

    var temoignages = contenu.temoignages.where((t) {
      if (_serviteur != 'all' && t.serviteur != _serviteur) return false;
      if (_theme != null && !t.themes.contains(_theme)) return false;
      return true;
    }).toList();

    return _PageTemoignages(
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('temoignages'), hauteur: 150),
          // ── Filtres ──
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: [
                PuceFiltre(
                  libelle: 'Tous',
                  actif: _theme == null,
                  onTap: () => setState(() => _theme = null),
                ),
                const SizedBox(width: 7),
                ...themes.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: PuceFiltre(
                      libelle: t,
                      actif: _theme == t,
                      onTap: () => setState(() => _theme = t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              children: [
                PuceFiltre(
                  libelle: 'Tous les serviteurs',
                  actif: _serviteur == 'all',
                  onTap: () => setState(() => _serviteur = 'all'),
                ),
                const SizedBox(width: 7),
                ...contenu.serviteurs.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: PuceFiltre(
                      libelle: s.nomCourt,
                      actif: _serviteur == s.code,
                      onTap: () => setState(() => _serviteur = s.code),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Liste ──
          Expanded(
            child: temoignages.isEmpty
                ? const EtatSectionVide(
                    message: 'Aucun témoignage ne correspond à ces filtres.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    itemCount: temoignages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CarteTemoignage(
                      temoignage: temoignages[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _LectureTemoignage(
                            temoignage: temoignages[i],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE D'UN TÉMOIGNAGE
// ═══════════════════════════════════════════════════════════════════

class _CarteTemoignage extends StatelessWidget {
  final TemoignageModele temoignage;
  final VoidCallback onTap;

  const _CarteTemoignage({required this.temoignage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: AppColors.or),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  temoignage.titre,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            temoignage.resume,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texteSecondaire,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...temoignage.themes.take(3).map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.nuit,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(color: AppColors.orPastel, fontSize: 10.5),
                        ),
                      ),
                    ),
                  ),
              const Spacer(),
              if (temoignage.tempsLecture.isNotEmpty)
                Text(
                  temoignage.tempsLecture,
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FICHE DE LECTURE COMPLÈTE
// ═══════════════════════════════════════════════════════════════════

class _LectureTemoignage extends StatelessWidget {
  final TemoignageModele temoignage;

  const _LectureTemoignage({required this.temoignage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: Text(
          temoignage.nomServiteur,
          style: const TextStyle(color: AppColors.texte, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Text(
            temoignage.titre,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (temoignage.referenceLivre.isNotEmpty) ...[
                const Icon(Icons.menu_book_outlined, size: 13, color: AppColors.or),
                const SizedBox(width: 4),
                Text(
                  temoignage.referenceLivre,
                  style: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
                ),
                const SizedBox(width: 10),
              ],
              if (temoignage.tempsLecture.isNotEmpty)
                Text(
                  '· ${temoignage.tempsLecture}',
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            temoignage.contenu,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 14.5,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold commun.
class _PageTemoignages extends StatelessWidget {
  final Widget enfant;

  const _PageTemoignages({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Témoignages',
          style: TextStyle(color: AppColors.texte, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
