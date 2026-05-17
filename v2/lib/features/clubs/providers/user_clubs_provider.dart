import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

typedef UserClubEntry = (Club club, ClubMembershipSummary membership);

class UserClubWithEvent {
  const UserClubWithEvent({
    required this.club,
    required this.membership,
    this.highlightEvent,
  });

  final Club club;
  final ClubMembershipSummary membership;
  final ClubEvent? highlightEvent;
}

final userClubsProvider = FutureProvider<List<UserClubEntry>>((ref) async {
  final user = ref.watch(viroUserProvider).value;
  if (user == null || !user.hasClubs) return [];

  final clubs = await ref.read(clubServiceProvider).getClubsForUser(user);
  final membershipById = {
    for (final m in user.clubMemberships) m.clubId: m,
  };

  return clubs.map((c) => (c, membershipById[c.id]!)).toList();
});

final userClubsWithEventsProvider =
    FutureProvider<List<UserClubWithEvent>>((ref) async {
  final entries = await ref.watch(userClubsProvider.future);
  final eventService = ref.read(eventServiceProvider);

  return Future.wait(
    entries.map((entry) async {
      final event =
          await eventService.getHighlightEventForClub(entry.$1.id);
      return UserClubWithEvent(
        club: entry.$1,
        membership: entry.$2,
        highlightEvent: event,
      );
    }),
  );
});
