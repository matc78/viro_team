import 'package:flutter/material.dart';

class ViroColors {
  // Palette principale
  static const Color text = Color(0xFF050315);
  static const Color background = Color(0xFFFBFBFE);
  static const Color primary = Color(0xFF2F27CE);
  static const Color secondary = Color(0xFFDEDCFF);
  static const Color accent = Color(0xFF433BFF);

  // Couleurs techniques & délimitations
  static const Color borderColor = Color(0xFFD1D1D1);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F); // Jaune pour "En attente"
  static const Color error = Color(0xFFE74C3C); // Rouge pour "Erreur"

  /// Palette de couleurs pour différencier les clubs (calendrier, cartes, etc.)
  static const List<Color> clubPalette = [
    Color(0xFF2F27CE), // Bleu ViroTeam (Primary)
    Color(0xFFE91E63), // Rose Électrique (Pink accent)
    Color(0xFF00B8D4), // Cyan Profond (Plus lisible que le néon)
    Color(0xFFFF6D00), // Orange Brûlé (Sportif et ultra lisible)
    Color(0xFF6200EA), // Violet Impérial
    Color(0xFF00C853), // Vert Jungle (Énergie terrain)
    Color(0xFFD50000), // Rouge Racing
    Color(0xFF0091EA), // Bleu Azur Sport
  ];
}

class ViroTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ViroColors.background,
      colorScheme: const ColorScheme.light(
        primary: ViroColors.primary,
        secondary: ViroColors.secondary,
        surface: ViroColors.background,
        error: ViroColors.error,
      ),

      // Configuration des Textes
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: ViroColors.text,
          fontWeight: FontWeight.w900,
          fontSize: 32,
        ),
        titleLarge: TextStyle(
          color: ViroColors.text,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        bodyMedium: TextStyle(color: ViroColors.text, fontSize: 14),
      ),

      // Délimitation du Header (AppBar)
      appBarTheme: const AppBarTheme(
        backgroundColor: ViroColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ViroColors.text,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: ViroColors.primary),
        shape: Border(
          bottom: BorderSide(color: ViroColors.borderColor, width: 1),
        ),
      ),

      // Style des Boutons Primaires (Pleins)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ViroColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: ViroColors.borderColor, width: 0.5),
          ),
        ),
      ),

      // Style des Boutons Secondaires (Contours)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ViroColors.text,
          side: const BorderSide(color: ViroColors.borderColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Style des Cartes (Widgets délimités)
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ViroColors.borderColor, width: 1.5),
        ),
      ),

      // Style des Inputs (Formulaires)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: ViroColors.borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: ViroColors.primary, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
