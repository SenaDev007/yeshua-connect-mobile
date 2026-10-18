/// ⭐ V2.0 — ADORATION & LOUVANGES (miroir de la page
/// /adoration-louanges du site, V3.79 web).
///
/// Page dédiée à Afrika, ARTISTE et CHANTRE de l'Éternel : ses clips,
/// ses adorations et ses louanges — catégorie « Adoration » d'un côté,
/// « Louanges » de l'autre (scission demandée par le pasteur), sans
/// mélanger la médiathèque générale.
///
/// Même lecture que la page Vidéos : MP4 hébergés → lecteur intégré ;
/// YouTube / TikTok → app officielle. HORS-LIGNE : catalogue local.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';
import 'videos_screen.dart';

class AdorationScreen extends ConsumerStatefulWidget {
  const AdorationScreen({super.key});

  @override
  ConsumerState<AdorationScreen> createState() => _AdorationScreenState();
}

class _AdorationScreenState extends ConsumerState<AdorationScreen> {
  String _onglet = 'Tous';

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageAdoration(enfant: EtatPremiereSync());
    }

    // Scission Adoration / Louanges d'Afrika (même règle que le web :
    // catégories de la servante « afrika » uniquement).
    final videosAfrika = contenu.videos.where((v) => v.serviteur == 'afrika').toList();
    final categories = videosAfrika.map((v) => v.categorie).where((c) => c.isNotEmpty).toSet().toList()
      ..sort();

    var videos = videosAfrika.where((v) {
      if (_onglet == 'Tous') return true;
      return v.categorie == _onglet;
    }).toList();

    return _PageAdoration(
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('adoration-louanges'), hauteur: 170),
          // ── Onglets Adoration / Louanges ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: [
                PuceFiltre(
                  libelle: 'Tous',
                  actif: _onglet == 'Tous',
                  onTap: () => setState(() => _onglet = 'Tous'),
                ),
                const SizedBox(width: 7),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: PuceFiltre(
                      libelle: c,
                      actif: _onglet == c,
                      onTap: () => setState(() => _onglet = c),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: videos.isEmpty
                ? const EtatSectionVide(
                    message:
                        'Aucun chant publié pour cette catégorie — les adorations '
                        'publiées par Afrika depuis le back-office apparaîtront ici.')
                : GrilleVideos(videos: videos),
          ),
        ],
      ),
    );
  }
}

/// Scaffold commun.
class _PageAdoration extends StatelessWidget {
  final Widget enfant;

  const _PageAdoration({required this.enfant});

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
          'Adoration & Louanges',
          style: TextStyle(color: AppColors.texte, fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
