/// ⭐ V2.0 — WIDGETS COMMUNS DES PAGES DE CONTENU DU MINISTÈRE.
///
/// Toutes les pages publiques (Serviteurs, Témoignages, Enseignements,
/// Vidéos, Adoration, Intercession, Dispersés, Contribuer, Annonces,
/// Rendez-vous) partagent la même charte : fond nuit, AppBar dorée,
/// hero paramétrable depuis le back-office, et l'EXIGENCE hors-ligne —
/// le contenu vient de la base SQLite locale (aucun réseau requis), le
/// premier lancement invite simplement à se connecter une fois.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';

/// Résout une URL du backend : relative (`/rendered-videos/x.mp4`,
/// `/uploads/y.jpg`) → absolue sur l'API ; data-URL → inchangée.
String resoudreUrl(String? url) {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return '';
  if (u.startsWith('http://') ||
      u.startsWith('https://') ||
      u.startsWith('data:')) {
    return u;
  }
  if (u.startsWith('/')) return '${AppConfig.apiBaseUrl}$u';
  return u;
}

/// État « premier lancement sans réseau » : le contenu public n'a jamais
/// pu être téléchargé.
/// ⭐ V2.4 — PENDANT le téléchargement (contenu.enCours) : indicateur de
/// chargement animé (logo pulsant + barre dorée) — plus JAMAIS d'écran
/// statique sans explication ; bouton Réessayer uniquement hors sync.
class EtatPremiereSync extends ConsumerWidget {
  final String message;

  const EtatPremiereSync(
      {super.key, this.message = 'Contenu pas encore téléchargé'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enCours = ref.watch(contenuProvider).enCours;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo pulsant pendant le téléchargement ──
            if (enCours) ...[
              const _LogoPulsant(),
              const SizedBox(height: 18),
              const Text(
                'Téléchargement du contenu…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texte,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Témoignages, enseignements, vidéos et annonces du ministère '
                'arrivent — restez sur cet écran un instant.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texteSecondaire,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 210,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.pourpreClair,
                    color: AppColors.or,
                  ),
                ),
              ),
            ] else ...[
              const Icon(Icons.cloud_off, size: 54, color: AppColors.orPastel),
              const SizedBox(height: 16),
              const Text(
                'Premier lancement',
                style: TextStyle(
                  color: AppColors.texte,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$message. Connectez-vous à Internet une première fois : '
                'tout le ministère (témoignages, enseignements, vidéos, '
                'annonces…) sera ensuite disponible hors ligne.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texteSecondaire,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit,
                ),
                onPressed: () =>
                    ref.read(contenuProvider.notifier).synchroniser(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Logo officiel pulsant (même respiration que le splash).
class _LogoPulsant extends StatefulWidget {
  const _LogoPulsant();

  @override
  State<_LogoPulsant> createState() => _LogoPulsantState();
}

class _LogoPulsantState extends State<_LogoPulsant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1.05)
          .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: Image.asset(
        'assets/images/logo-christ-libere.png',
        width: 84,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// État « section vide » (contenu synchronisé mais rien dans la section).
class EtatSectionVide extends StatelessWidget {
  final String message;

  const EtatSectionVide({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 44, color: AppColors.texteEteint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ISOLÉLÉ (ISRAËL) — directive pastorale V3.45
// ═══════════════════════════════════════════════════════════

/// Le mot isolé « Israël » (et « Israel » sans diacritiques) — PAS les
/// mots dérivés (« Israélite », « Israélien »…), exactement comme le
/// composant web <IsololeText>.
final RegExp _motIsrael = RegExp(r'\bIsra[ëe]l\b');

/// Découpe un texte : « Israël » s'affiche « Isolélé (Israël) » avec
/// « Isolélé » en gras — directive du pasteur, identique au site web.
List<InlineSpan> spansIsolole(
  String texte, {
  TextStyle? style,
  TextStyle? styleGras,
}) {
  final correspondances = _motIsrael.allMatches(texte).toList();
  if (correspondances.isEmpty) {
    return [TextSpan(text: texte, style: style)];
  }
  final gras = (styleGras ?? style)?.copyWith(fontWeight: FontWeight.w800);
  final note = style; // « (Israël) » garde le style courant
  final spans = <InlineSpan>[];
  var curseur = 0;
  for (final m in correspondances) {
    if (m.start > curseur) {
      spans
          .add(TextSpan(text: texte.substring(curseur, m.start), style: style));
    }
    spans.add(TextSpan(text: 'Isolélé', style: gras));
    spans.add(TextSpan(text: ' (${m.group(0)})', style: note));
    curseur = m.end;
  }
  if (curseur < texte.length) {
    spans.add(TextSpan(text: texte.substring(curseur), style: style));
  }
  return spans;
}

/// Hero de page : bannière paramétrée depuis le back-office (/admin/heroes)
/// — kicker doré, titre (accent en or), sous-titre, image de fond voilée.
///
/// [margeBas] ajoute de l'espace SOUS le texte (utile quand des boutons
/// sont superposés en bas de la bannière — cf. accueil V2.2 : plus aucun
/// chevauchement texte/boutons).
///
/// ⭐ V2.4 — ANTI-DÉBORDEMENT (« bottom overflowed by N pixels »).
/// ⭐ V2.5 — PLUS JAMAIS DE TEXTE COUPÉ EN HAUT (retour pasteur : « Un
/// même appel, deux serviteurs » invisible). La hauteur [hauteur] devient
/// un MINIMUM : le bloc texte est ancré en BAS de la bannière (juste
/// au-dessus de la marge réservée aux boutons) et la bannière GRANDIT si
/// le texte est plus haut que l'espace disponible (grandes polices
/// système, accents d'accessibilité, écrans courts). L'ancienne version
/// (vue défilante inversée) masquait le HAUT du texte sans aucune
/// possibilité de le faire défiler — le kicker « UN MÊME APPEL, DEUX
/// SERVITEURS » disparaissait entièrement.
class HeroEnTete extends StatelessWidget {
  final HeroConfigModele hero;
  final double hauteur;
  final double margeBas;

  const HeroEnTete(
      {super.key, required this.hero, this.hauteur = 190, this.margeBas = 0});

  @override
  Widget build(BuildContext context) {
    final fond = resoudreUrl(hero.imageDeFond);
    return Container(
      // ⭐ V2.5 — hauteur MINIMALE : la bannière s'agrandit pour TOUJOURS
      // contenir son texte (plus de coupure haute), les boutons superposés
      // de l'accueil restent collés en bas du Stack.
      constraints: BoxConstraints(minHeight: hauteur),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        image: fond.isNotEmpty && !fond.startsWith('data:')
            ? DecorationImage(
                image: CachedNetworkImageProvider(fond),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  AppColors.nuit.withValues(alpha: 0.72),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + margeBas),
          // ⭐ V2.5 — ancrage BAS : quand la bannière est plus haute que le
          // texte (cas courant), le texte reste au-dessus des boutons ;
          // Align grandit avec l'enfant quand le texte déborde (le
          // conteneur suit, la bannière s'agrandit).
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hero.kicker.isNotEmpty) ...[
                  Text.rich(
                    TextSpan(
                      children: spansIsolole(
                        hero.kicker.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.or,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                        styleGras: const TextStyle(
                          color: AppColors.or,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Titre : accent doré + reste blanc (même construction web).
                Text.rich(
                  TextSpan(
                    children: [
                      ...spansIsolole(
                        '${hero.titre} ',
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      ...spansIsolole(
                        hero.accentTitre,
                        style: const TextStyle(
                          color: AppColors.or,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      ...spansIsolole(
                        ' ${hero.suffixeTitre}',
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hero.sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: spansIsolole(
                        hero.sousTitre,
                        style: const TextStyle(
                          color: AppColors.texteSecondaire,
                          fontSize: 13,
                          height: 1.45,
                        ),
                        styleGras: const TextStyle(
                          color: AppColors.orPastel,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Puce de filtre (catégories vidéos, thèmes témoignages…) — dorée quand
/// active, outline pourpre sinon.
class PuceFiltre extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const PuceFiltre({
    super.key,
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? AppColors.or : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: actif ? AppColors.or : AppColors.pourpreClair),
        ),
        child: Text(
          libelle,
          style: TextStyle(
            color: actif ? AppColors.nuit : AppColors.texteSecondaire,
            fontSize: 12.5,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Carte standard d'une page de contenu (fond pourpre, coin doux).
class CarteContenu extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const CarteContenu(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.pourpreClair.withValues(alpha: 0.6)),
        ),
        child: child,
      ),
    );
  }
}
