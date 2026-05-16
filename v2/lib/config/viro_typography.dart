import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:viro_team_v2/config/viro_colors.dart';

/// Échelle typo Inter — viroheam_v2_design_system_final.md
abstract final class ViroTypography {
  static TextTheme textTheme(TextTheme base) {
    final inter = GoogleFonts.interTextTheme(base).apply(
      bodyColor: ViroColors.gray900,
      displayColor: ViroColors.gray900,
    );

    return inter.copyWith(
      headlineLarge: inter.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ViroColors.gray900,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ViroColors.gray900,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: ViroColors.gray900,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ViroColors.gray900,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ViroColors.gray600,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ViroColors.gray400,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: ViroColors.gray600,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: ViroColors.gray600,
      ),
    );
  }

  static TextStyle get sectionHeader => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: ViroColors.gray600,
      );
}
