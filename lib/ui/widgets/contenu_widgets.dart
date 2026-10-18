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
  if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('data:')) {
    return u;
  }
  if (u.startsWith('/')) return '${AppConfig.apiBaseUrl}$u';
  return u;
}

/// État « premier lancement sans réseau » : le contenu public n'a jamais
/// pu être téléchargé. Bouton Réessayer (relance la synchronisation).
class EtatPremiereSync extends ConsumerWidget {
  final String message;

  const EtatPremiereSync({super.key, this.message = 'Contenu pas encore téléchargé'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              onPressed: () => ref.read(contenuProvider.notifier).synchroniser(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
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
            const Icon(Icons.inbox_outlined, size: 44, color: AppColors.texteEteint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero de page : bannière paramétrée depuis le back-office (/admin/heroes)
/// — kicker doré, titre (accent en or), sous-titre, image de fond voilée.
class HeroEnTete extends StatelessWidget {
  final HeroConfigModele hero;
  final double hauteur;

  const HeroEnTete({super.key, required this.hero, this.hauteur = 190});

  @override
  Widget build(BuildContext context) {
    final fond = resoudreUrl(hero.imageDeFond);
    return Container(
      height: hauteur,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hero.kicker.isNotEmpty) ...[
                Text(
                  hero.kicker.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.or,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              // Titre : accent doré + reste blanc (même construction web).
              Text.rich(
                TextSpan(
                  children: [
                    if (hero.titre.isNotEmpty)
                      TextSpan(
                        text: '${hero.titre} ',
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    if (hero.accentTitre.isNotEmpty)
                      TextSpan(
                        text: hero.accentTitre,
                        style: const TextStyle(
                          color: AppColors.or,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    if (hero.suffixeTitre.isNotEmpty)
                      TextSpan(
                        text: ' ${hero.suffixeTitre}',
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
                Text(
                  hero.sousTitre,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
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
          border: Border.all(color: actif ? AppColors.or : AppColors.pourpreClair),
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

  const CarteContenu({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.pourpreClair.withValues(alpha: 0.6)),
        ),
        child: child,
      ),
    );
  }
}
