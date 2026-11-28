/// ⭐ V2.17 — ORNEMENTS LUMINEUX : la signature graphique du sceau
/// (or → flamme → violet) posée sur toute l'interface.
///
/// Demande du pasteur : « les boutons sont trop simples, il faut du
/// design autour, des traits lumineux, l'or, la flamme, le violet du
/// logo — que l'interface soit vraiment stylée et jolie à voir. »
///
/// Quatre briques réutilisables partout dans l'app :
///   · [TraitLumineux]      — filet fin or → flamme → violet évanoui
///                            (sous les titres, séparateurs du tiroir) ;
///   · [MedaillonLumineux]  — médaillon dégradé + halo (icônes des
///                            tuiles, items du menu, cartes Espace) ;
///   · [CarteLumineuse]     — carte blanche cerclée d'un liseré dégradé
///                            lumineux et d'une ombre dorée douce ;
///   · [BoutonDore] / [BoutonPourpre] — pilules dégradées or→flamme et
///                            violet royal (CTA du héros, connexion…).
///
/// Tout est construit SANS package supplémentaire : dégradés natifs,
/// ombres douces, formes arrondies — le blanc/crème du site reste la
/// base, la lumière vient des filets et des médaillons.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
//  TRAIT LUMINEUX
// ═══════════════════════════════════════════════════════════════════

/// Filet horizontal or → flamme → violet, évanoui aux extrémités —
/// le « trait lumineux » demandé, hérité des rayons du logo.
class TraitLumineux extends StatelessWidget {
  /// Largeur totale du filet (double.infinity autorisé).
  final double largeur;

  /// Épaisseur du filet (1 à 3).
  final double epaisseur;

  const TraitLumineux({
    super.key,
    this.largeur = 110,
    this.epaisseur = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: epaisseur,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(epaisseur),
        gradient: LinearGradient(
          colors: [
            AppColors.or.withValues(alpha: 0.0),
            AppColors.or,
            AppColors.flamme,
            AppColors.violetRoyal.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MÉDAILLON LUMINEUX
// ═══════════════════════════════════════════════════════════════════

/// Médaillon dégradé (or→flamme ou violet royal) portant une icône
/// blanche, couronné d'un halo de la teinte la plus profonde — la
/// « pierre précieuse » qui remplace les icônes plates des boutons.
class MedaillonLumineux extends StatelessWidget {
  final IconData icone;

  /// Diamètre du médaillon.
  final double taille;

  /// Dégradé de fond (utiliser AppColors.feuOr / nuitRoyale…).
  final List<Color> gradient;

  /// Rond (par défaut) ou carré arrondi [rayon].
  final double? rayon;

  const MedaillonLumineux({
    super.key,
    required this.icone,
    this.taille = 32,
    this.gradient = AppColors.feuOr,
    this.rayon,
  });

  @override
  Widget build(BuildContext context) {
    final forme = rayon == null
        ? BorderRadius.circular(taille / 2) // cercle
        : BorderRadius.circular(rayon!);
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        borderRadius: forme,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        // Halo lumineux : la couleur la plus profonde du dégradé
        // diffuse sous le médaillon — effet « braise posée sur soie ».
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.38),
            blurRadius: taille * 0.42,
            offset: Offset(0, taille * 0.10),
          ),
        ],
      ),
      child: Icon(
        icone,
        size: taille * 0.52,
        color: Colors.white,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE LUMINEUSE
// ═══════════════════════════════════════════════════════════════════

/// Carte blanche cerclée d'un LISERÉ DÉGRADÉ lumineux (or → flamme →
/// violet par défaut, adouci à ~55 %) et posée sur une ombre dorée.
/// Le contenu (blanc crème) reste intact : la lumière vient du cerne.
class CarteLumineuse extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double rayon;

  /// Dégradé du liseré — par défaut la signature adoucie du sceau.
  final List<Color> liseres;

  /// Épaisseur du liseré (1.0 = filet fin, 1.6 = cerne visible).
  final double epaisseurLiseret;

  /// Ombre dorée douce sous la carte.
  final bool ombre;

  const CarteLumineuse({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.rayon = 14,
    this.liseres = const [
      Color(0x8CC9A227), // or 55 %
      Color(0x73C2410C), // flamme 45 %
      Color(0x804C1D95), // violet 50 %
    ],
    this.epaisseurLiseret = 1.2,
    this.ombre = true,
  });

  @override
  Widget build(BuildContext context) {
    final interieur = BorderRadius.circular(rayon - epaisseurLiseret);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: liseres,
        ),
        boxShadow: ombre
            ? [
                BoxShadow(
                  color: AppColors.or.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      // Le dégradé EXTÉRIEUR sert de bordure : le blanc intérieur est
      // simplement enfoncé de [epaisseurLiseret] — filet net, sans pixél.
      padding: EdgeInsets.all(epaisseurLiseret),
      child: ClipRRect(
        borderRadius: interieur,
        child: Material(
          color: AppColors.carte,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BOUTONS DÉGRADÉS
// ═══════════════════════════════════════════════════════════════════

/// Pilule d'OR ENFLAMMÉ : dégradé or pastel → or → flamme, texte nuit
/// audacieux, halo braise sous le bouton — l'action principale.
class BoutonDore extends StatelessWidget {
  final String libelle;
  final IconData? icone;
  final VoidCallback? onPressed;

  /// true → le bouton occupe TOUTE la largeur offerte (pleine largeur).
  final bool pleine;

  const BoutonDore({
    super.key,
    required this.libelle,
    this.icone,
    this.onPressed,
    this.pleine = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.feuOr,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.flamme.withValues(alpha: 0.34),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: pleine ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 17, color: AppColors.nuit),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.nuit,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
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

/// Pilule VIOLET ROYAL : dégradé violet → nuit, texte or pastel,
/// liseré or — l'action secondaire, digne d'un sceau.
class BoutonPourpre extends StatelessWidget {
  final String libelle;
  final IconData? icone;
  final VoidCallback? onPressed;

  const BoutonPourpre({
    super.key,
    required this.libelle,
    this.icone,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violetRoyal, AppColors.pourpre, AppColors.nuit],
        ),
        border: Border.all(color: AppColors.or.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.violetRoyal.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 17, color: AppColors.orPastel),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.orPastel,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
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
//  ANNEAU LUMINEUX (photos des serviteurs)
// ═══════════════════════════════════════════════════════════════════

/// Anneau dégradé or → flamme → violet qui entoure une photo circulaire
/// — « sceau » doré autour des visages des serviteurs de l'accueil.
class AnneauLumineux extends StatelessWidget {
  final Widget child;

  /// Diamètre TOTAL (anneau compris).
  final double taille;

  /// Épaisseur de l'anneau dégradé.
  final double epaisseur;

  const AnneauLumineux({
    super.key,
    required this.child,
    this.taille = 82,
    this.epaisseur = 2.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.triomphe,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33C9A227), // or 20 %
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(epaisseur),
      child: ClipOval(child: child),
    );
  }
}
