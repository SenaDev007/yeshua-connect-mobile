/// ⭐ V2.2 — DISPERSÉS D'ISOLÉLÉ (miroir de la page /disperses).
///
/// La carte mondiale des dispersés — même rendu que le site public :
/// carte en points (dotted-map) avec épingles dorées pulsantes par pays.
/// Les statistiques viennent de la synchronisation locale (hors ligne) ;
/// l'ajout de SA position se fait via le compte membre (page profil web).
///
/// ⭐ V2.4 — CARTE PRÉCISE (parité web) :
///   · ZOOM À PINCER + panoramique (InteractiveViewer ×1 → ×6) ;
///   · COURBES DE BÉZIER dorées reliant les dispersés entre eux
///     (même formule que le site : Q milieu, milieu − 0.3·|Δx|) ;
///   · UNE ÉPINGLE PAR MEMBRE à SA position exacte (couleur du niveau
///     spirituel, comme la carte web) — toucher = fiche du dispersé ;
///   · serviteurs localisés inclus (niveau « pasteur »).
///
/// NB : « Isolélé (Israël) » — orthographe officielle du Mouvement
/// (directive pastorale V3.45, cf. lib/isolole du site web).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/contenu_models.dart';
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

/// Centres approximatifs des pays (latitude, longitude) — pour les
/// épingles de repli par pays (données de sync antérieures à V4.14).
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

/// Initiales d'un dispersé (même règle que le web : 1ʳᵉ lettre du
/// premier mot + du dernier, particules élidées ignorées).
String _initialesDisperse(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '?';
  String initiale(String mot) {
    final elision = RegExp(r"^[\p{L}]{1,2}['’](.+)$", unicode: true).firstMatch(mot);
    final cible = elision != null ? elision.group(1)! : mot;
    final lettre = RegExp(r'\p{L}', unicode: true).firstMatch(cible);
    return (lettre?.group(0) ?? cible[0]).toUpperCase();
  }
  if (mots.length == 1) return initiale(mots.first);
  return initiale(mots.first) + initiale(mots.last);
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
    final membres = contenu.dispersesMembres;

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
          // ── Carte du monde ──
          if (membres.isNotEmpty)
            _CarteMembresDisperses(membres: membres)
          else if (entrees.isNotEmpty)
            _CarteParPays(entrees: entrees),
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
//  CARTE V2.4 — MEMBRES POSITIONNÉS (zoom + courbes + épingles exactes)
// ═══════════════════════════════════════════════════════════════════

/// Carte interactive : chaque dispersé est une épingle à SA position,
/// reliée aux suivantes par une courbe de Bézier dorée (comme le web).
/// ZOOM à deux doigts ×1 → ×6, panoramique, boutons +/−/réinitialiser.
class _CarteMembresDisperses extends StatefulWidget {
  final List<MembreDisperseModele> membres;

  const _CarteMembresDisperses({required this.membres});

  @override
  State<_CarteMembresDisperses> createState() => _CarteMembresDispersesState();
}

class _CarteMembresDispersesState extends State<_CarteMembresDisperses>
    with SingleTickerProviderStateMixin {
  final TransformationController _vue = TransformationController();
  Size _tailleCarte = Size.zero; // mémorisée au build (LayoutBuilder)

  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulsation.dispose();
    _vue.dispose();
    super.dispose();
  }

  /// Zoom (ou dézoom) ×[facteur] CENTRÉ sur le milieu de la carte : le
  /// point du contenu actuellement au centre y reste (comme une loupe).
  void _zoomer(double facteur) {
    if (_tailleCarte == Size.zero) return;
    final m = _vue.value;
    final echelle = (m.getMaxScaleOnAxis() * facteur).clamp(1.0, 6.0);
    final centre = Offset(_tailleCarte.width / 2, _tailleCarte.height / 2);
    // Point du contenu actuellement au centre de la carte.
    final pointContenu =
        MatrixUtils.transformPoint(Matrix4.inverted(m), centre);
    final nouvelle = Matrix4.identity()
      ..scaleByDouble(echelle, echelle, echelle, 1.0)
      ..setEntry(0, 3, centre.dx - pointContenu.dx * echelle)
      ..setEntry(1, 3, centre.dy - pointContenu.dy * echelle);
    _vue.value = nouvelle;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CarteContenu(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: _kLargeurVue / _kHauteurVue, // 158:80 exact
                child: LayoutBuilder(
                  builder: (context, contraintes) {
                    _tailleCarte = Size(
                      contraintes.maxWidth,
                      contraintes.maxHeight,
                    );
                    return Stack(
                      children: [
                        // ── Fond : la carte en points + courbes + épingles,
                        //    le TOUT zoomable d'un seul geste. ──
                        InteractiveViewer(
                          transformationController: _vue,
                          maxScale: 6,
                          minScale: 1,
                          panEnabled: true,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: contraintes.maxWidth,
                            height: contraintes.maxHeight,
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/images/carte-monde-disperses.png',
                                  fit: BoxFit.fill, // ratio exact
                                  excludeFromSemantics: true,
                                ),
                                // Courbes reliant les dispersés (web).
                                CustomPaint(
                                  size: Size(
                                    contraintes.maxWidth,
                                    contraintes.maxHeight,
                                  ),
                                  painter: _PeintreCourbes(
                                    points: widget.membres
                                        .map((m) =>
                                            _projeter(m.latitude, m.longitude))
                                        .toList(),
                                  ),
                                ),
                                // Équateur pointillé (comme le site web).
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: contraintes.maxHeight / 2,
                                  child: Container(
                                    height: 0.6,
                                    color:
                                        AppColors.or.withValues(alpha: 0.14),
                                  ),
                                ),
                                // Une épingle par membre, à SA position.
                                ...widget.membres.map((m) {
                                  final p =
                                      _projeter(m.latitude, m.longitude);
                                  return Positioned(
                                    left: p.dx / _kLargeurVue *
                                            contraintes.maxWidth -
                                        16,
                                    top: p.dy / _kHauteurVue *
                                            contraintes.maxHeight -
                                        16,
                                    child: _EpingleMembre(
                                      membre: m,
                                      pulsation: _pulsation,
                                      onTap: () => _ouvrirFiche(m),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Légende + commandes de zoom (web V3.15) ──
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (final e in libellesNiveauDisperse.entries)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(couleursNiveauDisperse[e.key] ??
                                    0xFF8A8378),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e.value,
                              style: const TextStyle(
                                color: AppColors.texteEteint,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _BoutonZoom(
                  icone: Icons.remove,
                  onTap: () => _zoomer(1 / 1.5),
                ),
                const SizedBox(width: 6),
                _BoutonZoom(
                  icone: Icons.add,
                  onTap: () => _zoomer(1.5),
                ),
                const SizedBox(width: 6),
                _BoutonZoom(
                  icone: Icons.center_focus_strong,
                  onTap: () => _vue.value = Matrix4.identity(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pincez pour zoomer · touchez une épingle pour découvrir le dispersé',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.texteEteint, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirFiche(MembreDisperseModele m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FicheDisperse(membre: m),
    );
  }
}

/// Bouton de zoom doré (contour pourpre, fond nuit).
class _BoutonZoom extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;

  const _BoutonZoom({required this.icone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nuit,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: const BorderSide(color: AppColors.pourpreClair),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 26,
          child: Icon(icone, size: 16, color: AppColors.or),
        ),
      ),
    );
  }
}

/// Peintre des courbes de Bézier dorées reliant les dispersés
/// consécutifs — EXACTEMENT la formule du site web
/// (carte-disperses.tsx : contrôle au milieu, décalé de 0.3·|Δx|).
class _PeintreCourbes extends CustomPainter {
  final List<Offset> points;

  _PeintreCourbes({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final c = Offset(size.width / _kLargeurVue, size.height / _kHauteurVue);
    final peinture = Paint()
      ..color = const Color(0x66C9A227) // or 40 % (comme le web)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final a = Offset(points[i].dx * c.dx, points[i].dy * c.dy);
      final b = Offset(points[i + 1].dx * c.dx, points[i + 1].dy * c.dy);
      final milieu = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final controle =
          Offset(milieu.dx, milieu.dy - (b.dx - a.dx).abs() * 0.3);
      final chemin = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(controle.dx, controle.dy, b.dx, b.dy);
      // Tirets 4:3 comme le web (strokeDasharray "4 3").
      for (final mesure in chemin.computeMetrics()) {
        var debut = 0.0;
        while (debut < mesure.length) {
          final fin = math.min(debut + 4.0, mesure.length);
          canvas.drawPath(mesure.extractPath(debut, fin), peinture);
          debut = fin + 3.0;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreCourbes old) =>
      old.points.length != points.length;
}

/// Épingle d'un dispersé : halo pulsant + point de la couleur de son
/// niveau spirituel (comme le web) + zone tactile généreuse (32 px).
class _EpingleMembre extends StatelessWidget {
  final MembreDisperseModele membre;
  final Animation<double> pulsation;
  final VoidCallback onTap;

  const _EpingleMembre({
    required this.membre,
    required this.pulsation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = Color(
        couleursNiveauDisperse[membre.niveau] ?? 0xFF8A8378);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: AnimatedBuilder(
          animation: pulsation,
          builder: (context, _) {
            final t = pulsation.value; // 0 → 1 → 0
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 12 + 22 * (0.4 + t),
                  height: 12 + 22 * (0.4 + t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: couleur.withValues(alpha: 0.30 * (1 - t) + 0.05),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: couleur,
                    border: Border.all(
                      color: AppColors.nuit,
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: couleur.withValues(alpha: 0.6),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fiche d'un dispersé (feuille du bas) — parité du modal web :
/// initiales (anneau de la couleur du niveau), pseudonyme, ville/pays,
/// badge du niveau spirituel, message, langue et position.
class _FicheDisperse extends StatelessWidget {
  final MembreDisperseModele membre;

  const _FicheDisperse({required this.membre});

  @override
  Widget build(BuildContext context) {
    final couleur =
        Color(couleursNiveauDisperse[membre.niveau] ?? 0xFF8A8378);
    final niveau = libellesNiveauDisperse[membre.niveau] ?? membre.niveau;
    final lieu = [
      if (membre.ville.isNotEmpty) membre.ville,
      _nomsPays[membre.pays] ?? membre.pays,
    ].join(', ');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: AppColors.or, width: 1.2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: couleur, width: 2.4),
                        ),
                        color: AppColors.nuit,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initialesDisperse(membre.pseudonyme),
                        style: TextStyle(
                          color: couleur,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            membre.pseudonyme,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.texte,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (lieu.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              lieu,
                              style: const TextStyle(
                                color: AppColors.texteSecondaire,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close, color: AppColors.or, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Badge niveau spirituel (couleur du niveau, comme le web).
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: couleur.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: couleur),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        niveau,
                        style: TextStyle(
                          color: couleur,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (membre.message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.nuit.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.or.withValues(alpha: 0.25)),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: spansIsolole(
                          '« ${membre.message} »',
                          style: const TextStyle(
                            color: AppColors.texteSecondaire,
                            fontSize: 13,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                          ),
                          styleGras: const TextStyle(
                            color: AppColors.orPastel,
                            fontSize: 13,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Position : ${membre.latitude.toStringAsFixed(1)}°, '
                  '${membre.longitude.toStringAsFixed(1)}° (arrondie à 0.1° pour anonymat)'
                  '${membre.langue.isNotEmpty ? ' · Langue : ${membre.langue}' : ''}',
                  style: const TextStyle(
                    color: AppColors.texteEteint,
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE DE REPLI (données de sync antérieures V4.13 — épingles/pays)
// ═══════════════════════════════════════════════════════════════════

/// Carte du monde (asset dotted-map, ratio 158:80) avec une épingle
/// dorée PULSANTE par pays représenté — la taille de l'épingle croît
/// avec le nombre de dispersés du pays.
class _CarteParPays extends StatefulWidget {
  final List<MapEntry<String, int>> entrees;

  const _CarteParPays({required this.entrees});

  @override
  State<_CarteParPays> createState() => _CarteParPaysState();
}

class _CarteParPaysState extends State<_CarteParPays>
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
