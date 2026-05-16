import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

class EventService {
  EventService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _events(String clubId) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.eventsSubcollection);

  CollectionReference<Map<String, dynamic>> _announcements(String clubId) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.announcementsSubcollection);

  DocumentReference<Map<String, dynamic>> _memberRef(
    String clubId,
    String uid,
  ) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.membersSubcollection)
          .doc(uid);

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      _startOfDay(d).add(const Duration(days: 1));

  Stream<List<ClubEvent>> watchUpcomingEventsForClub({
    required String clubId,
    required String uid,
  }) {
    return _events(clubId)
        .where(FirestoreFields.teamMemberIds, arrayContains: uid)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfToday()),
        )
        .orderBy(FirestoreFields.date)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClubEvent.fromFirestore(clubId: clubId, doc: d))
            .where((e) => !e.canceled)
            .toList());
  }

  Stream<List<ClubEvent>> watchUpcomingEventsForClubs({
    required List<String> clubIds,
    required String uid,
  }) {
    if (clubIds.isEmpty) return Stream.value([]);

    final streams = clubIds
        .map(
          (clubId) => watchUpcomingEventsForClub(clubId: clubId, uid: uid),
        )
        .toList();

    return combineLatestListStreams(streams).map((events) {
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    });
  }

  Stream<List<ClubEvent>> watchPastEventsForClub({
    required String clubId,
    required String uid,
    required DateTime since,
  }) {
    return _events(clubId)
        .where(FirestoreFields.teamMemberIds, arrayContains: uid)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(since),
        )
        .where(
          FirestoreFields.date,
          isLessThan: Timestamp.fromDate(_startOfToday()),
        )
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClubEvent.fromFirestore(clubId: clubId, doc: d))
            .where((e) => !e.canceled)
            .toList());
  }

  /// Tous les événements d'un jour (vue coach/admin planning).
  Stream<List<ClubEvent>> watchClubEventsOnDay({
    required String clubId,
    required DateTime day,
  }) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);

    return _events(clubId)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          FirestoreFields.date,
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy(FirestoreFields.date)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ClubEvent.fromFirestore(clubId: clubId, doc: d))
              .where((e) => !e.canceled)
              .toList(),
        );
  }

  Future<DateTime?> getFirstEventDate(String clubId) async {
    final snap = await _events(clubId)
        .orderBy(FirestoreFields.date)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final ts = snap.docs.first.data()[FirestoreFields.date] as Timestamp?;
    if (ts == null) return null;
    return _startOfDay(ts.toDate());
  }

  /// Crée un ou plusieurs événements (récurrence hebdomadaire pour entraînements).
  Future<int> createEvents({
    required String clubId,
    required String creatorId,
    required String type,
    required String title,
    required DateTime startDate,
    required List<String> teamIds,
    required List<String> teamMemberIds,
    required bool allTeams,
    String? location,
    String? startTime,
    String? endTime,
    String? meetingTime,
    String? matchVenue,
    DateTime? recurrenceEndDate,
  }) async {
    final dates = _recurrenceDates(
      startDate: startDate,
      recurrenceEndDate: recurrenceEndDate,
    );
    final seriesId =
        dates.length > 1 ? _events(clubId).doc().id : null;

    final batch = _db.batch();
    for (final date in dates) {
      final ref = _events(clubId).doc();
      batch.set(ref, {
        FirestoreFields.type: type,
        FirestoreFields.title: title,
        FirestoreFields.location: location ?? '',
        FirestoreFields.teamIds: teamIds,
        FirestoreFields.allTeams: allTeams,
        FirestoreFields.date: Timestamp.fromDate(_startOfDay(date)),
        if (startTime != null) FirestoreFields.startTime: startTime,
        if (endTime != null) FirestoreFields.endTime: endTime,
        if (meetingTime != null) FirestoreFields.meetingTime: meetingTime,
        if (matchVenue != null) FirestoreFields.matchVenue: matchVenue,
        if (seriesId != null) FirestoreFields.seriesId: seriesId,
        FirestoreFields.teamMemberIds: teamMemberIds,
        FirestoreFields.rsvp: <String, String>{},
        FirestoreFields.attendance: <String, dynamic>{},
        FirestoreFields.creatorId: creatorId,
        FirestoreFields.canceled: false,
        FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return dates.length;
  }

  List<DateTime> _recurrenceDates({
    required DateTime startDate,
    DateTime? recurrenceEndDate,
  }) {
    final start = _startOfDay(startDate);
    if (recurrenceEndDate == null) return [start];

    final end = _startOfDay(recurrenceEndDate);
    if (end.isBefore(start)) return [start];

    final dates = <DateTime>[];
    var d = start;
    while (!d.isAfter(end) && dates.length < 52) {
      dates.add(d);
      d = d.add(const Duration(days: 7));
    }
    return dates.isEmpty ? [start] : dates;
  }

  Future<void> cancelEvent({
    required String clubId,
    required String eventId,
  }) async {
    await _events(clubId).doc(eventId).update({
      FirestoreFields.canceled: true,
    });
  }

  /// Annule tous les événements d'une série récurrente.
  Future<int> cancelEventSeries({
    required String clubId,
    required String seriesId,
  }) async {
    final snap = await _events(clubId)
        .where(FirestoreFields.seriesId, isEqualTo: seriesId)
        .get();
    if (snap.docs.isEmpty) return 0;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {FirestoreFields.canceled: true});
    }
    await batch.commit();
    return snap.docs.length;
  }

  Future<void> updateRsvp({
    required String clubId,
    required String eventId,
    required String uid,
    required RsvpStatus status,
  }) async {
    await _events(clubId).doc(eventId).update({
      '${FirestoreFields.rsvp}.$uid': status.firestoreValue,
    });
  }

  Stream<ClubMember?> watchClubMember({
    required String clubId,
    required String uid,
  }) {
    final accountIndexRef = _db
        .collection(ProjectConfig.clubsCollection)
        .doc(clubId)
        .collection(ProjectConfig.memberAccountsSubcollection)
        .doc(uid);

    return accountIndexRef.snapshots().asyncExpand((indexSnap) {
      String? linkedMemberId;
      if (indexSnap.exists) {
        final indexData = indexSnap.data();
        linkedMemberId =
            indexData?[FirestoreFields.linkedMemberId] as String?;
      }
      final targetId = linkedMemberId ?? uid;
      return _memberRef(clubId, targetId).snapshots().map((doc) {
        if (!doc.exists) return null;
        return ClubMember.fromFirestore(doc);
      });
    });
  }

  Stream<List<ClubAnnouncement>> watchRecentAnnouncements({
    required String clubId,
    int limit = 3,
  }) {
    return _announcements(clubId)
        .orderBy(FirestoreFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ClubAnnouncement.fromFirestore).toList(),
        );
  }

  /// Prochain événement à venir, ou le plus récent passé (aperçu club).
  Future<ClubEvent?> getHighlightEventForClub(String clubId) async {
    final today = _startOfToday();

    final upcoming = await _events(clubId)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(today),
        )
        .orderBy(FirestoreFields.date)
        .limit(3)
        .get();

    for (final doc in upcoming.docs) {
      final event = ClubEvent.fromFirestore(clubId: clubId, doc: doc);
      if (!event.canceled) return event;
    }

    final past = await _events(clubId)
        .where(
          FirestoreFields.date,
          isLessThan: Timestamp.fromDate(today),
        )
        .orderBy(FirestoreFields.date, descending: true)
        .limit(5)
        .get();

    for (final doc in past.docs) {
      final event = ClubEvent.fromFirestore(clubId: clubId, doc: doc);
      if (!event.canceled) return event;
    }

    return null;
  }

  /// Taux de présence sur les 30 derniers jours (events passés pointés).
  Future<double?> computeAttendanceRate({
    required String clubId,
    required String uid,
  }) async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final snap = await _events(clubId)
        .where(FirestoreFields.teamMemberIds, arrayContains: uid)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(since),
        )
        .where(
          FirestoreFields.date,
          isLessThan: Timestamp.fromDate(_startOfToday()),
        )
        .get();

    var total = 0;
    var present = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data[FirestoreFields.canceled] == true) continue;
      final attendance =
          data[FirestoreFields.attendance] as Map<String, dynamic>? ?? {};
      final entry = attendance[uid];
      if (entry == null) continue;
      total++;
      final status = entry is Map
          ? entry[FirestoreFields.status] as String?
          : entry.toString();
      if (status == 'present' || status == 'yes') present++;
    }

    if (total == 0) return null;
    return present / total * 100;
  }
}
