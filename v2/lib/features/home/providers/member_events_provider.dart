import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

class MemberEventsState {
  const MemberEventsState({
    required this.pending,
    required this.upcoming,
  });

  final List<ClubEvent> pending;
  final List<ClubEvent> upcoming;

  static const empty = MemberEventsState(pending: [], upcoming: []);
}

final memberEventsProvider = StreamProvider<MemberEventsState>((ref) {
  final auth = ref.watch(authStateProvider).value;
  final user = ref.watch(viroUserProvider).value;

  if (auth == null || user == null || !user.hasClubs) {
    return Stream.value(MemberEventsState.empty);
  }

  final clubIds = user.clubMemberships.map((m) => m.clubId).toList();
  final uid = auth.uid;

  return ref.read(eventServiceProvider).watchUpcomingEventsForClubs(
        clubIds: clubIds,
        uid: uid,
      ).map((events) {
    final pending = <ClubEvent>[];
    final upcoming = <ClubEvent>[];

    for (final event in events) {
      if (event.rsvpFor(uid) == RsvpStatus.none) {
        pending.add(event);
      } else {
        upcoming.add(event);
      }
    }

    return MemberEventsState(pending: pending, upcoming: upcoming);
  });
});

/// Nombre d'events sans réponse par club (badges barre clubs).
final pendingCountByClubProvider = Provider<Map<String, int>>((ref) {
  final events = ref.watch(memberEventsProvider).value;
  final auth = ref.watch(authStateProvider).value;
  if (events == null || auth == null) return {};

  final counts = <String, int>{};
  for (final event in events.pending) {
    counts[event.clubId] = (counts[event.clubId] ?? 0) + 1;
  }
  return counts;
});
