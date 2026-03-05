import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:viro_team/main.dart' as app;

/// Test d'intégration : vérifie que l'application démarre sans crasher.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows first frame', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 15));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
