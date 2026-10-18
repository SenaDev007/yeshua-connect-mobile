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
import 'menu_tiroir.dart';

class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenu = ref.watch(contenuProvider);
    final connecte = ref.watch(authProvider).status == AuthStatus.authenticated;
    final hero = contenu.hero('landing');

    return Scaffold(
      backgroundColor: AppColors.nuit,
      drawer: const MenuTiroir(),
      body: CustomScrollView(
        slivers: [
          // ── En-tête : logo + bouton menu ──
          SliverAppBar(
            backgroundColor: AppColors.nuit,
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
                  TextSpan(text: 'Christ ', style: TextStyle(color: AppColors.or)),
                  TextSpan(text: 'Libère', style: TextStyle(color: AppColors.texte)),
                ],
              ),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  tooltip: connecte ? 'Profil' : 'Se connecter',
                  icon: Icon(
                    connecte ? Icons.person : Icons.login,
                    color: AppColors.texteSecondaire,
                  ),
                  onPressed: () => context.push(
                    connecte ? '/app/connect/profil' : '/login',
                  ),
                ),
              ),
            ],
          ),

          // ── Hero landing (back-office) ──
          SliverToBoxAdapter(
            child: Stack(
              children: [
                HeroEnTete(hero: hero, hauteur: 300),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _BoutonsHero(hero: hero),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bandeau DIRECT (live en cours) ──
          if (contenu.liveEnCours != null)
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

class _BoutonsHero extends StatelessWidget {
  final HeroConfigModele hero;

  const _BoutonsHero({required this.hero});

  @override
  Widget build(BuildContext context) {
    final principal = hero.ctaLabel.isNotEmpty ? hero.ctaLabel : 'Yeshua Connect';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.or,
            foregroundColor: AppColors.nuit,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            final cible = hero.ctaHref.isNotEmpty ? hero.ctaHref : '/app/connect';
            if (cible.startsWith('http')) return; // liens externes ignorés ici
            context.push('/app/connect');
          },
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text(principal, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (hero.cta2Label.isNotEmpty) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.or,
              side: const BorderSide(color: AppColors.or),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => context.push('/app/rendez-vous'),
            child: Text(hero.cta2Label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
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
          gradient: const LinearGradient(colors: [Color(0xFF7A1025), AppColors.pourpre]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5484D).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sensors, color: Color(0xFFFF6B6B), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EN DIRECT MAINTENANT',
                    style: TextStyle(
                      color: Color(0xFFFF9B9B),
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
                      color: AppColors.texte,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFFF9B9B)),
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
        const SizedBox(height: 10),
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: SizedBox(
                                width: 76,
                                height: 76,
                                child: ImageUniverselle(
                                  url: resoudreUrl(s.photoEffective),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.nomCourt,
                              style: const TextStyle(
                                color: AppColors.texte,
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
        titre: 'Dispersés d\'Issos Lélé',
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
        accent: true,
      ),
      const _TuileSection(
        titre: 'Rendez-vous',
        sousTitre: 'Demander à rencontrer un serviteur',
        icone: Icons.event_available_outlined,
        route: '/app/rendez-vous',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.62,
      children: sections
          .map((s) => CarteContenu(
                onTap: () => context.push(s.route),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: s.accent
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3A2A10), AppColors.pourpre],
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(s.icone, color: AppColors.or, size: 22),
                      const Spacer(),
                      Text(
                        s.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texteSecondaire,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _TuileSection {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final String route;
  final bool accent;

  const _TuileSection({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.route,
    this.accent = false,
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
              onPressed: () => context.push('/app/temoignages'),
              child: const Text('Tout voir', style: TextStyle(color: AppColors.or, fontSize: 12)),
            ),
          ],
        ),
        ...vies.take(2).map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CarteContenu(
                  onTap: () => context.push('/app/temoignages'),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote, color: AppColors.or, size: 22),
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
                                color: AppColors.texte,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${v.nom}${v.ville.isNotEmpty ? ' · ${v.ville}' : ''}',
                              style: const TextStyle(
                                color: AppColors.texteSecondaire,
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
        border: Border.all(color: AppColors.or.withValues(alpha: 0.45)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pourpre, AppColors.nuit],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: AppColors.or, size: 30),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Rencontrer Afrika ou le Pasteur Kongo ?'
              '\nPassez par le secrétariat.',
              style: TextStyle(
                color: AppColors.texte,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.or,
              foregroundColor: AppColors.nuit,
            ),
            onPressed: () => context.push('/app/rendez-vous'),
            child: const Text('Demander', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
