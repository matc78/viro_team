import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';

/// Libellés d'affichage planning (évite le doublon titre = nom d'équipe).
abstract final class PlanningEventDisplay {
  static String headline(ClubEvent event) {
    final typeLabel = eventTypeLabel(event.type);
    if (event.type == EventTypes.other) {
      return event.title.isNotEmpty ? event.title : typeLabel;
    }
    return typeLabel;
  }

  static String? teamLabel(
    ClubEvent event,
    Map<String, ClubTeam> teamsById,
  ) {
    if (event.allTeams) return 'Tout le club';
    if (event.teamIds.isEmpty) return null;
    final names = event.teamIds
        .map((id) => teamsById[id]?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  static String? subtitle(ClubEvent event, String? teamLabel) {
    if (teamLabel == null || teamLabel.isEmpty) return null;
    if (event.type == EventTypes.other &&
        event.title.isNotEmpty &&
        event.title != teamLabel) {
      return teamLabel;
    }
    if (event.type == EventTypes.training ||
        event.type == EventTypes.match) {
      return teamLabel;
    }
    return null;
  }

  static String? locationLine(ClubEvent event) {
    final loc = event.location?.trim();
    if (loc == null || loc.isEmpty) return null;
    return loc;
  }

  /// UIDs des coachs à exclure de la liste / des badges RSVP.
  /// L'utilisateur est coach d'une équipe liée à l'événement.
  static bool isCoachForEvent(
    ClubEvent event,
    String authUid,
    Map<String, ClubTeam> teamsById,
  ) {
    if (event.teamIds.isNotEmpty) {
      for (final teamId in event.teamIds) {
        if (teamsById[teamId]?.coachIds.contains(authUid) ?? false) {
          return true;
        }
      }
      return false;
    }
    for (final team in teamsById.values) {
      if (team.coachIds.contains(authUid)) return true;
    }
    return false;
  }

  /// Joueur convoqué → RSVP ; coach seul → badges de présence.
  static bool showCoachRsvpSummary(
    ClubEvent event,
    String authUid,
    Map<String, ClubTeam> teamsById,
  ) =>
      !event.isInvitedAsPlayer(authUid) &&
      isCoachForEvent(event, authUid, teamsById);

  /// Événement visible pour un joueur / coach membre (hors mode gestion).
  static bool isVisibleToMember({
    required ClubEvent event,
    required String authUid,
    required String audienceId,
    required Set<String> playerTeamIds,
    required Map<String, ClubTeam> teamsById,
  }) {
    if (event.allTeams) return true;
    if (event.isInvitedAsPlayer(authUid, clubAudienceId: audienceId)) {
      return true;
    }
    if (isCoachForEvent(event, authUid, teamsById)) return true;
    if (event.teamIds.any(playerTeamIds.contains)) return true;
    return false;
  }

  static Set<String> coachUidsToExclude(
    ClubEvent event,
    Map<String, ClubTeam> teamsById,
  ) {
    if (event.teamIds.isNotEmpty) {
      final coaches = <String>{};
      for (final teamId in event.teamIds) {
        coaches.addAll(teamsById[teamId]?.coachIds ?? []);
      }
      return coaches;
    }
    // Événements créés avant teamIds : coach repéré sur une équipe du club.
    final coaches = <String>{};
    for (final team in teamsById.values) {
      for (final coachId in team.coachIds) {
        if (event.teamMemberIds.contains(coachId)) coaches.add(coachId);
      }
    }
    return coaches;
  }

  static String scheduleLine(ClubEvent event) {
    final date = formatEventDate(event.date);
    final start = formatEventTime(event.startTime);
    final end = formatEventTime(event.endTime);
    final rdv = formatEventTime(event.meetingTime);

    if (event.type == EventTypes.match) {
      final parts = <String>[date];
      if (start.isNotEmpty) parts.add('Match $start');
      if (rdv.isNotEmpty) parts.add('RDV $rdv');
      return parts.join(' · ');
    }

    final parts = <String>[date];
    if (start.isNotEmpty) {
      parts.add(end.isNotEmpty ? '$start – $end' : start);
    }
    return parts.join(' · ');
  }
}
