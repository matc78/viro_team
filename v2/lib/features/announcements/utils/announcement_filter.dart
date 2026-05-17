import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';

/// Catégories dérivées des équipes du membre dans le club.
Set<String> memberCategoriesFromTeams({
  required List<ClubTeam> clubTeams,
  required List<String> memberTeamIds,
}) {
  final ids = memberTeamIds.toSet();
  final categories = <String>{};
  for (final team in clubTeams) {
    if (!ids.contains(team.id)) continue;
    final cat = team.category;
    if (cat != null && cat.isNotEmpty) {
      categories.add(cat);
    }
  }
  return categories;
}

abstract final class AnnouncementFilter {
  /// Filtre par ciblage destinataire (sans tenir compte du dismiss).
  static List<ClubAnnouncement> forMemberAudience({
    required List<ClubAnnouncement> announcements,
    required ClubMember? member,
    required List<ClubTeam> clubTeams,
    required bool staffSeesAll,
  }) {
    if (staffSeesAll) return announcements;
    if (member == null) return [];

    final categories = memberCategoriesFromTeams(
      clubTeams: clubTeams,
      memberTeamIds: member.teamIds,
    );

    return announcements
        .where(
          (a) => a.matchesMember(
            memberTeamIds: member.teamIds,
            memberCategories: categories,
          ),
        )
        .toList();
  }

  /// Annonces actives pour le bandeau home (ciblage + non dismissées).
  static List<ClubAnnouncement> activeForHome({
    required List<ClubAnnouncement> announcements,
    required ClubMember? member,
    required List<ClubTeam> clubTeams,
    required bool staffSeesAll,
    required Set<String> dismissedIds,
  }) {
    return forMemberAudience(
      announcements: announcements,
      member: member,
      clubTeams: clubTeams,
      staffSeesAll: staffSeesAll,
    ).where((a) => !dismissedIds.contains(a.id)).toList();
  }

  static bool isStaffRole(String? role) {
    if (role == null) return false;
    return role == MemberRoles.admin || role == MemberRoles.coach;
  }
}
