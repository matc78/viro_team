import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team_v2/app/viro_app.dart';

void main() {
  testWidgets('affiche l\'aperçu du design system', (WidgetTester tester) async {
    await tester.pumpWidget(const ViroApp());
    await tester.pumpAndSettle();

    expect(find.text('ViroTeam v2'), findsOneWidget);
    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('ICÔNES PHOSPHOR'), findsOneWidget);
    expect(find.text('menu'), findsOneWidget);
    expect(find.text('ball'), findsOneWidget);
  });
}
