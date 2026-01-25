import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/pages/auth_page.dart';
import 'package:viro_team/theme/viro_theme.dart';

void main() {
  group('AuthPage', () {
    testWidgets('affiche le formulaire de connexion par défaut', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      expect(find.text('Bon retour !'), findsOneWidget);
      expect(find.text('SE CONNECTER'), findsOneWidget);
      expect(find.text('Pas encore de compte ? Inscris-toi'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // email, password
    });

    testWidgets('bascule vers inscription au clic sur le lien', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.tap(find.text('Pas encore de compte ? Inscris-toi'));
      await tester.pumpAndSettle();

      expect(find.text('Rejoins ViroTeam'), findsOneWidget);
      expect(find.text('CRÉER UN COMPTE'), findsOneWidget);
      expect(find.text('Déjà un compte ? Connecte-toi'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5)); // prénom, nom, email, mdp, confirm
    });

    testWidgets('validation email vide en mode connexion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      expect(find.text("L'email est requis"), findsOneWidget);
    });

    testWidgets('validation email invalide', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.tap(find.text('SE CONNECTER'));
      await tester.pumpAndSettle();

      expect(find.text('Format d\'email invalide'), findsOneWidget);
    });

    testWidgets('validation mot de passe requis en mode inscription', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.tap(find.text('Pas encore de compte ? Inscris-toi'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jean');
      await tester.enterText(fields.at(1), 'Dupont');
      await tester.enterText(fields.at(2), 'jean@test.fr');
      await tester.ensureVisible(find.text('CRÉER UN COMPTE'));
      await tester.tap(find.text('CRÉER UN COMPTE'));
      await tester.pumpAndSettle();

      expect(find.text('Le mot de passe est requis'), findsOneWidget);
    });

    testWidgets('validation mot de passe trop court en inscription', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.tap(find.text('Pas encore de compte ? Inscris-toi'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jean');
      await tester.enterText(fields.at(1), 'Dupont');
      await tester.enterText(fields.at(2), 'jean@test.fr');
      await tester.enterText(fields.at(3), 'Short1');
      await tester.enterText(fields.at(4), 'Short1');
      await tester.ensureVisible(find.text('CRÉER UN COMPTE'));
      await tester.tap(find.text('CRÉER UN COMPTE'));
      await tester.pumpAndSettle();

      expect(find.text('Le mot de passe doit contenir au moins 8 caractères'), findsOneWidget);
    });

    testWidgets('validation confirmation mot de passe différente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      await tester.tap(find.text('Pas encore de compte ? Inscris-toi'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jean');
      await tester.enterText(fields.at(1), 'Dupont');
      await tester.enterText(fields.at(2), 'jean@test.fr');
      await tester.enterText(fields.at(3), 'ValidPass1');
      await tester.enterText(fields.at(4), 'ValidPass2');
      await tester.ensureVisible(find.text('CRÉER UN COMPTE'));
      await tester.tap(find.text('CRÉER UN COMPTE'));
      await tester.pumpAndSettle();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });

    testWidgets('affiche le logo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ViroTheme.lightTheme,
          home: const AuthPage(),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}
