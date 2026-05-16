import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

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

  return ref.read(eventServiceProvider).watchUpcomingEventsForClub(
        clubId: clubId,
        uid: auth.uid,
      ).map((events) {
    final pending = <ClubEvent>[];
    final upcoming = <ClubEvent>[];

    for (final event in events) {
      if (event.rsvpFor(auth.uid) == RsvpStatus.none) {
        pending.add(event);
      } else {
        upcoming.add(event);
      }
    }

    return ClubEventsState(pending: pending, upcoming: upcoming);
  });
});

final clubAnnouncementsProvider =
    StreamProvider.family<List<ClubAnnouncement>, String>((ref, clubId) {
  return ref.read(eventServiceProvider).watchRecentAnnouncements(
        clubId: clubId,
      );
});

final clubAttendanceRateProvider =
    FutureProvider.family<double?, String>((ref, clubId) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;
  return ref.read(eventServiceProvider).computeAttendanceRate(
        clubId: clubId,
        uid: auth.uid,
      );
});
