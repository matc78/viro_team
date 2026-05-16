import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/widgets/lists/club_list_tile.dart';

void main() {
  testWidgets('ClubListTile affiche le nom du club', (tester) async {
    const club = Club(
      id: 'c1',
      name: 'ASM Football',
      sport: 'Football',
      city: 'Paris',
    );
    const membership = ClubMembershipSummary(
      clubId: 'c1',
      role: MemberRoles.player,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubListTile(
            club: club,
            membership: membership,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('ASM Football'), findsOneWidget);
    expect(find.text('Joueur'), findsOneWidget);
  });
}
