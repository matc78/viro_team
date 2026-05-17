import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/services/event_service.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

class MemberEventsState {
  const MemberEventsState({
    required this.pending,
    required this.upcoming,
  });

  final List<ClubEvent> pending;
  final List<ClubEvent> upcoming;

  static const empty = MemberEventsState(pending: [], upcoming: []);
}

/// Planning global du membre — tous les clubs, temps réel.
final memberEventsProvider = StreamProvider<MemberEventsState>((ref) {
  final auth = ref.watch(authStateProvider).value;
  final user = ref.watch(viroUserProvider).value;

  if (auth == null || user == null || !user.hasClubs) {
    return Stream.value(MemberEventsState.empty);
  }

  final clubIds = user.clubMemberships.map((m) => m.clubId).toList();
  final authUid = auth.uid;
  final eventService = ref.read(eventServiceProvider);

  final audienceStreams = clubIds.map((clubId) {
    return eventService.watchClubMember(clubId: clubId, uid: authUid).map(
      (member) => [MapEntry(clubId, member?.memberId ?? authUid)],
    );
  }).toList();

  return combineLatestListStreams(audienceStreams).asyncExpand((entries) {
    final audienceByClub = Map<String, String>.fromEntries(entries);

    return eventService
        .watchUpcomingEventsForUser(clubIds: clubIds, authUid: authUid)
        .map((events) => _categorizeMemberEvents(
              events,
              authUid: authUid,
              audienceByClub: audienceByClub,
            ));
  });
});

MemberEventsState _categorizeMemberEvents(
  List<ClubEvent> events, {
  required String authUid,
  required Map<String, String> audienceByClub,
}) {
  final pending = <ClubEvent>[];
  final upcoming = <ClubEvent>[];

  for (final event in events) {
    if (!EventService.isWithinUpcomingPlanningWindow(event.date)) continue;

    upcoming.add(event);

    final audienceId = audienceByClub[event.clubId] ?? authUid;
    final audienceKeys = {authUid, audienceId};
    final invitedAsPlayer = event.isInvitedAsPlayer(
      authUid,
      clubAudienceId: audienceId,
      memberAudienceKeys: audienceKeys,
    );
    final needsRsvp = invitedAsPlayer &&
        event.rsvpStatusForUser(
          authUid,
          clubAudienceId: audienceId,
          memberAudienceKeys: audienceKeys,
        ) ==
            RsvpStatus.none;

    if (needsRsvp) pending.add(event);
  }

  return MemberEventsState(
    pending: EventService.sortedByDate(pending),
    upcoming: EventService.sortedByDate(upcoming),
  );
}

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
