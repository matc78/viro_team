import 'package:flutter/material.dart';

/// Tokens couleur — bleu profond, surfaces claires contrastées.
abstract final class ViroColors {
  // Primary (Deep Blue — palette assombrie)
  static const Color primary50 = Color(0xFFD4E4F4);
  static const Color primary100 = Color(0xFF9BB8DC);
  static const Color primary200 = Color(0xFF5E8DBF);
  static const Color primary400 = Color(0xFF1A5F9E);
  static const Color primary600 = Color(0xFF134A7D);
  static const Color primary800 = Color(0xFF0B3358);
  static const Color primary900 = Color(0xFF061F38);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color neutral = Color(0xFF6B7280);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF4F6F9);
  static const Color gray100 = Color(0xFFECEFF4);
  static const Color gray200 = Color(0xFFE2E6ED);
  static const Color gray300 = Color(0xFFC8CED8);
  static const Color gray400 = Color(0xFF8B95A5);
  static const Color gray600 = Color(0xFF4A5568);
  static const Color gray900 = Color(0xFF111827);

  // Surfaces & fond (harmonie douce, pas de bleu opaque plein écran)
  static const Color scaffold = Color(0xFFE9EFF7);
  static const Color scaffoldHighlight = Color(0xFFF6F9FC);
  static const Color scaffoldDepth = Color(0xFFE2E9F2);
  static const Color surface = Color(0xFFFAFCFE);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Dégradé principal derrière tout le contenu.
  static const LinearGradient scaffoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [scaffoldHighlight, scaffold, scaffoldDepth],
    stops: [0.0, 0.55, 1.0],
  );

  /// Bandeau haut (AppBar) — fusionne avec le fond.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FAFD),
      Color(0xFFF0F5FA),
    ],
  );

  // Role badges — couleurs vives (dégradés dans [ViroRoleBadge])
  static const Color playerBadgeStart = Color(0xFF3B82F6);
  static const Color playerBadgeEnd = Color(0xFF1D4ED8);

  static const Color coachBadgeStart = Color(0xFFFB923C);
  static const Color coachBadgeEnd = Color(0xFFEA580C);

  static const Color parentBadgeStart = Color(0xFF34D399);
  static const Color parentBadgeEnd = Color(0xFF059669);

  static const Color adminBadgeStart = Color(0xFFA78BFA);
  static const Color adminBadgeEnd = Color(0xFF7C3AED);

  static const Color roleBadgeText = white;
  static const Color roleBadgeIconBg = Color(0x33FFFFFF);
}
