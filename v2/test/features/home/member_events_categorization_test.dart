import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team_v2/features/home/providers/member_events_provider.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/services/event_service.dart';

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

ClubEvent _eventOnDay(
  DateTime day, {
  String id = 'e1',
  String clubId = 'c1',
  List<String> teamMemberIds = const ['authUid'],
}) {
  return ClubEvent(
    id: id,
    clubId: clubId,
    type: EventTypes.training,
    title: 'Entraînement',
    date: day,
    teamMemberIds: teamMemberIds,
  );
}

void main() {
  group('categorizeMemberEvents — fenêtre 14 jours', () {
    test('inclut un event à J+13 dans upcoming et pending', () {
      final today = _startOfToday();
      final j13 = today.add(const Duration(days: 13));
      final event = _eventOnDay(j13);

      final result = categorizeMemberEvents(
        [event],
        authUid: 'authUid',
        audienceByClub: {'c1': 'authUid'},
      );

      expect(result.upcoming, [event]);
      expect(result.pending, [event]);
    });

    test('exclut un event à J+14 de upcoming et pending', () {
      final today = _startOfToday();
      final j14 = today.add(const Duration(days: 14));
      final event = _eventOnDay(j14);

      final result = categorizeMemberEvents(
        [event],
        authUid: 'authUid',
        audienceByClub: {'c1': 'authUid'},
      );

      expect(result.upcoming, isEmpty);
      expect(result.pending, isEmpty);
    });

    test('EventService.isWithinUpcomingPlanningWindow — J+13 oui, J+14 non', () {
      final today = _startOfToday();
      expect(
        EventService.isWithinUpcomingPlanningWindow(
          today.add(const Duration(days: 13)),
        ),
        isTrue,
      );
      expect(
        EventService.isWithinUpcomingPlanningWindow(
          today.add(const Duration(days: 14)),
        ),
        isFalse,
      );
    });
  });
}
