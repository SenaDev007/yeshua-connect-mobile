/// ⭐ V2.0 — VIDÉOS & LIVES (miroir de la page /videos du site).
///
/// Médiathèque complète : filtres par catégorie (rubriques signature,
/// même logique que le web), par serviteur, recherche, miniatures,
/// compteur de vues et de likes. Les lives programmés s'affichent en
/// tête.
///
/// LECTURE 100 % INTÉGRÉE (exigence pasteur V2.2 — aucune sortie vers
/// les apps YouTube/TikTok) :
///   · MP4 hébergé chez nous (copie R2 TikTok, replays) → lecteur NATIF ;
///   · YouTube / TikTok → lecteur WEB EMBARQUÉ (iframe officielle,
///     exactement comme le site public).
///
/// HORS-LIGNE : catalogue, miniatures et métadonnées depuis SQLite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/contenu_widgets.dart';
import 'page_video_screen.dart';

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  String? _categorie;
  String _serviteur = 'all';
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageVideos(enfant: EtatPremiereSync());
    }

    // ⭐ V2.7 — SCISION (miroir du web V3.79) : les chants des catégories
    // « Adoration » / « Louanges » vivent sur la page DÉDIÉE Adoration &
    // Louanges — la médiathèque Vidéos & Lives reste concentrée sur les
    // enseignements vidéo, les directs et les témoignages.
    final videosPubliques =
        contenu.videos.where((v) => !v.estChantAdoration).toList();

    final categories = videosPubliques
        .map((v) => v.categorie)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    var videos = videosPubliques.where((v) {
      if (_serviteur != 'all' && v.serviteur != _serviteur) return false;
      if (_categorie != null && v.categorie != _categorie) return false;
      if (_recherche.isNotEmpty &&
          !v.titre.toLowerCase().contains(_recherche.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return _PageVideos(
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('videos'), hauteur: 150),
          // ── Recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v),
              style: const TextStyle(color: AppColors.texte, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher une vidéo…',
                hintStyle:
                    const TextStyle(color: AppColors.texteEteint, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.or, size: 20),
                filled: true,
                fillColor: AppColors.pourpre,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pourpreClair),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pourpreClair),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.or),
                ),
              ),
            ),
          ),
          // ── Filtres catégorie ──
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              children: [
                PuceFiltre(
                  libelle: 'Tout',
                  actif: _categorie == null,
                  onTap: () => setState(() => _categorie = null),
                ),
                const SizedBox(width: 7),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: PuceFiltre(
                      libelle: c,
                      actif: _categorie == c,
                      onTap: () => setState(() => _categorie = c),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Filtres serviteur ──
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              children: [
                PuceFiltre(
                  libelle: 'Tous',
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
            child: GrilleVideos(videos: videos),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  GRILLE PUBLIQUE (réutilisée par la page Adoration & Louanges)
// ═══════════════════════════════════════════════════════════════════

class GrilleVideos extends StatelessWidget {
  final List<VideoModele> videos;

  const GrilleVideos({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const EtatSectionVide(
          message: 'Aucune vidéo ne correspond à ces filtres.');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: videos.length,
      itemBuilder: (context, i) => CarteVideo(video: videos[i], toutes: videos),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE D'UNE VIDÉO (miniature + titre + stats)
// ═══════════════════════════════════════════════════════════════════

class CarteVideo extends StatelessWidget {
  final VideoModele video;

  /// Toutes les vidéos du contexte (grille filtrée) — la page vidéo
  /// unifiée s'en sert pour proposer les VIDÉOS SIMILAIRES (comme le
  /// web qui transmet allVideos à son lecteur).
  final List<VideoModele> toutes;

  const CarteVideo({super.key, required this.video, required this.toutes});

  /// Ouvre la PAGE VIDÉO UNIFIÉE (⭐ V2.9 — même structure que le web) :
  /// lecteur intégré + titre + vues/likes + J'aime + Partager +
  /// description + vidéos similaires à côté. Le type de lecteur est
  /// choisi par la page (YouTube embed web / natif R2 / TikTok embed).
  void ouvrir(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageVideoScreen(video: video, toutes: toutes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: EdgeInsets.zero,
      onTap: () => ouvrir(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Miniature ──
          Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9.6,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  child: ImageUniverselle(
                    url: resoudreUrl(video.miniatureUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.nuit.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.play_arrow, color: AppColors.or, size: 26),
              ),
              // Badge source (YouTube / TikTok / hébergé)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.nuit.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _BadgeSource(video: video),
                ),
              ),
            ],
          ),
          // ── Titre + stats ──
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 11, color: AppColors.texteEteint),
                    const SizedBox(width: 3),
                    Text(
                      _compte(video.vues),
                      style: const TextStyle(
                          color: AppColors.texteEteint, fontSize: 10.5),
                    ),
                    const SizedBox(width: 9),
                    const Icon(Icons.favorite_outline,
                        size: 11, color: AppColors.texteEteint),
                    const SizedBox(width: 3),
                    Text(
                      _compte(video.likes),
                      style: const TextStyle(
                          color: AppColors.texteEteint, fontSize: 10.5),
                    ),
                    const Spacer(),
                    if (video.categorie.isNotEmpty)
                      Flexible(
                        child: Text(
                          video.categorie,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.orPastel, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _compte(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} k';
    return '$n';
  }
}

class _BadgeSource extends StatelessWidget {
  final VideoModele video;

  const _BadgeSource({required this.video});

  @override
  Widget build(BuildContext context) {
    if (video.lisibleDansLapp) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_outlined, size: 10, color: AppColors.enLigne),
          SizedBox(width: 3),
          Text('Hébergé',
              style: TextStyle(color: AppColors.enLigne, fontSize: 9.5)),
        ],
      );
    }
    if (video.youtubeId.isNotEmpty) {
      return const Text('YouTube',
          style: TextStyle(color: AppColors.texteSecondaire, fontSize: 9.5));
    }
    if (video.tiktokId.isNotEmpty) {
      return const Text('TikTok',
          style: TextStyle(color: AppColors.texteSecondaire, fontSize: 9.5));
    }
    return const Text('Vidéo',
        style: TextStyle(color: AppColors.texteSecondaire, fontSize: 9.5));
  }
}

/// Scaffold commun.
class _PageVideos extends StatelessWidget {
  final Widget enfant;

  const _PageVideos({required this.enfant});

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
          'Vidéos & Lives',
          style: TextStyle(
              color: AppColors.texte,
              fontSize: 17,
              fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
