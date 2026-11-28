/// 🎨 Charte graphique de l'app Christ Libère — identique à la plateforme web.
///
/// - **Nuit** `#1E0F2B` : fond principal
/// - **Pourpre** `#2A0E3D` : fond secondaire / cartes / surfaces
/// - **Or** `#C9A227` : accents, actions, titres soulignés
library;

import 'package:flutter/material.dart';
class AppColors {
  AppColors._();

  // ── Palette officielle ──
  static const Color nuit = Color(0xFF1E0F2B);
  static const Color pourpre = Color(0xFF2A0E3D);
  static const Color or = Color(0xFFC9A227);

  // ── Dérivés utiles ──
  static const Color nuitClair = Color(0xFF2A1638);
  static const Color pourpreClair = Color(0xFF3A1A52);
  static const Color orFonce = Color(0xFF9A7A1E);
  static const Color orPastel = Color(0xFFE3C866);

  // ── ⭐ V2.17 — TOUCHES « FLAMME » & VIOLET ROYAL (palette du logo) ──
  // Le sceau du ministère porte trois feux : l'or (#C9A227), la flamme
  // braise (rouges profonds du logo) et le violet royal. Ces teintes
  // alimentent les dégradés lumineux (traits, médaillons, liserés,
  // boutons) qui embellissent toute l'interface — demande pasteur :
  // « du design autour des boutons, des traits lumineux ».
  static const Color flamme = Color(0xFFC2410C);      // braise orangée
  static const Color flammeFonce = Color(0xFF9A2E0C); // braise profonde
  static const Color flammeVive = Color(0xFFF97316);  // éclat de flamme
  static const Color violetRoyal = Color(0xFF4C1D95); // violet lumineux
  static const Color violetHalo = Color(0xFF7C3AED);  // violet éclatant

  // ── ⭐ V2.17 — Dégradés officiels réutilisables ──
  /// Or → flamme : médaillons et boutons d'or enflammé.
  static const List<Color> feuOr = [Color(0xFFE3C866), Color(0xFFC9A227), Color(0xFFC2410C)];
  /// Violet → nuit : surfaces royales (cartes Espace, en-tête du tiroir).
  static const List<Color> nuitRoyale = [Color(0xFF4C1D95), Color(0xFF2A0E3D), Color(0xFF1E0F2B)];
  /// Trait lumineux complet : or → flamme → violet (signature du sceau).
  static const List<Color> triomphe = [Color(0xFFC9A227), Color(0xFFC2410C), Color(0xFF4C1D95)];

  // ── ⭐ V4.47 — Palette CLAIRE du site web (parité « pattern landing ») ──
  // Les écrans de CONTENU (accueil, témoignages, bibliothèque,
  // enseignements…) passent sur le fond crème du site public : le violet
  // n'est plus le fond de tout, il ne reste que PAR TOUCHES (barres,
  // en-têtes, boutons primaires, onglets actifs) — exactement comme le web.
  static const Color fond = Color(0xFFFAF6EF);            // crème du site
  static const Color carte = Color(0xFFFFFFFF);           // cartes blanches
  static const Color encre = Color(0xFF1E0F2B);           // texte sombre
  static const Color encreSecondaire = Color(0xFF8A8378); // texte atténué
  static const Color encreEteinte = Color(0xFFB0A89E);    // texte discret
  static const Color bordure = Color(0x268A8378);         // filets ~15 %

  // ── Textes ──
  static const Color texte = Color(0xFFF5F0FA);
  static const Color texteSecondaire = Color(0xFFB8A8CE);
  static const Color texteEteint = Color(0xFF7E6E96);

  // ── États ──
  static const Color enLigne = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFE5484D);
  static const Color succes = Color(0xFF30A46C);

  // ── Bulles de chat ──
  static const Color bulleMoi = Color(0xFF3A1A52);      // mes messages (pourpre clair)
  static const Color bulleAutre = Color(0xFF261233);    // messages reçus (nuit légèrement éclairci)

  // ── Fonction : couleur d'accent par type de conversation ──
  static Color typeAccent(String type) {
    switch (type) {
      case 'DIRECT':
        return or;
      case 'PASTORS':
        return const Color(0xFFB08FFF);
      case 'VOICE':
        return const Color(0xFF5AC8FA);
      case 'GROUP':
        return const Color(0xFF7BD88F);
      case 'CHANNEL':
      default:
        return orPastel;
    }
  }
}
