import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/pages/auth_page.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/widget/viro_loader.dart';

/// Tests widget basiques (sans Firebase).
/// MyApp dépend de Firebase et ne peut pas être testé en unitaire sans mocks.
void main() {
  group('Widgets basiques', () {
    testWidgets('ViroLoader s\'affiche correctement', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ViroLoader(size: 40)),
        ),
      );
      expect(find.byType(ViroLoader), findsOneWidget);
    });

    testWidgets('AuthPage se construit sans erreur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );
      expect(find.byType(AuthPage), findsOneWidget);
    });

    testWidgets('MaterialApp avec ViroTheme a un thème cohérent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Test')),
          ),
        ),
      );
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme!.useMaterial3, isTrue);
    });
  });
}
