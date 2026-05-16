import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team_v2/config/viro_theme.dart';
import 'package:viro_team_v2/features/members/widgets/add_member_sheet.dart';

void main() {
  testWidgets('bouton Ajouter désactivé si champs vides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ViroTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAddMemberSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(ElevatedButton, 'Ajouter');
    final button = tester.widget<ElevatedButton>(addButton);
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Jean');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(addButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'Dupont');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(addButton).onPressed, isNotNull);
  });
}
