import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/theme/viro_theme.dart';

void main() {
  group('ViroColors', () {
    test('définit les couleurs principales', () {
      expect(ViroColors.primary, isNotNull);
      expect(ViroColors.secondary, isNotNull);
      expect(ViroColors.text, isNotNull);
      expect(ViroColors.background, isNotNull);
      expect(ViroColors.error, isNotNull);
      expect(ViroColors.success, isNotNull);
    });

    test('primary a la valeur attendue', () {
      expect(ViroColors.primary, const Color(0xFF2F27CE));
    });

    test('error a la valeur attendue', () {
      expect(ViroColors.error, const Color(0xFFE74C3C));
    });
  });

  group('ViroTheme', () {
    test('lightTheme retourne un ThemeData non null', () {
      expect(ViroTheme.lightTheme, isNotNull);
      expect(ViroTheme.lightTheme, isA<ThemeData>());
    });

    test('lightTheme utilise useMaterial3', () {
      expect(ViroTheme.lightTheme.useMaterial3, isTrue);
    });

    test('lightTheme a scaffoldBackgroundColor', () {
      expect(
        ViroTheme.lightTheme.scaffoldBackgroundColor,
        ViroColors.background,
      );
    });

    test('lightTheme définit colorScheme.primary', () {
      expect(
        ViroTheme.lightTheme.colorScheme.primary,
        ViroColors.primary,
      );
    });

    test('lightTheme définit textTheme.headlineLarge', () {
      final headline = ViroTheme.lightTheme.textTheme.headlineLarge;
      expect(headline, isNotNull);
      expect(headline!.color, ViroColors.text);
    });

    test('lightTheme définit appBarTheme', () {
      expect(ViroTheme.lightTheme.appBarTheme.backgroundColor, ViroColors.background);
    });
  });
}
