import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { present, late, absent }

extension SessionStatusLabel on SessionStatus {
  String get label {
    switch (this) {
      case SessionStatus.present:
        return 'Présent';
      case SessionStatus.late:
        return 'Retard';
      case SessionStatus.absent:
        return 'Absent';
    }
  }

  static SessionStatus fromString(String? value) {
    switch (value) {
      case 'present':
        return SessionStatus.present;
      case 'late':
        return SessionStatus.late;
      default:
        return SessionStatus.absent;
    }
  }
}

class PlayerSessionAttendance {
  final String playerId;
  final SessionStatus status;
  final int? lateMinutes;
  final String markedBy;
  final DateTime? markedAt;

  const PlayerSessionAttendance({
    required this.playerId,
    required this.status,
    this.lateMinutes,
    required this.markedBy,
    this.markedAt,
  });

  factory PlayerSessionAttendance.fromMap(
    String playerId,
    Map<String, dynamic> data,
  ) {
    return PlayerSessionAttendance(
      playerId: playerId,
      status: SessionStatusLabel.fromString(data['status'] as String?),
      lateMinutes: data['lateMinutes'] as int?,
      markedBy: data['markedBy'] as String? ?? '',
      markedAt: data['markedAt'] is Timestamp
          ? (data['markedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status.name,
        if (lateMinutes != null) 'lateMinutes': lateMinutes,
        'markedBy': markedBy,
        'markedAt': FieldValue.serverTimestamp(),
      };
}

/// Calcule la saison sportive à partir d'une date (ex: 2025-2026).
/// La saison commence en juillet (mois 7).
String computeSeason(DateTime date) {
  final startYear = date.month >= 7 ? date.year : date.year - 1;
  return '$startYear-${startYear + 1}';
}
