/// 🎨 Charte graphique Yeshua Connect — identique à la plateforme web.
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
