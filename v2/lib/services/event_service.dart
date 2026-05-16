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
