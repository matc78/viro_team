import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentType { ponctuel, championnat }

enum TournamentStatus { draft, active, completed, archived }

enum VictoryFormat { auTemps, auxPoints, auxSets }

enum TournamentStructure {
  championnatSeul,
  tournoiSeul,
  poulesVersTournoi,
  poulesInterVersTournoi,
}

extension TournamentTypeExt on TournamentType {
  String get value {
    switch (this) {
      case TournamentType.ponctuel:
        return 'ponctuel';
      case TournamentType.championnat:
        return 'championnat';
    }
  }

  static TournamentType fromString(String? v) {
    switch (v) {
      case 'championnat':
        return TournamentType.championnat;
      default:
        return TournamentType.ponctuel;
    }
  }
}

extension TournamentStatusExt on TournamentStatus {
  String get value {
    switch (this) {
      case TournamentStatus.draft:
        return 'draft';
      case TournamentStatus.active:
        return 'active';
      case TournamentStatus.completed:
        return 'completed';
      case TournamentStatus.archived:
        return 'archived';
    }
  }

  static TournamentStatus fromString(String? v) {
    switch (v) {
      case 'active':
        return TournamentStatus.active;
      case 'completed':
        return TournamentStatus.completed;
      case 'archived':
        return TournamentStatus.archived;
      default:
        return TournamentStatus.draft;
    }
  }
}

extension VictoryFormatExt on VictoryFormat {
  String get value {
    switch (this) {
      case VictoryFormat.auTemps:
        return 'auTemps';
      case VictoryFormat.auxPoints:
        return 'auxPoints';
      case VictoryFormat.auxSets:
        return 'auxSets';
    }
  }

  static VictoryFormat fromString(String? v) {
    switch (v) {
      case 'auxPoints':
        return VictoryFormat.auxPoints;
      case 'auxSets':
        return VictoryFormat.auxSets;
      default:
        return VictoryFormat.auTemps;
    }
  }
}

extension TournamentStructureExt on TournamentStructure {
  String get value {
    switch (this) {
      case TournamentStructure.championnatSeul:
        return 'championnatSeul';
      case TournamentStructure.tournoiSeul:
        return 'tournoiSeul';
      case TournamentStructure.poulesVersTournoi:
        return 'poulesVersTournoi';
      case TournamentStructure.poulesInterVersTournoi:
        return 'poulesInterVersTournoi';
    }
  }

  static TournamentStructure fromString(String? v) {
    switch (v) {
      case 'championnatSeul':
        return TournamentStructure.championnatSeul;
      case 'poulesVersTournoi':
        return TournamentStructure.poulesVersTournoi;
      case 'poulesInterVersTournoi':
        return TournamentStructure.poulesInterVersTournoi;
      default:
        return TournamentStructure.tournoiSeul;
    }
  }
}

class SwapRecord {
  final String playerId;
  final String fromTeamId;
  final String toTeamId;
  final DateTime swappedAt;
  final String? swappedBy;

  const SwapRecord({
    required this.playerId,
    required this.fromTeamId,
    required this.toTeamId,
    required this.swappedAt,
    this.swappedBy,
  });

  factory SwapRecord.fromMap(Map<String, dynamic> m) {
    return SwapRecord(
      playerId: m['playerId'] as String? ?? '',
      fromTeamId: m['fromTeamId'] as String? ?? '',
      toTeamId: m['toTeamId'] as String? ?? '',
      swappedAt: (m['swappedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      swappedBy: m['swappedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'fromTeamId': fromTeamId,
        'toTeamId': toTeamId,
        'swappedAt': Timestamp.fromDate(swappedAt),
        'swappedBy': swappedBy,
      };
}

class TournamentModel {
  final String id;
  final String name;
  final TournamentType type;
  final TournamentStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? linkedEventId;

  // Format des matchs
  final int playersPerTeam;
  final VictoryFormat victoryFormat;
  final int timeDurationMinutes;
  final int pointsTarget;
  final int setsCount;

  // Structure
  final TournamentStructure structure;
  final int nbGroups;
  final int nbQualifiedPerGroup;
  final bool hasIntermediatePhase;
  final int nbIntermediateGroups;
  final int nbQualifiedFromIntermediate;
  final bool hasConsolationBracket;

  // Constitution équipes
  final double driftFactor;
  final bool isManualDraft;

  // Suivi
  final int currentPhaseIndex;
  final String generationStatus; // 'pending' | 'complete' | ''
  final List<SwapRecord> swapHistory;

  final DateTime createdAt;
  final String createdBy;

  const TournamentModel({
    required this.id,
    required this.name,
    this.type = TournamentType.ponctuel,
    this.status = TournamentStatus.draft,
    required this.startDate,
    this.endDate,
    this.linkedEventId,
    this.playersPerTeam = 1,
    this.victoryFormat = VictoryFormat.auTemps,
    this.timeDurationMinutes = 20,
    this.pointsTarget = 21,
    this.setsCount = 3,
    this.structure = TournamentStructure.tournoiSeul,
    this.nbGroups = 2,
    this.nbQualifiedPerGroup = 2,
    this.hasIntermediatePhase = false,
    this.nbIntermediateGroups = 2,
    this.nbQualifiedFromIntermediate = 2,
    this.hasConsolationBracket = false,
    this.driftFactor = 0.0,
    this.isManualDraft = false,
    this.currentPhaseIndex = 0,
    this.generationStatus = '',
    this.swapHistory = const [],
    required this.createdAt,
    required this.createdBy,
  });

  factory TournamentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawSwaps =
        (d['swapHistory'] as List?)?.whereType<Map>().toList() ?? [];
    return TournamentModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      type: TournamentTypeExt.fromString(d['type'] as String?),
      status: TournamentStatusExt.fromString(d['status'] as String?),
      startDate:
          (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      linkedEventId: d['linkedEventId'] as String?,
      playersPerTeam: (d['playersPerTeam'] as num?)?.toInt() ?? 1,
      victoryFormat:
          VictoryFormatExt.fromString(d['victoryFormat'] as String?),
      timeDurationMinutes:
          (d['timeDurationMinutes'] as num?)?.toInt() ?? 20,
      pointsTarget: (d['pointsTarget'] as num?)?.toInt() ?? 21,
      setsCount: (d['setsCount'] as num?)?.toInt() ?? 3,
      structure:
          TournamentStructureExt.fromString(d['structure'] as String?),
      nbGroups: (d['nbGroups'] as num?)?.toInt() ?? 2,
      nbQualifiedPerGroup:
          (d['nbQualifiedPerGroup'] as num?)?.toInt() ?? 2,
      hasIntermediatePhase:
          d['hasIntermediatePhase'] as bool? ?? false,
      nbIntermediateGroups:
          (d['nbIntermediateGroups'] as num?)?.toInt() ?? 2,
      nbQualifiedFromIntermediate:
          (d['nbQualifiedFromIntermediate'] as num?)?.toInt() ?? 2,
      hasConsolationBracket:
          d['hasConsolationBracket'] as bool? ?? false,
      driftFactor: (d['driftFactor'] as num?)?.toDouble() ?? 0.0,
      isManualDraft: d['isManualDraft'] as bool? ?? false,
      currentPhaseIndex:
          (d['currentPhaseIndex'] as num?)?.toInt() ?? 0,
      generationStatus: d['generationStatus'] as String? ?? '',
      swapHistory: rawSwaps
          .map((e) => SwapRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'type': type.value,
        'status': status.value,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'linkedEventId': linkedEventId,
        'playersPerTeam': playersPerTeam,
        'victoryFormat': victoryFormat.value,
        'timeDurationMinutes': timeDurationMinutes,
        'pointsTarget': pointsTarget,
        'setsCount': setsCount,
        'structure': structure.value,
        'nbGroups': nbGroups,
        'nbQualifiedPerGroup': nbQualifiedPerGroup,
        'hasIntermediatePhase': hasIntermediatePhase,
        'nbIntermediateGroups': nbIntermediateGroups,
        'nbQualifiedFromIntermediate': nbQualifiedFromIntermediate,
        'hasConsolationBracket': hasConsolationBracket,
        'driftFactor': driftFactor,
        'isManualDraft': isManualDraft,
        'currentPhaseIndex': currentPhaseIndex,
        'generationStatus': generationStatus,
        'swapHistory': swapHistory.map((s) => s.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };

  TournamentModel copyWith({
    String? id,
    String? name,
    TournamentType? type,
    TournamentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? linkedEventId,
    int? playersPerTeam,
    VictoryFormat? victoryFormat,
    int? timeDurationMinutes,
    int? pointsTarget,
    int? setsCount,
    TournamentStructure? structure,
    int? nbGroups,
    int? nbQualifiedPerGroup,
    bool? hasIntermediatePhase,
    int? nbIntermediateGroups,
    int? nbQualifiedFromIntermediate,
    bool? hasConsolationBracket,
    double? driftFactor,
    bool? isManualDraft,
    int? currentPhaseIndex,
    String? generationStatus,
    List<SwapRecord>? swapHistory,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      linkedEventId: linkedEventId ?? this.linkedEventId,
      playersPerTeam: playersPerTeam ?? this.playersPerTeam,
      victoryFormat: victoryFormat ?? this.victoryFormat,
      timeDurationMinutes: timeDurationMinutes ?? this.timeDurationMinutes,
      pointsTarget: pointsTarget ?? this.pointsTarget,
      setsCount: setsCount ?? this.setsCount,
      structure: structure ?? this.structure,
      nbGroups: nbGroups ?? this.nbGroups,
      nbQualifiedPerGroup: nbQualifiedPerGroup ?? this.nbQualifiedPerGroup,
      hasIntermediatePhase:
          hasIntermediatePhase ?? this.hasIntermediatePhase,
      nbIntermediateGroups:
          nbIntermediateGroups ?? this.nbIntermediateGroups,
      nbQualifiedFromIntermediate:
          nbQualifiedFromIntermediate ?? this.nbQualifiedFromIntermediate,
      hasConsolationBracket:
          hasConsolationBracket ?? this.hasConsolationBracket,
      driftFactor: driftFactor ?? this.driftFactor,
      isManualDraft: isManualDraft ?? this.isManualDraft,
      currentPhaseIndex: currentPhaseIndex ?? this.currentPhaseIndex,
      generationStatus: generationStatus ?? this.generationStatus,
      swapHistory: swapHistory ?? this.swapHistory,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
