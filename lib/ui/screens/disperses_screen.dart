/// ⭐ V2.2 — DISPERSÉS D'ISOLÉLÉ (miroir de la page /disperses).
///
/// La carte mondiale des dispersés — même rendu que le site public :
/// carte en points (dotted-map) avec épingles dorées pulsantes par pays.
/// Les statistiques viennent de la synchronisation locale (hors ligne) ;
/// l'ajout de SA position se fait via le compte membre (page profil web).
///
/// NB : « Isolélé (Israël) » — orthographe officielle du Mouvement
/// (directive pastorale V3.45, cf. lib/isolole du site web).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

/// Noms français des pays les plus représentés (codes ISO 2 lettres).
const _nomsPays = {
  'CI': 'Côte d\'Ivoire', 'SN': 'Sénégal', 'BJ': 'Bénin', 'TG': 'Togo',
  'FR': 'France', 'NG': 'Nigéria', 'CM': 'Cameroun', 'CD': 'RD Congo',
  'US': 'États-Unis', 'GB': 'Royaume-Uni', 'CA': 'Canada', 'IL': 'Israël',
  'DE': 'Allemagne', 'ES': 'Espagne', 'BE': 'Belgique', 'IT': 'Italie',
  'BR': 'Brésil', 'MX': 'Mexique', 'ET': 'Éthiopie', 'ZA': 'Afrique du Sud',
  'AU': 'Australie', 'JP': 'Japon', 'GH': 'Ghana', 'MA': 'Maroc',
  'CG': 'Congo', 'GA': 'Gabon', 'ML': 'Mali', 'BF': 'Burkina Faso',
  'NE': 'Niger', 'TD': 'Tchad', 'RW': 'Rwanda', 'KE': 'Kenya',
  'LU': 'Luxembourg', 'CH': 'Suisse', 'PT': 'Portugal', 'NL': 'Pays-Bas',
  'SE': 'Suède', 'NO': 'Norvège', 'AT': 'Autriche', 'GR': 'Grèce',
  'RO': 'Roumanie', 'TR': 'Turquie', 'IN': 'Inde', 'CN': 'Chine',
  'HT': 'Haïti', 'RU': 'Russie',
};

/// Centres approximatifs des pays (latitude, longitude) — pour poser les
/// épingles sur la carte (même projection Mercator que le site web).
const _centroidsPays = <String, (double, double)>{
  'CI': (7.5, -5.5), 'SN': (14.5, -14.5), 'BJ': (9.5, 2.3),
  'TG': (8.6, 1.0), 'FR': (46.6, 2.2), 'NG': (9.1, 8.7),
  'CM': (5.7, 12.7), 'CD': (-2.9, 23.6), 'US': (39.8, -98.6),
  'GB': (54.0, -2.0), 'CA': (56.1, -106.3), 'IL': (31.4, 34.9),
  'DE': (51.1, 10.4), 'ES': (40.2, -3.7), 'BE': (50.6, 4.6),
  'IT': (42.8, 12.8), 'BR': (-10.8, -52.9), 'MX': (23.9, -102.5),
  'ET': (8.6, 39.6), 'ZA': (-29.0, 25.1), 'AU': (-25.7, 134.5),
  'JP': (36.5, 138.0), 'GH': (7.9, -1.0), 'MA': (31.8, -7.1),
  'CG': (-0.8, 15.8), 'GA': (-0.6, 11.8), 'ML': (17.6, -4.0),
  'BF': (12.2, -1.6), 'NE': (17.6, 8.1), 'TD': (15.4, 18.7),
  'RW': (-1.9, 29.9), 'KE': (0.2, 37.9), 'LU': (49.8, 6.1),
  'CH': (46.8, 8.2), 'PT': (39.4, -8.2), 'NL': (52.1, 5.3),
  'SE': (60.1, 18.6), 'NO': (60.5, 8.5), 'AT': (47.5, 14.6),
  'GR': (39.1, 21.8), 'RO': (45.9, 25.0), 'TR': (39.0, 35.2),
  'IN': (20.6, 78.9), 'CN': (35.9, 104.2), 'HT': (18.9, -72.3),
  'RU': (61.5, 90.0),
};

// ── Calibration de la carte « dotted-map » ──────────────────────────
// L'asset assets/images/carte-monde-disperses.png est généré depuis la
// MÊME librairie que le site (dotted-map, height 80, grille diagonale,
// fond #1A0826) — sa viewBox fait 158 × 80 et la projection est la
// Mercator de la librairie (constantes mesurées ci-dessous).
const double _kLargeurVue = 158.0;
const double _kHauteurVue = 80.0;
const double _kRayon = 6378137.0; // WGS84
const double _kXMin = -18701674.453269962;
const double _kXRange = 37403348.906539924;
const double _kYMax = 11361819.887676764;
const double _kYRange = 18884783.128941886;

/// Projette (lat, lng) en coordonnées de la carte (0..158 × 0..80).
Offset _projeter(double lat, double lng) {
  final lngRad = lng * math.pi / 180;
  final latRad = lat * math.pi / 180;
  final mercX = _kRayon * lngRad;
  final mercY = _kRayon * math.log(math.tan(math.pi / 4 + latRad / 2));
  return Offset(
    _kLargeurVue * (mercX - _kXMin) / _kXRange,
    _kHauteurVue * (_kYMax - mercY) / _kYRange,
  );
}

class DispersesScreen extends ConsumerWidget {
  const DispersesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageDisperses(enfant: EtatPremiereSync());
    }

    final entrees = contenu.dispersesParPays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = contenu.dispersesTotal;

    return _PageDisperses(
      enfant: ListView(
        padding: const EdgeInsets.only(bottom: 34),
        children: [
          HeroEnTete(hero: contenu.hero('disperses'), hauteur: 170),
          const SizedBox(height: 18),
          // ── Mission ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CarteContenu(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: AppColors.or, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Le rassemblement des dispersés',
                        style: TextStyle(
                          color: AppColors.texte,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '« Voici, je vais prendre les enfants '
                              'd\'Israël du milieu des nations où ils sont '
                              'allés, je les rassemblerai de toutes parts, '
                              'et je les ramènerai dans leur pays. »\n\n'
                              'Ézéchiel 36:24 — les dispersés d\'',
                        ),
                        TextSpan(
                          text: 'Isolélé',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: ' (Israël)'),
                        TextSpan(
                          text: ' se signalent aux quatre coins du monde : '
                              'chaque épingle de la carte est un frère, une '
                              'sœur en marche vers le rassemblement.',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Carte du monde (épingles par pays) ──
          if (entrees.isNotEmpty)
            _CarteMondeDisperses(entrees: entrees),
          const SizedBox(height: 16),
          // ── Compteur ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppColors.pourpre, AppColors.nuitClair],
                ),
                border: Border.all(color: AppColors.or.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total <= 1
                        ? 'dispersé positionné sur la carte'
                        : 'dispersés positionnés sur la carte',
                    style: const TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${entrees.length} pays représentés',
                    style: const TextStyle(color: AppColors.orPastel, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Liste des pays ──
          if (entrees.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(
                'PAR PAYS',
                style: TextStyle(
                  color: AppColors.or,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            ...entrees.map((e) {
              final pays = _nomsPays[e.key] ?? e.key;
              final part = total > 0 ? e.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CarteContenu(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pays,
                              style: const TextStyle(
                                color: AppColors.texte,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: const TextStyle(
                              color: AppColors.or,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: part,
                          minHeight: 5,
                          backgroundColor: AppColors.nuit,
                          color: AppColors.or.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(24),
              child: EtatSectionVide(
                message: 'Aucune position sur la carte pour l\'instant — '
                    'les membres du Mouvement apparaissent ici dès qu\'ils '
                    'épinglent leur position depuis leur compte.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE DU MONDE EN POINTS (même dotted-map que le site)
// ═══════════════════════════════════════════════════════════════════

/// Carte du monde (asset dotted-map, ratio 158:80) avec une épingle
/// dorée PULSANTE par pays représenté — la taille de l'épingle croît
/// avec le nombre de dispersés du pays.
class _CarteMondeDisperses extends StatefulWidget {
  final List<MapEntry<String, int>> entrees;

  const _CarteMondeDisperses({required this.entrees});

  @override
  State<_CarteMondeDisperses> createState() => _CarteMondeDispersesState();
}

class _CarteMondeDispersesState extends State<_CarteMondeDisperses>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  /// Épingle positionnée d'un pays — null si le centre du pays est
  /// inconnu (la carte l'ignore simplement).
  Widget? _epinglePour(MapEntry<String, int> e, BoxConstraints c) {
    final centre = _centroidsPays[e.key];
    if (centre == null) return null;
    final p = _projeter(centre.$1, centre.$2);
    final taille = e.value >= 5 ? 13.0 : (e.value >= 2 ? 11.0 : 9.5);
    return Positioned(
      left: p.dx / _kLargeurVue * c.maxWidth - taille / 2,
      top: p.dy / _kHauteurVue * c.maxHeight - taille / 2,
      child: _Epingle(taille: taille, pulsation: _pulsation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CarteContenu(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: _kLargeurVue / _kHauteurVue, // 158:80 exact
            child: LayoutBuilder(
              builder: (context, contraintes) {
                return Stack(
                  children: [
                    // Fond : la carte en points (fond #1A0826 inclus).
                    Image.asset(
                      'assets/images/carte-monde-disperses.png',
                      fit: BoxFit.fill, // ratio exact → aucune déformation
                      excludeFromSemantics: true,
                    ),
                    // Équateur pointillé (comme le site web).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: contraintes.maxHeight / 2,
                      child: Container(
                        height: 0.6,
                        color: AppColors.or.withValues(alpha: 0.14),
                      ),
                    ),
                    // Épingles des pays représentés.
                    ...widget.entrees
                        .map((e) => _epinglePour(e, contraintes))
                        .whereType<Widget>(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Épingle dorée : point plein + halo pulsant (comme le site web).
class _Epingle extends StatelessWidget {
  final double taille;
  final Animation<double> pulsation;

  const _Epingle({required this.taille, required this.pulsation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulsation,
      builder: (context, _) {
        final t = pulsation.value; // 0 → 1 → 0
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Halo qui respire.
            Container(
              width: taille + 20 * (0.35 + t),
              height: taille + 20 * (0.35 + t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.or.withValues(alpha: 0.30 * (1 - t) + 0.05),
              ),
            ),
            // Point plein.
            Container(
              width: taille,
              height: taille,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.or,
                border: Border.all(color: AppColors.nuit, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.or.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Scaffold commun.
class _PageDisperses extends StatelessWidget {
  final Widget enfant;

  const _PageDisperses({required this.enfant});

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
          'Dispersés d\'Isolélé',
          style: TextStyle(color: AppColors.texte, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
