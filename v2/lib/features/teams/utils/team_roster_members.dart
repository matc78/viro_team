import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';

/// Clé RSVP / `teamMemberIds` (aligné sur [EventService.resolveAudienceId]).
String rosterAudienceId(ClubMember member) {
  final accountUid = member.accountUid;
  if (accountUid != null && accountUid.isNotEmpty) {
    return member.memberId;
  }
  return member.effectiveUid;
}

/// Tous les identifiants possibles d'un membre sur un événement.
Set<String> eventAudienceKeys(ClubMember member) {
  final keys = ClubTeam.rosterIdVariants(member)
    ..add(rosterAudienceId(member));
  return keys;
}

/// `teamMemberIds` à la création d'un événement (clés RSVP canoniques).
List<String> audienceIdsForTeam(
  ClubTeam team,
  Map<String, ClubMember> membersByUid,
) {
  final ids = <String>{};
  for (final rosterUid in team.playerIds) {
    final member = clubMemberForTeamUid(membersByUid, rosterUid);
    ids.add(member != null ? rosterAudienceId(member) : rosterUid);
  }
  return ids.toList();
}

/// Index des membres par toutes les clés roster / RSVP.
Map<String, ClubMember> indexClubMembersByUid(List<ClubMember> members) {
  final map = <String, ClubMember>{};
  for (final m in members) {
    for (final key in eventAudienceKeys(m)) {
      map[key] = m;
    }
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
