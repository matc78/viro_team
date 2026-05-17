import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

/// Statut RSVP d'un membre sur un événement.
enum RsvpStatus {
  none,
  yes,
  no;

  static RsvpStatus fromString(String? value) => switch (value) {
        'yes' => RsvpStatus.yes,
        'no' => RsvpStatus.no,
        _ => RsvpStatus.none,
      };

  String get firestoreValue => switch (this) {
        RsvpStatus.yes => 'yes',
        RsvpStatus.no => 'no',
        RsvpStatus.none => 'none',
      };
}

/// Types d'événements club.
abstract final class EventTypes {
  static const String training = 'training';
  static const String match = 'match';
  static const String tournament = 'tournament';
  static const String other = 'other';
}

/// Lieu du match : domicile ou extérieur.
abstract final class MatchVenues {
  static const String home = 'home';
  static const String away = 'away';

  static const String homeLocationLabel = 'Domicile';
}

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.type,
    required this.title,
    required this.date,
    this.location,
    this.startTime,
    this.endTime,
    this.meetingTime,
    this.matchVenue,
    this.teamIds = const [],
    this.allTeams = false,
    this.teamMemberIds = const [],
    this.rsvp = const {},
    this.legacyAttendance = const {},
    this.canceled = false,
    this.seriesId,
  });

  final String id;
  final String clubId;
  final String type;
  final String title;
  final DateTime date;
  final String? location;
  final String? startTime;
  final String? endTime;
  final String? meetingTime;
  final String? matchVenue;
  final List<String> teamIds;
  final bool allTeams;
  final List<String> teamMemberIds;
  final Map<String, String> rsvp;
  /// Présences v1 (`attendance`) — utilisé si `rsvp` est vide.
  final Map<String, dynamic> legacyAttendance;
  final bool canceled;
  final String? seriesId;

  bool get isRecurringSeries =>
      seriesId != null && seriesId!.isNotEmpty;

  RsvpStatus rsvpFor(String uid) =>
      RsvpStatus.fromString(rsvp[uid]);

  /// Clé RSVP / audience réellement présente dans [teamMemberIds].
  String audienceKeyFor(String authUid, {String? clubAudienceId}) {
    final primary = clubAudienceId ?? authUid;
    if (teamMemberIds.contains(primary)) return primary;
    if (teamMemberIds.contains(authUid)) return authUid;
    return primary;
  }

  bool isInvitedAsPlayer(
    String authUid, {
    String? clubAudienceId,
    Set<String>? memberAudienceKeys,
  }) =>
      _audienceKeysForUser(
        authUid,
        clubAudienceId: clubAudienceId,
        memberAudienceKeys: memberAudienceKeys,
      ).any(teamMemberIds.contains);

  RsvpStatus rsvpStatusForUser(
    String authUid, {
    String? clubAudienceId,
    Set<String>? memberAudienceKeys,
  }) {
    final keys = _audienceKeysForUser(
      authUid,
      clubAudienceId: clubAudienceId,
      memberAudienceKeys: memberAudienceKeys,
    );
    for (final key in keys) {
      final value = rsvp[key];
      if (value != null) {
        return RsvpStatus.fromString(value);
      }
    }
    if (legacyAttendance.isNotEmpty) {
      for (final key in keys) {
        final entry = legacyAttendance[key];
        final mapped = _rsvpFromLegacyAttendance(entry);
        if (mapped != RsvpStatus.none) return mapped;
      }
    }
    return RsvpStatus.none;
  }

  /// Identifiants possibles de l'utilisateur sur l'événement (jamais d'autres joueurs).
  Set<String> _audienceKeysForUser(
    String authUid, {
    String? clubAudienceId,
    Set<String>? memberAudienceKeys,
  }) {
    final keys = <String>{
      audienceKeyFor(authUid, clubAudienceId: clubAudienceId),
      authUid,
      if (clubAudienceId != null && clubAudienceId.isNotEmpty) clubAudienceId,
      ...?memberAudienceKeys,
    };
    return keys.where((id) => id.isNotEmpty).toSet();
  }

  static RsvpStatus _rsvpFromLegacyAttendance(dynamic entry) {
    final status = entry is Map
        ? entry[FirestoreFields.status] as String?
        : entry?.toString();
    return switch (status) {
      'present' || 'yes' => RsvpStatus.yes,
      'absent' || 'no' => RsvpStatus.no,
      _ => RsvpStatus.none,
    };
  }

  static String normalizeEventType(String? raw) {
    final t = raw?.trim().toLowerCase() ?? '';
    return switch (t) {
      'training' || 'entraînement' || 'entrainement' => EventTypes.training,
      'match' => EventTypes.match,
      'tournament' || 'tournoi' => EventTypes.tournament,
      'other' || 'autre' || 'évènement' || 'événement' || 'evenement' =>
        EventTypes.other,
      _ => raw != null && raw.isNotEmpty ? raw : EventTypes.other,
    };
  }

  ({int yes, int no, int none}) get rsvpCounts => rsvpCountsExcluding({});

  /// Compteurs RSVP en excluant les coachs (et autres UIDs à ignorer).
  ({int yes, int no, int none}) rsvpCountsExcluding(Set<String> excludeUids) {
    var yes = 0;
    var no = 0;
    var none = 0;
    for (final uid in playerMemberIds(excludeUids)) {
      switch (rsvpFor(uid)) {
        case RsvpStatus.yes:
          yes++;
        case RsvpStatus.no:
          no++;
        case RsvpStatus.none:
          none++;
      }
    }
    return (yes: yes, no: no, none: none);
  }

  /// Joueurs convoqués sans les coachs d'équipe.
  List<String> playerMemberIds(Set<String> excludeCoachUids) =>
      teamMemberIds.where((id) => !excludeCoachUids.contains(id)).toList();

  bool get isUpcoming => !canceled && !date.isBefore(_startOfDay(DateTime.now()));

  /// Jour calendaire de l'événement (indépendant du fuseau à la lecture).
  static DateTime calendarDateFromFirestore(Map<String, dynamic> data) {
    final dateId = data[FirestoreFields.dateId] as String?;
    if (dateId != null && RegExp(r'^\d{8}$').hasMatch(dateId)) {
      return DateTime(
        int.parse(dateId.substring(0, 4)),
        int.parse(dateId.substring(4, 6)),
        int.parse(dateId.substring(6, 8)),
      );
    }

    final ts = data[FirestoreFields.date] as Timestamp?;
    if (ts == null) return _startOfDay(DateTime.now());

    final local = ts.toDate();
    // Legacy : minuit local (ex. Europe) → souvent J-1 à 22h en UTC à la lecture.
    if (local.hour >= 22) {
      final next = local.add(const Duration(days: 1));
      return DateTime(next.year, next.month, next.day);
    }
    return _startOfDay(local);
  }

  factory ClubEvent.fromFirestore({
    required String clubId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? {};
    final rsvpRaw = data[FirestoreFields.rsvp] as Map<String, dynamic>? ?? {};
    final attendanceRaw =
        data[FirestoreFields.attendance] as Map<String, dynamic>? ?? {};

    return ClubEvent(
      id: doc.id,
      clubId: clubId,
      type: normalizeEventType(data[FirestoreFields.type] as String?),
      title: data[FirestoreFields.title] as String? ?? '',
      date: calendarDateFromFirestore(data),
      location: data[FirestoreFields.location] as String?,
      startTime: data[FirestoreFields.startTime] as String?,
      endTime: data[FirestoreFields.endTime] as String?,
      meetingTime: data[FirestoreFields.meetingTime] as String?,
      matchVenue: data[FirestoreFields.matchVenue] as String?,
      teamIds: (data[FirestoreFields.teamIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      allTeams: data[FirestoreFields.allTeams] as bool? ?? false,
      teamMemberIds: (data[FirestoreFields.teamMemberIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      rsvp: rsvpRaw.map((k, v) => MapEntry(k, v.toString())),
      legacyAttendance: attendanceRaw,
      canceled: data[FirestoreFields.canceled] as bool? ?? false,
      seriesId: data[FirestoreFields.seriesId] as String?,
    );
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}
