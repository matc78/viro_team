import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/services/event_service.dart';

class ClubEventsState {
  const ClubEventsState({
    required this.pending,
    required this.upcoming,
  });

  final List<ClubEvent> pending;
  final List<ClubEvent> upcoming;

  static const empty = ClubEventsState(pending: [], upcoming: []);
}

final clubProvider = FutureProvider.family<Club?, String>((ref, clubId) {
  return ref.read(clubServiceProvider).getClub(clubId);
});

final clubMemberProvider =
    StreamProvider.family<ClubMember?, String>((ref, clubId) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  return ref.read(eventServiceProvider).watchClubMember(
        clubId: clubId,
        uid: auth.uid,
      );
});

final clubEventsProvider =
    StreamProvider.family<ClubEventsState, String>((ref, clubId) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(ClubEventsState.empty);

  final authUid = auth.uid;
  final eventService = ref.read(eventServiceProvider);

  return eventService.watchClubMember(clubId: clubId, uid: authUid).asyncExpand(
    (member) {
      final audienceId = member?.memberId ?? authUid;
      return eventService
          .watchUpcomingEventsForClubMember(
            clubId: clubId,
            audienceId: audienceId,
            authUid: authUid,
          )
          .map((events) {
        final pending = <ClubEvent>[];
        final upcoming = <ClubEvent>[];

        for (final event in events) {
          if (!EventService.isWithinUpcomingPlanningWindow(event.date)) {
            continue;
          }

          upcoming.add(event);

          final invitedAsPlayer = event.isInvitedAsPlayer(
            authUid,
            clubAudienceId: audienceId,
          );
          final needsRsvp = invitedAsPlayer &&
              event.rsvpStatusForUser(
                authUid,
                clubAudienceId: audienceId,
              ) ==
                  RsvpStatus.none;

          if (needsRsvp) pending.add(event);
        }

        return ClubEventsState(
          pending: EventService.sortedByDate(pending),
          upcoming: EventService.sortedByDate(upcoming),
        );
      });
    },
  );
});

final clubAttendanceRateProvider =
    FutureProvider.family<double?, String>((ref, clubId) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;
  return ref.read(eventServiceProvider).computeAttendanceRate(
        clubId: clubId,
        authUid: auth.uid,
      );
});
