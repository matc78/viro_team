import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';

/// Parse une couleur hex (#RRGGBB) ou dérive une couleur stable depuis un id.
Color clubAccentColor({String? brandColorHex, required String clubId}) {
  if (brandColorHex != null && brandColorHex.isNotEmpty) {
    final hex = brandColorHex.replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
  }
  final hash = clubId.hashCode.abs();
  final hues = [
    ViroColors.primary400,
    const Color(0xFF0D9488),
    const Color(0xFF7C3AED),
    const Color(0xFFDB2777),
    const Color(0xFFCA8A04),
    const Color(0xFF2563EB),
  ];
  return hues[hash % hues.length];
}
