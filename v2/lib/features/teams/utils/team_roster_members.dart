import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';

/// Index des membres du club par [ClubMember.effectiveUid] et [memberId].
Map<String, ClubMember> indexClubMembersByUid(List<ClubMember> members) {
  final map = <String, ClubMember>{};
  for (final m in members) {
    if (m.effectiveUid.isNotEmpty) {
      map[m.effectiveUid] = m;
    }
    map[m.memberId] = m;
  }
  return map;
}

ClubMember? clubMemberForTeamUid(
  Map<String, ClubMember> byUid,
  String uid,
) {
  return byUid[uid];
}

ClubMember pendingAsClubMember(PendingTeamMember pending) {
  return ClubMember.fromPendingRoster(
    pendingId: pending.id,
    firstName: pending.firstName,
    lastName: pending.lastName,
  );
}
