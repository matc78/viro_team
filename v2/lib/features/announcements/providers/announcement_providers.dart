import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/announcements/utils/announcement_filter.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/home/providers/home_teams_provider.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

/// Annonce active sur la home avec contexte club.
class HomeAnnouncementItem {
  const HomeAnnouncementItem({
    required this.clubId,
    required this.clubName,
    required this.brandColorHex,
    required this.announcement,
  });

  final String clubId;
  final String clubName;
  final String? brandColorHex;
  final ClubAnnouncement announcement;
}

final clubAnnouncementsProvider =
    StreamProvider.family<List<ClubAnnouncement>, String>((ref, clubId) {
  return ref.read(announcementServiceProvider).watchAnnouncements(
        clubId: clubId,
      );
});

/// Annonces visibles pour le membre connecté (ciblage ; sans filtre dismiss).
final visibleClubAnnouncementsProvider =
    Provider.family<AsyncValue<List<ClubAnnouncement>>, String>((ref, clubId) {
  final announcementsAsync = ref.watch(clubAnnouncementsProvider(clubId));
  final memberAsync = ref.watch(clubMemberProvider(clubId));
  final teamsAsync = ref.watch(clubTeamsProvider(clubId));

  return announcementsAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (announcements) {
      final member = memberAsync.value;
      final teams = teamsAsync.value ?? [];
      final staff = AnnouncementFilter.isStaffRole(member?.role);
      final visible = AnnouncementFilter.forMemberAudience(
        announcements: announcements,
        member: member,
        clubTeams: teams,
        staffSeesAll: staff,
      );
      return AsyncData(visible);
    },
  );
});

/// Bandeau home : annonces non dismissées, tous clubs.
final homeActiveAnnouncementsProvider =
    StreamProvider<List<HomeAnnouncementItem>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  final clubs = ref.watch(userClubsProvider).value;
  final teamsByClub = ref.watch(homeClubTeamsProvider).value ?? {};

  if (auth == null || clubs == null || clubs.isEmpty) {
    return Stream.value([]);
  }

  final authUid = auth.uid;
  final announcementService = ref.read(announcementServiceProvider);
  final eventService = ref.read(eventServiceProvider);

  final streams = clubs.map<Stream<List<HomeAnnouncementItem>>>((entry) {
    final club = entry.$1;
    return eventService.watchClubMember(clubId: club.id, uid: authUid).asyncExpand(
      (member) {
        final dismissed =
            member?.dismissedAnnouncementIds.toSet() ?? <String>{};
        final staff = AnnouncementFilter.isStaffRole(member?.role);
        final teams = teamsByClub[club.id]?.values.toList() ?? [];

        return announcementService.watchAnnouncements(clubId: club.id).map(
          (announcements) {
            final active = AnnouncementFilter.activeForHome(
              announcements: announcements,
              member: member,
              clubTeams: teams,
              staffSeesAll: staff,
              dismissedIds: dismissed,
            );
            return active
                .map(
                  (a) => HomeAnnouncementItem(
                    clubId: club.id,
                    clubName: club.name,
                    brandColorHex: club.brandColorHex,
                    announcement: a,
                  ),
                )
                .toList();
          },
        );
      },
    );
  }).toList();

  return combineLatestListStreams<HomeAnnouncementItem>(streams).map((items) {
    final all = List<HomeAnnouncementItem>.from(items)
      ..sort(
        (a, b) =>
            b.announcement.createdAt.compareTo(a.announcement.createdAt),
      );
    return all.take(5).toList();
  });
});
