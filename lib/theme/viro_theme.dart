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

  /// Indices de la palette réservés aux badges licence (orange = 3, vert = 5) ; les catégories ne les utilisent pas.
  static const List<int> _categoryPaletteIndices = [0, 1, 2, 4, 6, 7];

  /// Couleur déterministe par catégorie d'équipe (U7, Sénior, etc.).
  /// Utilisée dans le planning et la page équipes. N'utilise pas orange ni vert (réservés à Licencié / Non licencié).
  static Color getCategoryColor(String category) {
    if (category.trim().isEmpty) return primary;
    final i = category.hashCode.abs() % _categoryPaletteIndices.length;
    return clubPalette[_categoryPaletteIndices[i]];
  }

  /// Couleurs réservées pour les badges membres (rôles + licence) afin qu'aucun ne se confonde.
  /// Licencié = vert (index 5), Non licencié = orange (index 3) obligatoirement.
  static const Map<String, int> _memberBadgeReservedIndices = {
    'Admin Fondateur': 0,
    'Admin': 1,
    'Coach': 2,
    'Non licencié': 3, // Orange (palette index 3)
    'Sans catégorie': 4,
    'Licencié': 5, // Vert (palette index 5)
  };

  /// Couleur pour un badge de la page membres : rôles, licence ou catégorie.
  /// Garantit que Admin Fondateur, Admin, Coach, Licencié, Non licencié et Sans catégorie ont des couleurs distinctes.
  static Color getMemberBadgeColor(String label) {
    final key = label.trim();
    if (key.isEmpty) return primary;
    final reserved = _memberBadgeReservedIndices[key];
    if (reserved != null) return clubPalette[reserved];
    // Catégories : utiliser uniquement les indices 6 et 7 pour éviter toute collision avec les réservés
    final categoryIndex = 6 + (key.hashCode.abs() % 2);
    return clubPalette[categoryIndex];
  }
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
