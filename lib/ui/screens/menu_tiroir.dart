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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/contenu_controller.dart';
import '../widgets/avatar_widget.dart';

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
    final uriActuel =
        '${router.routerDelegate.currentConfiguration.uri}';
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
      backgroundColor: AppColors.pourpre,
      surfaceTintColor: Colors.transparent,
      width: 305,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête : logo + compte connecté + état sync ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Christ ', style: TextStyle(color: AppColors.or)),
                        TextSpan(text: 'Libère', style: TextStyle(color: AppColors.texte)),
                      ],
                    ),
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
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
                              color: AppColors.texte,
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
                      style: TextStyle(color: AppColors.texteEteint, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  // État de synchronisation (+ téléchargement en cours).
                  Row(
                    children: [
                      if (contenu.enCours) ...[
                        const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: AppColors.or,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Flexible(
                          child: Text(
                            'Téléchargement en cours…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.orPastel, fontSize: 11),
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
                              ? AppColors.texteEteint
                              : _enLigne
                                  ? AppColors.enLigne
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
                                  ? AppColors.texteEteint
                                  : _enLigne
                                      ? AppColors.enLigne
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
            Divider(height: 1, color: AppColors.or.withValues(alpha: 0.15)),

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
                  final estAccueil =
                      uri == '/app' || uri == '/app/' || uri.startsWith('/app?');
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
                      _ItemMenu(
                        icone: Icons.church_outlined,
                        libelle: 'Pasteur Kongo',
                        sousLibelle: 'Époux, ministre pastoral',
                        actif: uri.startsWith('/app/serviteur/kongo'),
                        onTap: () => _aller('/app/serviteur/kongo'),
                      ),
                      const _GroupeMenu(label: 'PAROLE'),
                      _ItemMenu(
                        icone: Icons.auto_awesome_outlined,
                        libelle: 'Témoignages',
                        actif: uri.startsWith('/app/temoignages'),
                        onTap: () => _aller('/app/temoignages'),
                      ),
                      _ItemMenu(
                        icone: Icons.school_outlined,
                        libelle: 'Enseignements',
                        actif: uri.startsWith('/app/enseignements'),
                        onTap: () => _aller('/app/enseignements'),
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
                        badge: contenu.videos.isEmpty ? null : '${contenu.videos.length}',
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
                        badge: contenu.annonces.isEmpty ? null : '${contenu.annonces.length}',
                        actif: uri.startsWith('/app/annonces'),
                        onTap: () => _aller('/app/annonces'),
                      ),
                      _ItemMenu(
                        icone: Icons.event_available_outlined,
                        libelle: 'Rendez-vous',
                        actif: uri.startsWith('/app/rendez-vous'),
                        onTap: () => _aller('/app/rendez-vous'),
                      ),
                      const _GroupeMenu(label: 'SOUTENIR'),
                      _ItemMenu(
                        icone: Icons.favorite_outline,
                        libelle: 'Contribuer',
                        sousLibelle: 'Dons sécurisés',
                        actif: uri.startsWith('/app/contribuer'),
                        onTap: () => _aller('/app/contribuer'),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Pied : compte / connexion ──
            Divider(height: 1, color: AppColors.or.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: connecte
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.texteSecondaire,
                        side: const BorderSide(color: AppColors.pourpreClair),
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
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.or,
                        foregroundColor: AppColors.nuit,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/login');
                      },
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text(
                        'Se connecter',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.or.withValues(alpha: 0.65),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
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
        color: actif
            ? AppColors.or.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: actif ? AppColors.or : Colors.transparent,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              minLeadingWidth: 26,
              leading: Icon(
                icone,
                size: 20,
                color: actif ? AppColors.or : AppColors.texteSecondaire,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: actif ? AppColors.or : AppColors.texte,
                        fontSize: 14,
                        fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.or.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: AppColors.orPastel, fontSize: 10.5),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: sousLibelle != null
                  ? Text(
                      sousLibelle!,
                      style: TextStyle(
                        color: actif
                            ? AppColors.orPastel
                            : AppColors.texteEteint,
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
