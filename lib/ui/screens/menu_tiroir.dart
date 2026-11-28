/// ⭐ V2.0 — MENU HAMBURGER (tiroir latéral).
///
/// Reproduit la structure de navigation du site public (site-header) :
/// Accueil · Serviteurs (Afrika, Pasteur Kongo) · Parole (Témoignages,
/// Enseignements, Bible) · Média (Vidéos & Lives, Adoration & Louanges,
/// Calendrier 364) · Communauté (Yeshua Connect, Intercession, Dispersés,
/// Annonces, Rendez-vous) · Contribuer.
///
/// ⭐ V2.4 :
///   · SURBRILLANCE DE LA PAGE COURANTE — « Accueil » est sélectionné par
///     défaut sur la page d'accueil ; chaque section s'allume sur SA page
///     (l'accent permanent doré de « Yeshua Connect », qui semblait être
///     une sélection par défaut, est supprimé — il ne s'allume QUE quand
///     on est réellement dans la communauté) ;
///   · AVATAR du compte connecté dans l'en-tête (photo réelle) ;
///   · plus de doublon de pile : si on est DÉJÀ dans la zone visée, le
///     tiroir se contente de se refermer.
///
/// En bas : état de connexion/synchronisation (en ligne : contenu à
/// jour · hors ligne : dernières données enregistrées), indicateur de
/// téléchargement en cours et compteur de messages en attente d'envoi
/// (outbox « façon WhatsApp »).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/contenu_controller.dart';
import '../../state/sons_controller.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/ornements.dart';
import 'splash_screen.dart' show ShofarIntro;

class MenuTiroir extends ConsumerStatefulWidget {
  const MenuTiroir({super.key});

  @override
  ConsumerState<MenuTiroir> createState() => _MenuTiroirState();
}

class _MenuTiroirState extends ConsumerState<MenuTiroir> {
  bool _enLigne = true;

  @override
  void initState() {
    super.initState();
    _enLigne = Connectivite.instance.enLigne;
    Connectivite.instance.flux.listen((v) {
      if (mounted) setState(() => _enLigne = v);
    });
  }

  void _aller(String route) {
    // Routeur + position ACTUELLE AVANT de fermer le tiroir (après pop,
    // le contexte de l'écran n'est plus garanti).
    final router = GoRouter.of(context);
    final uriActuel = '${router.routerDelegate.currentConfiguration.uri}';
    Navigator.of(context).pop(); // ferme le tiroir

    // Déjà dans la zone visée ? On ne pousse PAS de doublon de pile.
    if (route == '/app/connect') {
      if (uriActuel.startsWith('/app/connect')) return;
    } else if (uriActuel == route) {
      return;
    }
    router.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final connecte = auth.status == AuthStatus.authenticated;
    final session = auth.user;
    final contenu = ref.watch(contenuProvider);

    return Drawer(
      // ⭐ V4.47 — tiroir CLAIR (parité web) : fond crème, textes sombres.
      // ⭐ V2.17 — en-tête VIOLET ROYAL (dégradé pourpre → nuit, sceau
      // doré du logo, filet lumineux) : la porte du tiroir est un écrin.
      backgroundColor: AppColors.fond,
      surfaceTintColor: Colors.transparent,
      width: 305,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête royale : sceau doré + compte connecté + état sync ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.violetRoyal, AppColors.pourpre, AppColors.nuit],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // ⭐ V2.17 — LE SCEAU : logo officiel dans un anneau
                      //    or → flamme → violet, halo braise dessous.
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.triomphe,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x59C9A227), // or 35 %
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.4),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo-christ-libere.png',
                            width: 41,
                            height: 41,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                  text: 'Christ ',
                                  style: TextStyle(color: AppColors.orPastel)),
                              TextSpan(
                                  text: 'Libère',
                                  style: TextStyle(color: AppColors.carte)),
                            ],
                          ),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ⭐ V2.4 — compte connecté : sa PHOTO (réelle) + son nom.
                  if (connecte && session != null)
                    Row(
                      children: [
                        AvatarWidget(
                          photoUrl: session.image,
                          name: session.name,
                          size: 30,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            session.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.carte,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Le ministère dans votre poche',
                      style: TextStyle(
                          color: AppColors.texteSecondaire, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  // État de synchronisation (+ téléchargement en cours) —
                  // teintes relues pour la nuit violette de l'en-tête.
                  Row(
                    children: [
                      if (contenu.enCours) ...[
                        const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: AppColors.orPastel,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Flexible(
                          child: Text(
                            'Téléchargement en cours…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.orPastel, fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          contenu.jamaisSynchronise
                              ? Icons.cloud_off_outlined
                              : _enLigne
                                  ? Icons.cloud_done_outlined
                                  : Icons.wifi_off_outlined,
                          size: 13,
                          color: contenu.jamaisSynchronise
                              ? AppColors.texteSecondaire
                              : _enLigne
                                  ? const Color(0xFF7BD88F)
                                  : AppColors.orPastel,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            contenu.jamaisSynchronise
                                ? 'Contenu pas encore téléchargé'
                                : _enLigne
                                    ? 'En ligne — contenu à jour'
                                    : 'Hors ligne — dernières données',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: contenu.jamaisSynchronise
                                  ? AppColors.texteSecondaire
                                  : _enLigne
                                      ? const Color(0xFF7BD88F)
                                      : AppColors.orPastel,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ⭐ V2.17 — trait lumineux or → flamme → violet : la fin de
            //    l'en-tête violet, signature du sceau.
            const TraitLumineux(largeur: double.infinity, epaisseur: 2),

            // ── Navigation (surbrillance de la page courante) ──
            Expanded(
              // Listenable sur la navigation : la surbrillance se rafraîchit
              // même si le tiroir reste ouvert pendant un changement de page.
              child: ListenableBuilder(
                listenable: GoRouter.of(context).routerDelegate,
                builder: (context, _) {
                  final uri =
                      '${GoRouter.of(context).routerDelegate.currentConfiguration.uri}';
                  final dansConnect = uri.startsWith('/app/connect');
                  final estAccueil = uri == '/app' ||
                      uri == '/app/' ||
                      uri.startsWith('/app?');
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _ItemMenu(
                        icone: Icons.home_outlined,
                        libelle: 'Accueil',
                        actif: estAccueil,
                        onTap: () {
                          Navigator.of(context).pop();
                          // « Accueil » remet toute la pile à plat (comme un
                          // bouton maison) : retour propre depuis n'importe
                          // où, y compris depuis la messagerie.
                          context.go('/app');
                        },
                      ),
                      const _GroupeMenu(label: 'SERVITEURS'),
                      _ItemMenu(
                        icone: Icons.face_3_outlined,
                        libelle: 'Afrika',
                        sousLibelle: 'Servante de l\'Éternel',
                        actif: uri.startsWith('/app/serviteur/afrika'),
                        onTap: () => _aller('/app/serviteur/afrika'),
                      ),
                      // ⭐ V4.42 — espace bibliothèque d'Afrika (scission stricte)
                      _ItemMenu(
                        icone: Icons.auto_stories_outlined,
                        libelle: 'Livres d\'Afrika',
                        actif: uri.startsWith('/app/bibliotheque') &&
                            uri.contains('espace=afrika'),
                        onTap: () => _aller('/app/bibliotheque?espace=afrika'),
                      ),
                      _ItemMenu(
                        icone: Icons.church_outlined,
                        libelle: 'Pasteur Kongo',
                        sousLibelle: 'Époux, ministre pastoral',
                        actif: uri.startsWith('/app/serviteur/kongo'),
                        onTap: () => _aller('/app/serviteur/kongo'),
                      ),
                      // ⭐ V4.42 — espace bibliothèque du pasteur Kongo
                      _ItemMenu(
                        icone: Icons.auto_stories_outlined,
                        libelle: 'Livres du Pasteur Kongo',
                        actif: uri.startsWith('/app/bibliotheque') &&
                            uri.contains('espace=kongo'),
                        onTap: () => _aller('/app/bibliotheque?espace=kongo'),
                      ),
                      const _GroupeMenu(label: 'PAROLE'),
                      _ItemMenu(
                        icone: Icons.auto_awesome_outlined,
                        libelle: 'Témoignages',
                        actif: uri.startsWith('/app/temoignages') &&
                            !uri.contains('onglet=vie'),
                        onTap: () => _aller('/app/temoignages'),
                      ),
                      // ⭐ V4.47 — « Vie transformée » : espace DISTINCT des
                      // récits des serviteurs (miroir /vie-transformee du
                      // site) — onglet ?onglet=vie de l'écran Témoignages.
                      _ItemMenu(
                        icone: Icons.volunteer_activism_outlined,
                        libelle: 'Vie transformée',
                        actif: uri.startsWith('/app/temoignages') &&
                            uri.contains('onglet=vie'),
                        onTap: () => _aller('/app/temoignages?onglet=vie'),
                      ),
                      _ItemMenu(
                        icone: Icons.school_outlined,
                        libelle: 'Enseignements',
                        actif: uri.startsWith('/app/enseignements'),
                        onTap: () => _aller('/app/enseignements'),
                      ),
                      // ⭐ V4.38 — Bibliothèque documentaire (livres gratuits)
                      // ⭐ V4.42 — surlignée seulement hors espace dédié
                      // (les entrées « Livres de … » du groupe SERVITEURS
                      // prennent le relais quand ?espace= est présent).
                      _ItemMenu(
                        icone: Icons.library_books_outlined,
                        libelle: 'Bibliothèque',
                        actif: uri.startsWith('/app/bibliotheque') &&
                            !uri.contains('espace='),
                        onTap: () => _aller('/app/bibliotheque'),
                      ),
                      _ItemMenu(
                        icone: Icons.menu_book_outlined,
                        libelle: 'Bible',
                        actif: uri == '/app/bible',
                        onTap: () => _aller('/app/bible'),
                      ),
                      const _GroupeMenu(label: 'MÉDIA'),
                      _ItemMenu(
                        icone: Icons.play_circle_outline,
                        libelle: 'Vidéos & Lives',
                        badge: contenu.videos.isEmpty
                            ? null
                            : '${contenu.videos.length}',
                        actif: uri.startsWith('/app/videos'),
                        onTap: () => _aller('/app/videos'),
                      ),
                      _ItemMenu(
                        icone: Icons.music_note_outlined,
                        libelle: 'Adoration & Louanges',
                        actif: uri.startsWith('/app/adoration'),
                        onTap: () => _aller('/app/adoration'),
                      ),
                      _ItemMenu(
                        icone: Icons.calendar_month_outlined,
                        libelle: 'Calendrier 364',
                        actif: uri == '/app/calendrier',
                        onTap: () => _aller('/app/calendrier'),
                      ),
                      const _GroupeMenu(label: 'COMMUNAUTÉ'),
                      _ItemMenu(
                        icone: Icons.forum_outlined,
                        libelle: 'Yeshua Connect',
                        sousLibelle: 'Messagerie de la communauté',
                        // ⭐ V2.4 — s'allume UNIQUEMENT quand on est dans la
                        // communauté (avant : accent doré permanent qui
                        // semblait être une sélection par défaut).
                        actif: dansConnect,
                        onTap: () => _aller('/app/connect'),
                      ),
                      _ItemMenu(
                        icone: Icons.volunteer_activism_outlined,
                        libelle: 'Intercession',
                        actif: uri.startsWith('/app/intercession'),
                        onTap: () => _aller('/app/intercession'),
                      ),
                      _ItemMenu(
                        icone: Icons.public_outlined,
                        libelle: 'Dispersés d\'Isolélé',
                        sousLibelle: 'Isolélé (Israël)',
                        actif: uri.startsWith('/app/disperses'),
                        onTap: () => _aller('/app/disperses'),
                      ),
                      _ItemMenu(
                        icone: Icons.campaign_outlined,
                        libelle: 'Annonces',
                        badge: contenu.annonces.isEmpty
                            ? null
                            : '${contenu.annonces.length}',
                        actif: uri.startsWith('/app/annonces'),
                        onTap: () => _aller('/app/annonces'),
                      ),
                      _ItemMenu(
                        icone: Icons.event_available_outlined,
                        libelle: 'Rendez-vous',
                        actif: uri.startsWith('/app/rendez-vous'),
                        onTap: () => _aller('/app/rendez-vous'),
                      ),
                      // ⭐ V4.43 — retraite spirituelle : demande de séjour
                      // (identité + pièces) → espace Secrétariat.
                      _ItemMenu(
                        icone: Icons.self_improvement_outlined,
                        libelle: 'Retraite spirituelle',
                        sousLibelle: 'Lieu aménagé (Côte d\'Ivoire)',
                        actif: uri.startsWith('/app/retraite'),
                        onTap: () => _aller('/app/retraite'),
                      ),
                      const _GroupeMenu(label: 'SOUTENIR'),
                      _ItemMenu(
                        icone: Icons.favorite_outline,
                        libelle: 'Contribuer',
                        sousLibelle: 'Dons sécurisés',
                        actif: uri.startsWith('/app/contribuer'),
                        onTap: () => _aller('/app/contribuer'),
                      ),
                      // ⭐ V2.16 — ESPACE PRIVÉ : un seul bouton → les
                      // trois portes (Back-office, Secrétariat, Trésorerie)
                      // encapsulées avec leur page de connexion officielle.
                      // ⭐ V2.17 — CARTE ROYALE : dégradé violet → nuit,
                      // liseré or, médaillon d'or enflammé — la porte privée
                      // ne ressemble à aucune autre.
                      const _GroupeMenu(label: 'ESPACE PRIVÉ'),
                      _ItemEspace(
                        actif: uri.startsWith('/app/espaces'),
                        onTap: () => _aller('/app/espaces'),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Pied : sonneries + compte / connexion ──
            // ⭐ V2.17 — trait lumineux (signature du sceau) en séparation.
            const TraitLumineux(largeur: double.infinity, epaisseur: 2),
            // ⭐ V2.8 — MODE MUET GLOBAL (demande pasteur) : accès permanent
            // au réglage « le shofar et les sonneries retentissent-ils ? ».
            // Les boutons ponctuels existent aussi partout où la sonnerie
            // résonne (écran de lancement, écran d'appel).
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                secondary: Icon(
                  ref.watch(sonsMuetsProvider)
                      ? Icons.volume_off
                      : Icons.volume_up,
                  color: ref.watch(sonsMuetsProvider)
                      ? AppColors.encreEteinte
                      : AppColors.or,
                  size: 20,
                ),
                title: const Text(
                  'Sonneries de l\'application',
                  style: TextStyle(
                    color: AppColors.encre,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Shofar au lancement, sonnerie d\'appel',
                  style: TextStyle(
                    color: AppColors.encreEteinte,
                    fontSize: 11,
                  ),
                ),
                value: !ref.watch(sonsMuetsProvider),
                activeThumbColor: AppColors.or,
                onChanged: (_) async {
                  final etaitMuet = ref.read(sonsMuetsProvider);
                  await ref.read(sonsMuetsProvider.notifier).basculer();
                  // Coupe AUSSI le shofar d'intro s'il retentit en ce
                  // moment (les 30 premières secondes de l'app).
                  if (!etaitMuet) unawaited(ShofarIntro.arreter());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: connecte
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.encreSecondaire,
                        side: const BorderSide(color: AppColors.bordure),
                      ),
                      onPressed: () {
                        final router = GoRouter.of(context);
                        final uri =
                            '${router.routerDelegate.currentConfiguration.uri}';
                        Navigator.of(context).pop();
                        if (!uri.startsWith('/app/connect/profil')) {
                          router.push('/app/connect/profil');
                        }
                      },
                      // ⭐ V2.4 — photo du compte dans le bouton « Mon profil ».
                      icon: AvatarWidget(
                        photoUrl: session?.image,
                        name: session?.name ?? 'Membre',
                        size: 18,
                      ),
                      label: const Text('Mon profil'),
                    )
                  // ⭐ V2.17 — « Se connecter » : pilule d'OR ENFLAMMÉ
                  //    pleine largeur (dégradé or → flamme + halo braise).
                  : SizedBox(
                      width: double.infinity,
                      child: BoutonDore(
                        libelle: 'Se connecter',
                        icone: Icons.login,
                        pleine: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/login');
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupeMenu extends StatelessWidget {
  final String label;

  const _GroupeMenu({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.or.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 9),
          // ⭐ V2.17 — chaque groupe s'achève sur un fil lumineux
          //    or → flamme → violet, évanoui à droite.
          const Expanded(
            child: TraitLumineux(largeur: double.infinity, epaisseur: 1),
          ),
        ],
      ),
    );
  }
}

/// Élément du menu — [actif] allume la surbrillance de la page courante
/// (fond doré doux + liseré gauche or + texte or gras), comme la barre
/// latérale du site.
class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String? sousLibelle;
  final String? badge;
  final bool actif;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.sousLibelle,
    this.badge,
    this.actif = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color:
            actif ? AppColors.or.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: actif ? AppColors.or : Colors.transparent,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              minLeadingWidth: 28,
              // ⭐ V2.17 — chaque icône vit dans un MÉDAILLON : carré
              //    arrondi, teinte or posée au repos, dégradé or → flamme
              //    + halo braise quand la page est active.
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: actif
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                              AppColors.orPastel,
                              AppColors.or,
                              AppColors.flamme
                            ])
                      : null,
                  color: actif ? null : AppColors.or.withValues(alpha: 0.12),
                  boxShadow: actif
                      ? [
                          BoxShadow(
                            color: AppColors.flamme.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icone,
                  size: 16,
                  color: actif ? Colors.white : AppColors.orFonce,
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: actif ? AppColors.or : AppColors.encre,
                        fontSize: 14,
                        fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.or.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                            color: AppColors.orFonce, fontSize: 10.5),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: sousLibelle != null
                  ? Text(
                      sousLibelle!,
                      style: TextStyle(
                        color:
                            actif ? AppColors.orFonce : AppColors.encreEteinte,
                        fontSize: 11,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// ⭐ V2.17 — LA PORTE PRIVÉE « Espace » : carte royale violette (dégradé
/// violet → nuit), liseré or, médaillon d'or enflammé — elle se détache
/// du reste du menu comme un coffret posé sur la table.
class _ItemEspace extends StatelessWidget {
  final bool actif;
  final VoidCallback onTap;

  const _ItemEspace({required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.violetRoyal, AppColors.pourpre, AppColors.nuit],
          ),
          border: Border.all(color: AppColors.or.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: AppColors.violetRoyal.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const MedaillonLumineux(
                    icone: Icons.admin_panel_settings_outlined,
                    taille: 36,
                    gradient: AppColors.feuOr,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Espace',
                          style: TextStyle(
                            color: AppColors.orPastel,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Back-office · Secrétariat · Trésorerie',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.texteSecondaire,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.or,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
