import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/utils/player_club_stats_helpers.dart';
import 'package:viro_team/utils/rsvp_stats_math.dart';

void main() {
  test('delaySecondsSinceReference clamps negative', () {
    final ref = DateTime(2026, 1, 1, 12);
    final now = DateTime(2026, 1, 1, 11);
    expect(delaySecondsSinceReference(ref, now), 0);
  });

  test('playerSeasonStatsForClub parses nested maps', () {
    final uid = 'club1';
    final user = {
      'trainingStats': {
        '${uid}_2025-2026': {
          'total': 10,
          'present': 7,
          'late': 2,
          'absent': 1,
        },
      },
      'rsvpTrainingStats': {
        '${uid}_2025-2026': {
          'answered': 8,
          'present': 5,
          'absent': 3,
          'delaySumSec': 8000,
          'delayCount': 4,
        },
      },
      'rsvpMatchStats': {
        '${uid}_2025-2026': {
          'answered': 2,
          'present': 1,
          'absent': 1,
          'delaySumSec': 0,
          'delayCount': 0,
        },
      },
    };
    final s = playerSeasonStatsForClub(
      user,
      uid,
      DateTime(2025, 10, 1),
    );
    expect(s.trainingTotal, 10);
    expect(s.trainingRealRate, closeTo(0.9, 0.001));
    expect(s.rsvpAnswered, 8);
    expect(s.avgRsvpDelaySec, 2000);
  });
}
