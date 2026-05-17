import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team_v2/models/club_event.dart';

ClubEvent _event({
  List<String> teamMemberIds = const ['playerA', 'playerB'],
  Map<String, String> rsvp = const {},
  Map<String, dynamic> legacyAttendance = const {},
}) {
  return ClubEvent(
    id: 'e1',
    clubId: 'c1',
    type: EventTypes.training,
    title: 'Entraînement',
    date: DateTime(2026, 5, 20),
    teamMemberIds: teamMemberIds,
    rsvp: rsvp,
    legacyAttendance: legacyAttendance,
  );
}

void main() {
  group('ClubEvent.rsvpStatusForUser', () {
    test('none quand aucune réponse', () {
      final event = _event();
      expect(
        event.rsvpStatusForUser(
          'coachUid',
          clubAudienceId: 'coachMemberId',
          memberAudienceKeys: {'coachMemberId', 'coachUid'},
        ),
        RsvpStatus.none,
      );
    });

    test('ne reprend pas le RSVP d\'un autre joueur', () {
      final event = _event(
        rsvp: {'playerB': 'yes'},
      );
      expect(
        event.rsvpStatusForUser(
          'coachUid',
          clubAudienceId: 'coachMemberId',
          memberAudienceKeys: {'coachMemberId', 'coachUid'},
        ),
        RsvpStatus.none,
      );
    });

    test('lit le RSVP sous la clé membre du club', () {
      final event = _event(
        rsvp: {'coachMemberId': 'yes'},
      );
      expect(
        event.rsvpStatusForUser(
          'coachUid',
          clubAudienceId: 'coachMemberId',
          memberAudienceKeys: {'coachMemberId', 'coachUid'},
        ),
        RsvpStatus.yes,
      );
    });

    test('lit la présence legacy v1 pour l\'utilisateur uniquement', () {
      final event = _event(
        legacyAttendance: {
          'coachMemberId': 'none',
          'playerB': 'present',
        },
      );
      expect(
        event.rsvpStatusForUser(
          'coachUid',
          clubAudienceId: 'coachMemberId',
        ),
        RsvpStatus.none,
      );
    });
  });
}
