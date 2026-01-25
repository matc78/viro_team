import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/pages/fatal_error_page.dart';
import 'package:viro_team/widget/fatal_error_app.dart';

void main() {
  group('FatalErrorPage Tests', () {
    testWidgets('Affiche le message d\'erreur correctement', (tester) async {
      const testError = 'Test error message';
      
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: testError),
        ),
      );

      // Vérifier que le titre est affiché
      expect(find.text('Erreur de démarrage'), findsOneWidget);
      
      // Vérifier que le message d'erreur générique est affiché
      expect(
        find.text('Une erreur critique est survenue lors du démarrage de l\'application.'),
        findsOneWidget,
      );
    });

    testWidgets('Affiche le message d\'erreur Firebase pour les erreurs Firebase', (tester) async {
      const testError = 'Firebase initialization failed';
      
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: testError),
        ),
      );

      expect(find.text('Erreur de démarrage'), findsOneWidget);
      expect(
        find.textContaining('Impossible d\'initialiser les services Firebase'),
        findsOneWidget,
      );
    });

    testWidgets('Affiche le message d\'erreur réseau pour les erreurs réseau', (tester) async {
      const testError = 'Network connection timeout';
      
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: testError),
        ),
      );

      expect(find.text('Erreur de démarrage'), findsOneWidget);
      expect(
        find.textContaining('Problème de connexion internet'),
        findsOneWidget,
      );
    });

    testWidgets('Affiche les détails techniques quand stackTrace est fourni', (tester) async {
      const testError = 'Test error';
      final stackTrace = StackTrace.fromString('Test stack trace');
      
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: testError, stackTrace: stackTrace),
        ),
      );

      // Vérifier que l'ExpansionTile pour les détails techniques est présent
      expect(find.text('Détails techniques'), findsOneWidget);
      
      // Ouvrir l'expansion tile
      await tester.tap(find.text('Détails techniques'));
      await tester.pumpAndSettle();
      
      // Vérifier que le contenu est affiché
      expect(find.textContaining('Erreur: $testError'), findsOneWidget);
      expect(find.textContaining('StackTrace:'), findsOneWidget);
    });

    testWidgets('N\'affiche pas les détails techniques quand stackTrace est null', (tester) async {
      const testError = 'Test error';
      
      await tester.pumpWidget(
        MaterialApp(
          home: FatalErrorPage(error: testError),
        ),
      );

      // Vérifier que l'ExpansionTile n'est pas présent
      expect(find.text('Détails techniques'), findsNothing);
    });
  });

  group('FatalErrorApp Tests', () {
    testWidgets('Affiche correctement l\'application d\'erreur fatale', (tester) async {
      const testError = 'Test error';
      
      await tester.pumpWidget(
        const FatalErrorApp(error: testError),
      );

      // Vérifier que la page d'erreur est affichée
      expect(find.text('Erreur de démarrage'), findsOneWidget);
    });

    testWidgets('Utilise le thème ViroTheme', (tester) async {
      const testError = 'Test error';
      
      await tester.pumpWidget(
        const FatalErrorApp(error: testError),
      );

      // Vérifier que le MaterialApp est configuré avec le bon thème
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.debugShowCheckedModeBanner, false);
      expect(materialApp.locale, const Locale('fr'));
    });
  });

  group('Gestion d\'erreurs asynchrones', () {
    test('runZonedGuarded capture les erreurs asynchrones', () async {
      bool errorCaught = false;
      Object? caughtError;
      StackTrace? caughtStack;

      // Simuler runZonedGuarded
      runZonedGuarded(() async {
        // Simuler une erreur asynchrone
        Future.delayed(const Duration(milliseconds: 10), () {
          throw Exception('Erreur asynchrone test');
        });
        
        // Attendre que l'erreur se produise
        await Future.delayed(const Duration(milliseconds: 50));
      }, (error, stack) {
        errorCaught = true;
        caughtError = error;
        caughtStack = stack;
      });

      // Attendre que l'erreur soit capturée
      await Future.delayed(const Duration(milliseconds: 100));

      expect(errorCaught, isTrue);
      expect(caughtError, isA<Exception>());
      expect(caughtStack, isNotNull);
    });
  });

  group('Messages d\'erreur personnalisés', () {
    testWidgets('Détecte correctement les erreurs Firebase', (tester) async {
      final firebaseErrors = [
        'Firebase initialization failed',
        'Firestore connection error',
        'firebase_core error',
      ];

      for (final error in firebaseErrors) {
        await tester.pumpWidget(
          MaterialApp(
            home: FatalErrorPage(error: error),
          ),
        );

        expect(
          find.textContaining('Impossible d\'initialiser les services Firebase'),
          findsOneWidget,
          reason: 'Devrait détecter l\'erreur Firebase: $error',
        );
      }
    });

    testWidgets('Détecte correctement les erreurs réseau', (tester) async {
      final networkErrors = [
        'Network connection failed',
        'Socket exception',
        'Connection timeout',
        'No internet connection',
      ];

      for (final error in networkErrors) {
        await tester.pumpWidget(
          MaterialApp(
            home: FatalErrorPage(error: error),
          ),
        );

        expect(
          find.textContaining('Problème de connexion internet'),
          findsOneWidget,
          reason: 'Devrait détecter l\'erreur réseau: $error',
        );
      }
    });
  });
}
