/// ⭐ V2.0 — ÉCRAN D'ACCUEIL DU MINISTÈRE (landing).
///
/// Reproduit la page d'accueil du site public : grande bannière hero
/// pilotée par le back-office (/admin/heroes → « landing »), bandeau
/// DIRECT si un live est en cours, les deux serviteurs côte à côte,
/// grille des sections du ministère, et menu hamburger (tiroir) qui
/// déroule TOUTE la structure du site — Serviteurs / Parole / Média /
/// Communauté — exactement comme la barre du web.
///
/// HORS-LIGNE : l'écran est rendu depuis la base SQLite locale — aucune
/// connexion requise une fois le contenu téléchargé.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/contenu_models.dart';
import '../../state/auth_controller.dart';
import '../../state/contenu_controller.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/contenu_widgets.dart';
import '../widgets/ornements.dart';
import 'menu_tiroir.dart';

class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenu = ref.watch(contenuProvider);
    final auth = ref.watch(authProvider);
    final connecte = auth.status == AuthStatus.authenticated;
    final session = auth.user;
    final hero = contenu.hero('landing');

    return Scaffold(
      backgroundColor: AppColors.fond,
      drawer: const MenuTiroir(),
      body: CustomScrollView(
        slivers: [
          // ── En-tête : logo + bouton menu ──
          SliverAppBar(
            backgroundColor: AppColors.fond,
            surfaceTintColor: Colors.transparent,
            floating: true,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.or),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: 'Christ ', style: TextStyle(color: AppColors.or)),
                  TextSpan(
                      text: 'Libère', style: TextStyle(color: AppColors.encre)),
                ],
              ),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            centerTitle: false,
            actions: [
              // ⭐ V2.4 — PHOTO DU COMPTE CONNECTÉ (plus jamais une icône
              // générique) : l'avatar réel de la session, sinon l'icône.
              // ⭐ V2.8 — pendant le PREMIER TÉLÉCHARGEMENT, le bouton de
              // connexion n'apparaît pas non plus : « que le logo et le
              // texte informatif seuls » à l'écran (il revient dès que le
              // contenu est téléchargé).
              if (!(connecte || contenu.jamaisSynchronise))
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    tooltip: 'Se connecter',
                    icon: const Icon(
                      Icons.login,
                      color: AppColors.encreSecondaire,
                    ),
                    onPressed: () => context.push('/login'),
                  ),
                )
              else if (connecte)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => context.push('/app/connect/profil'),
                    child: AvatarWidget(
                      photoUrl: session?.image,
                      name: session?.name ?? 'Membre',
                      size: 34,
                    ),
                  ),
                ),
            ],
          ),

          // ── ⭐ V2.4 — Barre dorée « mise à jour en cours » (fine, sous
          // l'en-tête) : la synchronisation ne fige PLUS jamais l'écran. ──
          if (contenu.enCours && !contenu.jamaisSynchronise)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                color: AppColors.or,
              ),
            ),

          // ── Hero landing (back-office) ──
          // ⭐ V2.2 — correctif pasteur : les boutons ne chevauchent PLUS
          // le texte (marge réservée sous le bloc texte + dégradé porteur)
          // et le 2ᵉ bouton n'est plus transparent (fond nuit semi-opaque).
          // ⭐ V2.8 — PREMIER TÉLÉCHARGEMENT (demande pasteur) : pendant le
          // téléchargement initial du contenu, AUCUN bouton de choix — le
          // logo et le texte informatif seuls occupent le milieu de l'écran
          // (EtatPremiereSync). Le hero et ses boutons CTA (« Yeshua
          // Connect »…) n'apparaissent qu'une fois le contenu téléchargé.
          if (!contenu.jamaisSynchronise)
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  HeroEnTete(hero: hero, hauteur: 300, margeBas: 108),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BandeauBoutonsHero(hero: hero),
                  ),
                ],
              ),
            ),

          // ── Bandeau DIRECT (live en cours) ──
          // (⭐ V2.8 — rien avant le premier téléchargement : pas de live
          // connu tant que la première synchronisation n'est pas faite.)
          if (contenu.liveEnCours != null && !contenu.jamaisSynchronise)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _BandeauLive(live: contenu.liveEnCours!),
              ),
            ),

          // ── Contenu principal ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: contenu.jamaisSynchronise
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EtatPremiereSync(),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionServiteurs(serviteurs: contenu.serviteurs),
                      const SizedBox(height: 22),
                      _GrilleSections(videosTotal: contenu.videos.length),
                      const SizedBox(height: 22),
                      _ApercuViesTransformees(vies: contenu.viesTransformees),
                      const SizedBox(height: 14),
                      _ApercuRendezVous(),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BOUTONS DU HERO
// ═══════════════════════════════════════════════════════════════════

/// Traduit une route du SITE WEB vers la route équivalente de l'app.
/// Renvoie null si la cible n'existe pas dans l'app (lien externe,
/// page inconnue) — l'appelant fournit alors sa destination par défaut.
String? _routeApp(String? hrefWeb) {
  final h = hrefWeb?.trim() ?? '';
  if (h.isEmpty || h.startsWith('http')) return null;
  final cle = h.split('#').first;
  const correspondances = {
    '/': '/app',
    '/afrika': '/app/serviteur/afrika',
    '/pasteur-kongo': '/app/serviteur/kongo',
    '/temoignages': '/app/temoignages',
    '/enseignements': '/app/enseignements',
    '/bibliotheque': '/app/bibliotheque',
    '/videos': '/app/videos',
    '/adoration': '/app/adoration',
    '/intercession': '/app/intercession',
    '/disperses': '/app/disperses',
    '/contribuer': '/app/contribuer',
    '/rendez-vous': '/app/rendez-vous',
    // ⭐ V4.43 — retraite spirituelle (formulaire natif de l'app).
    '/retraite-spirituelle': '/app/retraite',
    // ⭐ V2.10 — /register a désormais son écran NATIF dans l'app
    // (avant : repli vers /login faute de formulaire d'inscription).
    '/register': '/register',
    '/login': '/login',
  };
  return correspondances[cle] ??
      correspondances[cle.replaceAll(RegExp(r'/+$'), '')];
}

class _BandeauBoutonsHero extends StatelessWidget {
  final HeroConfigModele hero;

  const _BandeauBoutonsHero({required this.hero});

  @override
  Widget build(BuildContext context) {
    final principal =
        hero.ctaLabel.isNotEmpty ? hero.ctaLabel : 'Yeshua Connect';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.nuit.withValues(alpha: 0.0),
            AppColors.nuit.withValues(alpha: 0.82),
            AppColors.nuit.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          // ── Bouton principal — ⭐ V2.17 pilule d'OR ENFLAMMÉ (dégradé
          //    or → flamme + halo braise) : l'action qui brille. ──
          BoutonDore(
            libelle: principal,
            onPressed: () {
              final cible = _routeApp(hero.ctaHref) ?? '/app/connect';
              context.push(cible);
            },
          ),
          // ── Bouton secondaire — ⭐ V2.17 VIOLET ROYAL (dégradé violet
          //    → nuit, liseré or) sur fond nuit semi-opaque. ──
          if (hero.cta2Label.isNotEmpty)
            BoutonPourpre(
              libelle: hero.cta2Label,
              onPressed: () {
                final cible = _routeApp(hero.cta2Href) ?? '/app/rendez-vous';
                context.push(cible);
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BANDEAU LIVE EN COURS
// ═══════════════════════════════════════════════════════════════════

class _BandeauLive extends StatelessWidget {
  final LiveEnCoursModele live;

  const _BandeauLive({required this.live});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/app/connect/live'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7A1025), AppColors.pourpre]),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFE5484D).withValues(alpha: 0.5)),
          // ⭐ V2.17 — halo braise : le bandeau LIVE éclaire la page.
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE5484D).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ⭐ V2.17 — POINT DE FLAMME pulsant (éclat orangé + halo),
            //    à la place de l'icône plate : « le direct est en feu ».
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.flammeVive,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.flammeVive.withValues(alpha: 0.85),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EN DIRECT MAINTENANT',
                    style: TextStyle(
                      color: Color(0xFFFFD9B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.orPastel,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFFFD9B8)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SECTION SERVITEURS (« Un même appel, deux serviteurs »)
// ═══════════════════════════════════════════════════════════════════

class _SectionServiteurs extends StatelessWidget {
  final List<ServiteurModele> serviteurs;

  const _SectionServiteurs({required this.serviteurs});

  @override
  Widget build(BuildContext context) {
    if (serviteurs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UN MÊME APPEL, DEUX SERVITEURS',
          style: TextStyle(
            color: AppColors.or,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        // ⭐ V2.17 — trait lumineux or → flamme → violet sous le titre.
        const TraitLumineux(largeur: 130, epaisseur: 2),
        const SizedBox(height: 12),
        Row(
          children: serviteurs
              .map((s) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: s == serviteurs.last ? 0 : 10,
                      ),
                      child: CarteContenu(
                        onTap: () => context.push('/app/serviteur/${s.code}'),
                        child: Column(
                          children: [
                            // ⭐ V2.17 — ANNEAU LUMINEUX (or → flamme →
                            //    violet) : le visage du serviteur porte
                            //    le sceau du ministère.
                            Center(
                              child: AnneauLumineux(
                                taille: 84,
                                epaisseur: 2.6,
                                child: ImageUniverselle(
                                  url: resoudreUrl(s.photoEffective),
                                  fit: BoxFit.cover,
                                  width: 84,
                                  height: 84,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.nomCourt,
                              style: const TextStyle(
                                color: AppColors.encre,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.role,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.orPastel,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  GRILLE DES SECTIONS DU MINISTÈRE
// ═══════════════════════════════════════════════════════════════════

class _GrilleSections extends StatelessWidget {
  final int videosTotal;

  const _GrilleSections({required this.videosTotal});

  @override
  Widget build(BuildContext context) {
    final sections = <_TuileSection>[
      const _TuileSection(
        titre: 'Témoignages',
        sousTitre: 'Visites du ciel, chofar, délivrances',
        icone: Icons.auto_awesome,
        route: '/app/temoignages',
      ),
      const _TuileSection(
        titre: 'Enseignements',
        sousTitre: 'Doctrine, fêtes, marche chrétienne',
        icone: Icons.school_outlined,
        route: '/app/enseignements',
      ),
      const _TuileSection(
        titre: 'Vidéos & Lives',
        sousTitre: 'Médiathèque complète',
        icone: Icons.play_circle_outline,
        route: '/app/videos',
      ),
      const _TuileSection(
        titre: 'Adoration & Louanges',
        sousTitre: 'Chants d\'Afrika, chantre de l\'Éternel',
        icone: Icons.music_note_outlined,
        route: '/app/adoration',
      ),
      const _TuileSection(
        titre: 'Bible',
        sousTitre: '6 versions, Strong, hébreu',
        icone: Icons.menu_book_outlined,
        route: '/app/bible',
      ),
      const _TuileSection(
        titre: 'Calendrier 364',
        sousTitre: 'Fêtes de l\'Éternel, shofar',
        icone: Icons.calendar_month_outlined,
        route: '/app/calendrier',
      ),
      const _TuileSection(
        titre: 'Intercession',
        sousTitre: 'Déposer une demande de prière',
        icone: Icons.volunteer_activism,
        route: '/app/intercession',
      ),
      const _TuileSection(
        titre: 'Dispersés d\'Isolélé',
        sousTitre: 'La carte mondiale des dispersés',
        icone: Icons.public,
        route: '/app/disperses',
      ),
      const _TuileSection(
        titre: 'Annonces',
        sousTitre: 'La voix officielle du ministère',
        icone: Icons.campaign_outlined,
        route: '/app/annonces',
      ),
      const _TuileSection(
        titre: 'Contribuer',
        sousTitre: 'Soutenir la mission',
        icone: Icons.favorite_outline,
        route: '/app/contribuer',
      ),
      const _TuileSection(
        titre: 'Yeshua Connect',
        sousTitre: 'La communauté, les canaux, les appels',
        icone: Icons.forum_outlined,
        route: '/app/connect',
      ),
      const _TuileSection(
        titre: 'Rendez-vous',
        sousTitre: 'Demander à rencontrer un serviteur',
        icone: Icons.event_available_outlined,
        route: '/app/rendez-vous',
      ),
      // ⭐ V4.43 — retraite spirituelle : lieu aménagé en Côte d'Ivoire.
      const _TuileSection(
        titre: 'Retraite spirituelle',
        sousTitre: 'Demander un séjour au lieu de retraite',
        icone: Icons.self_improvement_outlined,
        route: '/app/retraite',
      ),
    ];

    // ⭐ V2.17 — GRILLE EN LUMIÈRE : chaque tuile porte SA couleur du
    // sceau (or → flamme → violet, en rotation) — médaillon dégradé +
    // halo, liseré lumineux assorti, chevron doré. Le fond blanc/crème
    // du site reste intact : la lumière vient des filets et médaillons.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.52,
      children: sections
          .asMap()
          .entries
          .map((entree) => _TuileLumineuse(
                section: entree.value,
                theme: _themesTuile[entree.key % _themesTuile.length],
              ))
          .toList(),
    );
  }
}

/// ⭐ V2.17 — les trois lumières du sceau, en rotation sur la grille :
/// or (médaillon d'or), flamme (médaillon braise), violet (médaillon
/// royal). Liseré et halo suivent la couleur de la tuile.
class _ThemeTuile {
  final List<Color> liseres;
  final List<Color> medaillon;

  const _ThemeTuile(this.liseres, this.medaillon);
}

const List<_ThemeTuile> _themesTuile = [
  _ThemeTuile(
    [Color(0xD9C9A227), Color(0xB39A7A1E)], // or
    [AppColors.orPastel, AppColors.or],
  ),
  _ThemeTuile(
    [Color(0xD9C2410C), Color(0xB39A2E0C)], // flamme
    [AppColors.flammeVive, AppColors.flamme],
  ),
  _ThemeTuile(
    [Color(0xD94C1D95), Color(0xB32A0E3D)], // violet
    [AppColors.violetHalo, AppColors.violetRoyal],
  ),
];

/// Tuile de section « en lumière » — carte blanche, liseré dégradé de SA
/// couleur, médaillon dégradé + halo, chevron doré en coin.
class _TuileLumineuse extends StatelessWidget {
  final _TuileSection section;
  final _ThemeTuile theme;

  const _TuileLumineuse({required this.section, required this.theme});

  @override
  Widget build(BuildContext context) {
    return CarteLumineuse(
      onTap: () => context.push(section.route),
      liseres: theme.liseres,
      epaisseurLiseret: 1.3,
      rayon: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MedaillonLumineux(
                icone: section.icone,
                taille: 34,
                rayon: 11,
                gradient: theme.medaillon,
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 11,
                color: AppColors.or.withValues(alpha: 0.75),
              ),
            ],
          ),
          const Spacer(),
          Text(
            section.titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.encre,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            section.sousTitre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.encreSecondaire,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TuileSection {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final String route;

  const _TuileSection({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.route,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  APERÇUS BAS DE PAGE
// ═══════════════════════════════════════════════════════════════════

class _ApercuViesTransformees extends StatelessWidget {
  final List<VieTransformeeModele> vies;

  const _ApercuViesTransformees({required this.vies});

  @override
  Widget build(BuildContext context) {
    if (vies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'VIES TRANSFORMÉES',
                style: TextStyle(
                  color: AppColors.or,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/app/temoignages?onglet=vie'),
              child: const Text('Tout voir',
                  style: TextStyle(color: AppColors.or, fontSize: 12)),
            ),
          ],
        ),
        // ⭐ V2.17 — trait lumineux or → flamme → violet sous le titre.
        const Align(
          alignment: Alignment.centerLeft,
          child: TraitLumineux(largeur: 130, epaisseur: 2),
        ),
        const SizedBox(height: 8),
        ...vies.take(2).map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CarteContenu(
                  onTap: () => context.push('/app/temoignages?onglet=vie'),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote,
                          color: AppColors.or, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.titre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.encre,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${v.nom}${v.ville.isNotEmpty ? ' · ${v.ville}' : ''}',
                              style: const TextStyle(
                                color: AppColors.encreSecondaire,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _ApercuRendezVous extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.or.withValues(alpha: 0.55)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pourpre, AppColors.nuit],
        ),
        // ⭐ V2.17 — halo violet royal : la carte-sceau de l'accueil.
        boxShadow: [
          BoxShadow(
            color: AppColors.violetRoyal.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // ⭐ V2.17 — médaillon d'or enflammé à la place de l'icône plate.
          const MedaillonLumineux(
            icone: Icons.event_available_outlined,
            taille: 40,
            gradient: AppColors.feuOr,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Rencontrer Afrika ou le Pasteur Kongo ?'
              '\nPassez par le secrétariat.',
              style: TextStyle(
                color: AppColors.carte,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ⭐ V2.17 — pilule d'or enflammé (dégradé or → flamme + halo).
          BoutonDore(
            libelle: 'Demander',
            onPressed: () => context.push('/app/rendez-vous'),
          ),
        ],
      ),
    );
  }
}
