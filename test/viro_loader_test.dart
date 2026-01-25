import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/widget/viro_loader.dart';

void main() {
  group('ViroLoader', () {
    testWidgets('affiche un loader avec taille par défaut', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ViroLoader(),
          ),
        ),
      );

      expect(find.byType(ViroLoader), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('affiche un loader avec taille personnalisée', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ViroLoader(size: 50),
          ),
        ),
      );

      final loader = tester.widget<ViroLoader>(find.byType(ViroLoader));
      expect(loader.size, 50);
    });

    testWidgets('contient un SizedBox avec les dimensions correctes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ViroLoader(size: 80),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ViroLoader),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, 80);
      expect(sizedBox.height, 80);
    });
  });
}
