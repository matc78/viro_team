import 'package:cloud_firestore/cloud_firestore.dart';
import 'tournament_phase.dart';

enum MatchStatus { upcoming, inProgress, completed }

extension MatchStatusExt on MatchStatus {
  String get value {
    switch (this) {
      case MatchStatus.upcoming:
        return 'upcoming';
      case MatchStatus.inProgress:
        return 'inProgress';
      case MatchStatus.completed:
        return 'completed';
    }
  }

  static MatchStatus fromString(String? v) {
    switch (v) {
      case 'inProgress':
        return MatchStatus.inProgress;
      case 'completed':
        return MatchStatus.completed;
      default:
        return MatchStatus.upcoming;
    }
  }
}

class TournamentMatch {
  final String id;
  final String phaseId;
  final PhaseType phaseType;
  final int phaseIndex;
  final int? groupIndex;
  final int? round;
  final int? bracketSlot;
  final String? teamAId;
  final String? teamBId;
  final int scoreA;
  final int scoreB;
  final MatchStatus status;
  final DateTime? scheduledAt;

  const TournamentMatch({
    required this.id,
    required this.phaseId,
    required this.phaseType,
    required this.phaseIndex,
    this.groupIndex,
    this.round,
    this.bracketSlot,
    this.teamAId,
    this.teamBId,
    this.scoreA = 0,
    this.scoreB = 0,
    this.status = MatchStatus.upcoming,
    this.scheduledAt,
  });

  /// Retourne l'id du gagnant, null en cas de match nul ou non terminé.
  String? get winnerId {
    if (status != MatchStatus.completed) return null;
    if (teamAId == null) return teamBId;
    if (teamBId == null) return teamAId;
    if (scoreA > scoreB) return teamAId;
    if (scoreB > scoreA) return teamBId;
    return null;
  }

  /// Retourne l'id du perdant, null en cas de match nul ou non terminé.
  String? get loserId {
    if (status != MatchStatus.completed) return null;
    if (teamAId == null) return null;
    if (teamBId == null) return null;
    if (scoreA > scoreB) return teamBId;
    if (scoreB > scoreA) return teamAId;
    return null;
  }

  factory TournamentMatch.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return TournamentMatch(
      id: doc.id,
      phaseId: d['phaseId'] as String? ?? '',
      phaseType: PhaseTypeExt.fromString(d['phaseType'] as String?),
      phaseIndex: (d['phaseIndex'] as num?)?.toInt() ?? 0,
      groupIndex: (d['groupIndex'] as num?)?.toInt(),
      round: (d['round'] as num?)?.toInt(),
      bracketSlot: (d['bracketSlot'] as num?)?.toInt(),
      teamAId: d['teamAId'] as String?,
      teamBId: d['teamBId'] as String?,
      scoreA: (d['scoreA'] as num?)?.toInt() ?? 0,
      scoreB: (d['scoreB'] as num?)?.toInt() ?? 0,
      status: MatchStatusExt.fromString(d['status'] as String?),
      scheduledAt: (d['scheduledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'phaseId': phaseId,
        'phaseType': phaseType.value,
        'phaseIndex': phaseIndex,
        'groupIndex': groupIndex,
        'round': round,
        'bracketSlot': bracketSlot,
        'teamAId': teamAId,
        'teamBId': teamBId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'status': status.value,
        'scheduledAt':
            scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      };

  TournamentMatch copyWith({
    String? id,
    String? phaseId,
    PhaseType? phaseType,
    int? phaseIndex,
    int? groupIndex,
    int? round,
    int? bracketSlot,
    String? teamAId,
    String? teamBId,
    int? scoreA,
    int? scoreB,
    MatchStatus? status,
    DateTime? scheduledAt,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      phaseId: phaseId ?? this.phaseId,
      phaseType: phaseType ?? this.phaseType,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      groupIndex: groupIndex ?? this.groupIndex,
      round: round ?? this.round,
      bracketSlot: bracketSlot ?? this.bracketSlot,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}
