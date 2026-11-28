/// ⭐ V2.16 — ÉCRAN « ESPACE » — portes d'entrée des ESPACES PRIVÉS du
/// ministère dans l'application mobile.
///
/// Demande du pasteur : le back-office, le secrétariat et la trésorerie
/// possèdent chacun LEUR sous-domaine sur la plateforme web :
///   · admin.mouvementchristlibere.com       → back-office (super admins)
///   · secretariat.mouvementchristlibere.com → secrétariat (demandes,
///     rendez-vous, retraite spirituelle, annonces)
///   · tresorerie.mouvementchristlibere.com  → trésorerie (journal
///     financier — hautement confidentiel)
///
/// La VERSION WEB de chaque espace est ENCAPSULÉE dans l'application
/// (WebView plein écran — EspaceWebScreen) : la page de connexion officielle
/// s'affiche, l'admin/la secrétaire/le trésorier entre ses identifiants
/// UNE fois et la session reste enregistrée (cookies persistants du
/// WebView) — ensuite, l'espace s'ouvre directement avec TOUTES ses
/// fonctionnalités, exactement comme sur un navigateur.
///
/// Aucune donnée n'est réinventée côté Flutter : c'est le même code web,
/// les mêmes sessions (cookie `admin_session` propre à chaque hôte), les
/// mêmes rôles — la moindre évolution du web est immédiatement disponible
/// dans l'app sans nouvelle publication.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/ornements.dart';
import 'espace_web_screen.dart';

/// Une porte d'entrée d'espace privé (nom, sous-domaine, icône, rôle).
class _Espace {
  final String titre;
  final String sousDomaine;
  final String description;
  final IconData icone;

  const _Espace({
    required this.titre,
    required this.sousDomaine,
    required this.description,
    required this.icone,
  });

  /// URL d'entrée : le proxy web redirige « / » vers /<espace>/dashboard
  /// (ou la page de connexion si aucune session n'est enregistrée).
  String get url => 'https://$sousDomaine/';
}

const List<_Espace> _espaces = [
  _Espace(
    titre: 'Back-office',
    sousDomaine: 'admin.mouvementchristlibere.com',
    description: 'Administration du ministère — contenu, médias, membres.',
    icone: Icons.admin_panel_settings_outlined,
  ),
  _Espace(
    titre: 'Secrétariat',
    sousDomaine: 'secretariat.mouvementchristlibere.com',
    description: 'Demandes reçues, rendez-vous, retraite spirituelle.',
    icone: Icons.business_center_outlined,
  ),
  _Espace(
    titre: 'Trésorerie',
    sousDomaine: 'tresorerie.mouvementchristlibere.com',
    description: 'Journal financier et suivi des dons — accès confidentiel.',
    icone: Icons.account_balance_wallet_outlined,
  ),
];

class EspacesScreen extends StatelessWidget {
  const EspacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.encre),
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: 'Espace ',
                  style: TextStyle(color: AppColors.or)),
              TextSpan(
                  text: 'privé',
                  style: TextStyle(color: AppColors.encre)),
            ],
          ),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Les espaces internes du ministère, directement dans '
            'l\'application — la version web complète est ouverte ici même, '
            'avec la page de connexion officielle de chaque espace.',
            style: TextStyle(
              color: AppColors.encreSecondaire,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          // ⭐ V2.17 — trait lumineux : la signature du sceau avant les
          //    trois portes.
          const TraitLumineux(largeur: 150, epaisseur: 2),
          const SizedBox(height: 14),
          // ── Les trois portes d'entrée ──
          for (final espace in _espaces)
            _CarteEspace(
              espace: espace,
              onTap: () => _ouvrirEspace(context, espace),
            ),
          const SizedBox(height: 20),
          // ── Note de sécurité ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pourpre.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.or.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.or.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Accès réservé aux responsables autorisés. La connexion '
                    'se fait sur la page officielle de chaque espace ; vos '
                    'identifiants ne transitent jamais par autre chose que '
                    'le site sécurisé du ministère, et la session reste '
                    'ouverte jusqu\'à votre déconnexion.',
                    style: TextStyle(
                      color: AppColors.encreSecondaire,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _ouvrirEspace(BuildContext context, _Espace espace) {
    // go_router pousse l'écran WebView plein écran au-dessus de tout —
    // le retour (flèche) ramène ici.
    GoRouter.of(context).push(
      '/app/espaces/web',
      extra: EspaceWebParams(
        titre: espace.titre,
        url: espace.url,
        hote: espace.sousDomaine,
      ),
    );
  }
}

/// Carte d'un espace — ⭐ V2.17 : PORTE ROYALE. Carte blanche cerclée
/// d'un liseré lumineux or → flamme → violet, médaillon violet royal +
/// halo, pastille de sous-domaine pourpre — le coffret des clés du
/// ministère, pas une simple ligne de liste.
class _CarteEspace extends StatelessWidget {
  final _Espace espace;
  final VoidCallback onTap;

  const _CarteEspace({required this.espace, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CarteLumineuse(
        onTap: onTap,
        rayon: 16,
        epaisseurLiseret: 1.3,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Médaillon violet royal de l'espace (halo violet dessous).
            MedaillonLumineux(
              icone: espace.icone,
              taille: 46,
              gradient: const [
                AppColors.violetHalo,
                AppColors.violetRoyal,
                AppColors.pourpre,
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    espace.titre,
                    style: const TextStyle(
                      color: AppColors.encre,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    espace.description,
                    style: const TextStyle(
                      color: AppColors.encreSecondaire,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ⭐ V2.17 — pastille du sous-domaine : pourpre posé,
                  //    texte doré, globe minuscule.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.pourpre.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.or.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          size: 11,
                          color: AppColors.orFonce.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            espace.sousDomaine,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  AppColors.orFonce.withValues(alpha: 0.95),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chevron doré dans son médaillon posé.
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.or.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: AppColors.orFonce,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
