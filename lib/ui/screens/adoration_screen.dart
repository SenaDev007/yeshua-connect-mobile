/// ⭐ V2.0 — ADORATION & LOUVANGES (miroir de la page
/// /adoration-louanges du site, V3.79 web).
///
/// Page dédiée à Afrika, ARTISTE et CHANTRE de l'Éternel : ses clips,
/// ses adorations et ses louanges — catégorie « Adoration » d'un côté,
/// « Louanges » de l'autre (scission demandée par le pasteur), sans
/// mélanger la médiathèque générale.
///
/// ⭐ V2.7 — SCISION STRICTE : cette page ne retient QUE les chants des
/// catégories « Adoration » / « Louanges » (comme /adoration-louanges du
/// web) — tout ce qui est enseignement, exhortation ou direct reste sur
/// la page Vidéos & Lives.
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

    // ⭐ V2.7 — Scission STRICTE (miroir du web V3.79,
    // `estCategorieAdoration`) : seuls les chants d'Afrika des catégories
    // « Adoration » / « Louanges » vivent ici — ses enseignements,
    // exhortations et directs restent sur la page Vidéos & Lives. Plus
    // aucun mélange, ni dans un sens ni dans l'autre.
    final chantsAfrika = contenu.videos
        .where((v) => v.serviteur == 'afrika' && v.estChantAdoration)
        .toList();
    const categories = ['Adoration', 'Louanges'];

    var videos = chantsAfrika.where((v) {
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
          style: TextStyle(
              color: AppColors.texte,
              fontSize: 16.5,
              fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
