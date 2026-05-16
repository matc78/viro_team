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
  final bool canceled;
  final String? seriesId;

  bool get isRecurringSeries =>
      seriesId != null && seriesId!.isNotEmpty;

  RsvpStatus rsvpFor(String uid) =>
      RsvpStatus.fromString(rsvp[uid]);

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

  factory ClubEvent.fromFirestore({
    required String clubId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? {};
    final rsvpRaw = data[FirestoreFields.rsvp] as Map<String, dynamic>? ?? {};

    return ClubEvent(
      id: doc.id,
      clubId: clubId,
      type: data[FirestoreFields.type] as String? ?? EventTypes.other,
      title: data[FirestoreFields.title] as String? ?? '',
      date: (data[FirestoreFields.date] as Timestamp?)?.toDate() ??
          DateTime.now(),
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
      canceled: data[FirestoreFields.canceled] as bool? ?? false,
      seriesId: data[FirestoreFields.seriesId] as String?,
    );
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}
