/// ⭐ V2.0 — DISPERSÉS D'ISSOS LÉLÉ (miroir de la page /disperses).
///
/// La carte mondiale des dispersés d'Israël : statistiques par pays
/// (issues de la synchronisation locale — hors ligne), liste des pays
/// représentés, et description de la mission de rassemblement.
///
/// L'ajout de SA position sur la carte se fait via le compte membre
/// (page profil web) — l'app affiche la carte et son message.
library;

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
};

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
                  Text(
                    '« Voici, je vais prendre les enfants d\'Israël du milieu '
                    'des nations où ils sont allés, je les rassemblerai de '
                    'toutes parts, et je les ramènerai dans leur pays. »\n\n'
                    'Ézéchiel 36:24 — les dispersés d\'Issos Lélé (Israël) '
                    'se signalent aux quatre coins du monde : chaque épingle '
                    'de la carte est un frère, une sœur en marche vers le '
                    'rassemblement.',
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
          'Dispersés d\'Issos Lélé',
          style: TextStyle(color: AppColors.texte, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
