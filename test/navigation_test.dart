import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/pages/auth_page.dart';
import 'package:viro_team/pages/fatal_error_page.dart';
import 'package:viro_team/pages/no_internet_page.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/widget/fatal_error_app.dart';

void main() {
  group('Navigation et écrans clés', () {
    testWidgets('AuthPage contient le bouton SE CONNECTER', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );
      expect(find.text('SE CONNECTER'), findsOneWidget);
    });

    testWidgets('AuthPage contient le lien inscription', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );
      expect(find.text('Pas encore de compte ? Inscris-toi'), findsOneWidget);
    });

    testWidgets('NoInternetPage affiche le bouton Actualiser', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const NoInternetPage(),
        ),
      );
      expect(find.text('Actualiser'), findsOneWidget);
      expect(find.text('Pas de connexion internet'), findsOneWidget);
    });

    testWidgets('NoInternetPage a un bouton Actualiser tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: NoInternetPage(
            onConnectionRestored: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final actualiser = find.text('Actualiser');
      expect(actualiser, findsOneWidget);
      await tester.tap(actualiser);
      await tester.pump(const Duration(milliseconds: 100));
      // ConnectivityChecker s'exécute; pas de mock → on ne vérifie pas le callback.
    });

    testWidgets('FatalErrorPage affiche le bouton Réessayer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: 'Test error'),
        ),
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Erreur de démarrage'), findsOneWidget);
    });

    testWidgets('FatalErrorApp enveloppe FatalErrorPage dans MaterialApp', (tester) async {
      await tester.pumpWidget(
        const FatalErrorApp(error: 'Init error'),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Erreur de démarrage'), findsOneWidget);
    });

    testWidgets('FatalErrorPage snackbar au tap Réessayer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: 'Test'),
        ),
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Veuillez redémarrer l\'application manuellement'),
        findsOneWidget,
      );
    });
  });
}
