/// Thème MaterialApp de l'app Christ Libère.
///
/// ⭐ V4.47 — BASCULE « pattern landing » (parité avec le site web) :
/// les écrans de contenu sont CLAIRS — fond crème `#FAF6EF`, cartes
/// blanches, texte sombre — et le violet impérial n'est plus le fond de
/// tout : il reste PAR TOUCHES (héros, boutons primaires, barres de
/// navigation basse, snackbars, cases à cocher). Les écrans immersifs
/// (messagerie, appels, lecteurs vidéo, splash/login) restent sur la
/// charte nuit via leurs propres couleurs explicites.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fond,
      canvasColor: AppColors.fond,
      colorScheme: const ColorScheme.light(
        // ⭐ Touches de violet : les widgets Material qui utilisent
        // `primary` (FAB, boutons, switches, sélection) portent le violet
        // impérial avec texte crème — comme les CTA du site.
        primary: AppColors.pourpre,
        onPrimary: AppColors.orPastel,
        secondary: AppColors.or,
        onSecondary: AppColors.nuit,
        surface: AppColors.carte,
        onSurface: AppColors.encre,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.bordure,
      ),
      appBarTheme: const AppBarTheme(
        // Barre claire (comme la navbar du site au repos) ; le violet vit
        // dans les héros et les accents, pas dans chaque barre.
        backgroundColor: AppColors.fond,
        foregroundColor: AppColors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.or),
        titleTextStyle: TextStyle(
          color: AppColors.encre,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      // ⭐ V1.5.1 — CardThemeData (nouveau type exigé par Flutter ≥ 3.29 ;
      // CardTheme n'est plus assignable au paramètre cardTheme).
      cardTheme: const CardThemeData(
        color: AppColors.carte,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.bordure),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.bordure,
        thickness: 0.8,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.orFonce,
        textColor: AppColors.encre,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.encre,
        displayColor: AppColors.encre,
        fontFamily: null,
      ).copyWith(
        titleLarge: const TextStyle(
          color: AppColors.encre,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: AppColors.encre,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(color: AppColors.encre, fontSize: 14.5, height: 1.35),
        bodySmall: const TextStyle(color: AppColors.encreSecondaire, fontSize: 12),
        labelSmall: const TextStyle(color: AppColors.encreSecondaire, fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.carte,
        hintStyle: const TextStyle(color: AppColors.encreSecondaire),
        labelStyle: const TextStyle(color: AppColors.encreSecondaire),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.or, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // ⭐ Touches de violet : boutons primaires violet impérial +
          // texte doré pastel (identique aux CTA du site web).
          backgroundColor: AppColors.pourpre,
          foregroundColor: AppColors.orPastel,
          disabledBackgroundColor: AppColors.pourpre.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.encreSecondaire,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.encre,
          side: const BorderSide(color: AppColors.bordure),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.orFonce),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.pourpre,
        foregroundColor: AppColors.orPastel,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.carte,
        selectedItemColor: AppColors.or,
        unselectedItemColor: AppColors.encreSecondaire,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.carte,
        modalBackgroundColor: AppColors.carte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.carte,
        titleTextStyle: TextStyle(
          color: AppColors.encre,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: AppColors.encreSecondaire, fontSize: 14),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.carte,
        labelStyle: TextStyle(color: AppColors.encre),
        side: BorderSide(color: AppColors.bordure),
      ),
      snackBarTheme: SnackBarThemeData(
        // Violette : la snackbar reste un point de violet identifiable.
        backgroundColor: AppColors.pourpre,
        contentTextStyle: const TextStyle(color: AppColors.carte),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.orPastel
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pourpre
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pourpre
              : null,
        ),
        checkColor: WidgetStateProperty.all(AppColors.orPastel),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.or),
    );
  }
}
