import 'package:cloud_firestore/cloud_firestore.dart';

enum PhaseType { group, knockout, consolation }

extension PhaseTypeExt on PhaseType {
  String get value {
    switch (this) {
      case PhaseType.group:
        return 'group';
      case PhaseType.knockout:
        return 'knockout';
      case PhaseType.consolation:
        return 'consolation';
    }
  }

  static PhaseType fromString(String? v) {
    switch (v) {
      case 'knockout':
        return PhaseType.knockout;
      case 'consolation':
        return PhaseType.consolation;
      default:
        return PhaseType.group;
    }
  }
}

class GroupStanding {
  final String teamId;
  int wins;
  int draws;
  int losses;
  int goalsFor;
  int goalsAgainst;

  GroupStanding({
    required this.teamId,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
  int get gamesPlayed => wins + draws + losses;
}

class TournamentPhase {
  final String id;
  final PhaseType type;
  final int index;
  final int nbGroups;
  final int nbQualifiedPerGroup;
  final List<String> participatingTeamIds;
  final List<String> qualifiedTeamIds;
  final int totalMatchCount;
  final int completedMatchCount;
  final bool isComplete;

  const TournamentPhase({
    required this.id,
    required this.type,
    required this.index,
    this.nbGroups = 1,
    this.nbQualifiedPerGroup = 2,
    this.participatingTeamIds = const [],
    this.qualifiedTeamIds = const [],
    this.totalMatchCount = 0,
    this.completedMatchCount = 0,
    this.isComplete = false,
  });

  factory TournamentPhase.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return TournamentPhase(
      id: doc.id,
      type: PhaseTypeExt.fromString(d['type'] as String?),
      index: (d['index'] as num?)?.toInt() ?? 0,
      nbGroups: (d['nbGroups'] as num?)?.toInt() ?? 1,
      nbQualifiedPerGroup:
          (d['nbQualifiedPerGroup'] as num?)?.toInt() ?? 2,
      participatingTeamIds:
          List<String>.from(d['participatingTeamIds'] as List? ?? []),
      qualifiedTeamIds:
          List<String>.from(d['qualifiedTeamIds'] as List? ?? []),
      totalMatchCount: (d['totalMatchCount'] as num?)?.toInt() ?? 0,
      completedMatchCount:
          (d['completedMatchCount'] as num?)?.toInt() ?? 0,
      isComplete: d['isComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.value,
        'index': index,
        'nbGroups': nbGroups,
        'nbQualifiedPerGroup': nbQualifiedPerGroup,
        'participatingTeamIds': participatingTeamIds,
        'qualifiedTeamIds': qualifiedTeamIds,
        'totalMatchCount': totalMatchCount,
        'completedMatchCount': completedMatchCount,
        'isComplete': isComplete,
      };

  /// Calcule les classements par groupe à partir des matchs de cette phase.
  /// Retourne une map groupIndex → liste de [GroupStanding] triée.
  Map<int, List<GroupStanding>> computeGroupStandings(
    List<dynamic> matches, // List<TournamentMatch> — évite import circulaire
  ) {
    final Map<int, Map<String, GroupStanding>> groups = {};

    for (final m in matches) {
      final groupIndex = m.groupIndex as int?;
      if (groupIndex == null) continue;
      final teamAId = m.teamAId as String?;
      final teamBId = m.teamBId as String?;
      if (teamAId == null || teamBId == null) continue;
      if (m.status.toString() != 'MatchStatus.completed') continue;

      groups.putIfAbsent(groupIndex, () => {});
      groups[groupIndex]!.putIfAbsent(
          teamAId, () => GroupStanding(teamId: teamAId));
      groups[groupIndex]!.putIfAbsent(
          teamBId, () => GroupStanding(teamId: teamBId));

      final sA = m.scoreA as int;
      final sB = m.scoreB as int;
      final standA = groups[groupIndex]![teamAId]!;
      final standB = groups[groupIndex]![teamBId]!;

      standA.goalsFor += sA;
      standA.goalsAgainst += sB;
      standB.goalsFor += sB;
      standB.goalsAgainst += sA;

      if (sA > sB) {
        standA.wins++;
        standB.losses++;
      } else if (sB > sA) {
        standB.wins++;
        standA.losses++;
      } else {
        standA.draws++;
        standB.draws++;
      }
    }

    final Map<int, List<GroupStanding>> result = {};
    for (final entry in groups.entries) {
      final standings = entry.value.values.toList()
        ..sort((a, b) {
          final ptsDiff = b.points.compareTo(a.points);
          if (ptsDiff != 0) return ptsDiff;
          final gdDiff = b.goalDiff.compareTo(a.goalDiff);
          if (gdDiff != 0) return gdDiff;
          return b.goalsFor.compareTo(a.goalsFor);
        });
      result[entry.key] = standings;
    }
    return result;
  }
}
