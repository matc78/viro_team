import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';

/// Durées, courbes et élévations — interactions fluides et surfaces flottantes.
abstract final class ViroMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration modal = Duration(milliseconds: 320);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;

  static const double pressScale = 0.97;
  static const double hoverScale = 1.015;

  static const double elevationRest = 5;
  static const double elevationHover = 10;
  static const double elevationPressed = 2;
  static const double elevationCard = 8;
  static const double elevationMenu = 12;
  static const double elevationFab = 10;

  /// Ombre générique (boutons, icônes).
  static List<BoxShadow> floatingShadow({
    double opacity = 0.14,
    double blur = 16,
    double y = 6,
  }) =>
      [
        BoxShadow(
          color: ViroColors.primary900.withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity * 0.35),
          blurRadius: blur * 0.35,
          offset: const Offset(0, 2),
        ),
      ];

  /// Ombre des cartes — douce, teintée pour fond dégradé.
  static List<BoxShadow> cardShadow({bool elevated = true}) => [
        BoxShadow(
          color: ViroColors.primary600.withValues(alpha: elevated ? 0.08 : 0.04),
          blurRadius: elevated ? 20 : 12,
          spreadRadius: -4,
          offset: Offset(0, elevated ? 8 : 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}
