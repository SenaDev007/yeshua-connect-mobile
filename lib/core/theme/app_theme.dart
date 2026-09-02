/// Thème MaterialApp de Yeshua Connect — dark uniquement (charte nuit).
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nuit,
      canvasColor: AppColors.nuit,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.or,
        onPrimary: AppColors.nuit,
        secondary: AppColors.orPastel,
        onSecondary: AppColors.nuit,
        surface: AppColors.pourpre,
        onSurface: AppColors.texte,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.texteEteint,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.nuit,
        foregroundColor: AppColors.texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.texte,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: const CardTheme(
        color: AppColors.pourpre,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33C9A227),
        thickness: 0.8,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.orPastel,
        textColor: AppColors.texte,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.texte,
        displayColor: AppColors.texte,
        fontFamily: null,
      ).copyWith(
        titleLarge: const TextStyle(
          color: AppColors.texte,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: AppColors.texte,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(color: AppColors.texte, fontSize: 14.5, height: 1.35),
        bodySmall: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12),
        labelSmall: const TextStyle(color: AppColors.texteSecondaire, fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pourpre,
        hintStyle: const TextStyle(color: AppColors.texteSecondaire),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orFonce),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x55C9A227)),
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
          backgroundColor: AppColors.or,
          foregroundColor: AppColors.nuit,
          disabledBackgroundColor: AppColors.orFonce.withOpacity(0.35),
          disabledForegroundColor: AppColors.texteSecondaire,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.or,
          side: const BorderSide(color: AppColors.or),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.or),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.pourpre,
        selectedItemColor: AppColors.or,
        unselectedItemColor: AppColors.texteEteint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.pourpre,
        modalBackgroundColor: AppColors.pourpre,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.pourpreClair,
        contentTextStyle: const TextStyle(color: AppColors.texte),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.or),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.or : null,
        ),
      ),
    );
  }
}
