import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

final myTeamsProvider =
    StreamProvider.family<List<ClubTeam>, String>((ref, clubId) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value([]);

  final member = ref.watch(clubMemberProvider(clubId)).value;
  final audienceId = member?.memberId ?? auth.uid;

  return ref.read(teamServiceProvider).watchUserTeams(
        clubId: clubId,
        uid: audienceId,
        alternateUid: auth.uid,
      );
});

final clubTeamsProvider =
    StreamProvider.family<List<ClubTeam>, String>((ref, clubId) {
  return ref.read(teamServiceProvider).watchClubTeams(clubId: clubId);
});

final pendingTeamMembersProvider =
    StreamProvider.family<List<PendingTeamMember>, String>((ref, clubId) {
  return ref.read(teamServiceProvider).watchPendingMembers(clubId);
});
