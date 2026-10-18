/// ⭐ V2.0 — MENU HAMBURGER (tiroir latéral).
///
/// Reproduit la structure de navigation du site public (site-header) :
/// Accueil · Serviteurs (Afrika, Pasteur Kongo) · Parole (Témoignages,
/// Enseignements, Bible) · Média (Vidéos & Lives, Adoration & Louanges,
/// Calendrier 364) · Communauté (Yeshua Connect, Intercession, Dispersés,
/// Annonces, Rendez-vous) · Contribuer.
///
/// En bas : état de connexion/synchronisation (en ligne : contenu à
/// jour · hors ligne : dernières données enregistrées) et compteur de
/// messages en attente d'envoi (outbox « façon WhatsApp »).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/contenu_controller.dart';

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
    Navigator.of(context).pop(); // ferme le tiroir
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final connecte = ref.watch(authProvider).status == AuthStatus.authenticated;
    final contenu = ref.watch(contenuProvider);

    return Drawer(
      backgroundColor: AppColors.pourpre,
      surfaceTintColor: Colors.transparent,
      width: 305,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête : logo + état sync ──
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
                  const SizedBox(height: 4),
                  Text(
                    contenu.jamaisSynchronise
                        ? 'Contenu pas encore téléchargé'
                        : _enLigne
                            ? 'En ligne — contenu à jour'
                            : 'Hors ligne — dernières données',
                    style: TextStyle(
                      color: contenu.jamaisSynchronise
                          ? AppColors.texteEteint
                          : _enLigne
                              ? AppColors.enLigne
                              : AppColors.orPastel,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.or.withValues(alpha: 0.15)),

            // ── Navigation ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _ItemMenu(
                    icone: Icons.home_outlined,
                    libelle: 'Accueil',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/app');
                    },
                  ),
                  const _GroupeMenu(label: 'SERVITEURS'),
                  _ItemMenu(
                    icone: Icons.face_3_outlined,
                    libelle: 'Afrika',
                    sousLibelle: 'Servante de l\'Éternel',
                    onTap: () => _aller('/app/serviteur/afrika'),
                  ),
                  _ItemMenu(
                    icone: Icons.church_outlined,
                    libelle: 'Pasteur Kongo',
                    sousLibelle: 'Époux, ministre pastoral',
                    onTap: () => _aller('/app/serviteur/kongo'),
                  ),
                  const _GroupeMenu(label: 'PAROLE'),
                  _ItemMenu(
                    icone: Icons.auto_awesome_outlined,
                    libelle: 'Témoignages',
                    onTap: () => _aller('/app/temoignages'),
                  ),
                  _ItemMenu(
                    icone: Icons.school_outlined,
                    libelle: 'Enseignements',
                    onTap: () => _aller('/app/enseignements'),
                  ),
                  _ItemMenu(
                    icone: Icons.menu_book_outlined,
                    libelle: 'Bible',
                    onTap: () => _aller('/app/bible'),
                  ),
                  const _GroupeMenu(label: 'MÉDIA'),
                  _ItemMenu(
                    icone: Icons.play_circle_outline,
                    libelle: 'Vidéos & Lives',
                    badge: contenu.videos.isEmpty ? null : '${contenu.videos.length}',
                    onTap: () => _aller('/app/videos'),
                  ),
                  _ItemMenu(
                    icone: Icons.music_note_outlined,
                    libelle: 'Adoration & Louanges',
                    onTap: () => _aller('/app/adoration'),
                  ),
                  _ItemMenu(
                    icone: Icons.calendar_month_outlined,
                    libelle: 'Calendrier 364',
                    onTap: () => _aller('/app/calendrier'),
                  ),
                  const _GroupeMenu(label: 'COMMUNAUTÉ'),
                  _ItemMenu(
                    icone: Icons.forum_outlined,
                    libelle: 'Yeshua Connect',
                    sousLibelle: 'Messagerie de la communauté',
                    accent: true,
                    onTap: () => _aller('/app/connect'),
                  ),
                  _ItemMenu(
                    icone: Icons.volunteer_activism_outlined,
                    libelle: 'Intercession',
                    onTap: () => _aller('/app/intercession'),
                  ),
                  _ItemMenu(
                    icone: Icons.public_outlined,
                    libelle: 'Dispersés d\'Issos Lélé',
                    onTap: () => _aller('/app/disperses'),
                  ),
                  _ItemMenu(
                    icone: Icons.campaign_outlined,
                    libelle: 'Annonces',
                    badge: contenu.annonces.isEmpty ? null : '${contenu.annonces.length}',
                    onTap: () => _aller('/app/annonces'),
                  ),
                  _ItemMenu(
                    icone: Icons.event_available_outlined,
                    libelle: 'Rendez-vous',
                    onTap: () => _aller('/app/rendez-vous'),
                  ),
                  const _GroupeMenu(label: 'SOUTENIR'),
                  _ItemMenu(
                    icone: Icons.favorite_outline,
                    libelle: 'Contribuer',
                    sousLibelle: 'Dons sécurisés',
                    onTap: () => _aller('/app/contribuer'),
                  ),
                ],
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
                        Navigator.of(context).pop();
                        context.push('/app/connect/profil');
                      },
                      icon: const Icon(Icons.person_outline, size: 18),
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

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String? sousLibelle;
  final String? badge;
  final bool accent;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.sousLibelle,
    this.badge,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 26,
      leading: Icon(icone, size: 20, color: accent ? AppColors.or : AppColors.texteSecondaire),
      title: Row(
        children: [
          Flexible(
            child: Text(
              libelle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? AppColors.or : AppColors.texte,
                fontSize: 14,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
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
              style: const TextStyle(color: AppColors.texteEteint, fontSize: 11),
            )
          : null,
      onTap: onTap,
    );
  }
}
