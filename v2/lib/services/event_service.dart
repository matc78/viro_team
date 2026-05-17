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

  CollectionReference<Map<String, dynamic>> _teams(String clubId) => _db
      .collection(ProjectConfig.clubsCollection)
      .doc(clubId)
      .collection(ProjectConfig.teamsSubcollection);

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

  /// Même jour calendaire (fuseau local).
  static bool sameCalendarDay(DateTime a, DateTime b) {
    final da = _startOfDay(a);
    final db = _startOfDay(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  static String dateIdFor(DateTime day) {
    final d = _startOfDay(day);
    final m = d.month.toString().padLeft(2, '0');
    final dayStr = d.day.toString().padLeft(2, '0');
    return '${d.year}$m$dayStr';
  }

  /// Borne basse Firestore : inclut les événements « minuit local » stockés en UTC.
  static Timestamp get _upcomingQueryLowerBound => Timestamp.fromDate(
        _startOfToday().subtract(const Duration(days: 1)),
      );

  static List<ClubEvent> _filterUpcomingWindow(Iterable<ClubEvent> events) =>
      events
          .where((e) => !e.canceled && isWithinUpcomingPlanningWindow(e.date))
          .toList();

  /// Fenêtre « Planning à venir » : 14 jours calendaires à partir d'aujourd'hui.
  static const int upcomingPlanningHorizonDays = 14;

  static bool isWithinUpcomingPlanningWindow(DateTime eventDate) {
    final start = _startOfToday();
    final endExclusive =
        start.add(const Duration(days: upcomingPlanningHorizonDays));
    final day = _startOfDay(eventDate);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  Stream<List<ClubEvent>> watchUpcomingEventsForClub({
    required String clubId,
    required String uid,
    String? alternateUid,
  }) {
    final lowerBound = _upcomingQueryLowerBound;
    final alt = alternateUid;
    final streams = <Stream<List<ClubEvent>>>[
      _watchUpcomingEventsForClubAudience(
        clubId: clubId,
        uid: uid,
        lowerBound: lowerBound,
      ),
      if (alt != null && alt.isNotEmpty && alt != uid)
        _watchUpcomingEventsForClubAudience(
          clubId: clubId,
          uid: alt,
          lowerBound: lowerBound,
        ),
    ];

    return combineLatestListStreams(streams).map(_dedupeEvents);
  }

  Stream<List<ClubEvent>> _watchUpcomingEventsForClubAudience({
    required String clubId,
    required String uid,
    required Timestamp lowerBound,
  }) {
    return _events(clubId)
        .where(FirestoreFields.teamMemberIds, arrayContains: uid)
        .where(FirestoreFields.date, isGreaterThanOrEqualTo: lowerBound)
        .orderBy(FirestoreFields.date)
        .snapshots()
        .map(
          (snap) => sortedByDate(
            _filterUpcomingWindow(
              snap.docs.map(
                (d) => ClubEvent.fromFirestore(clubId: clubId, doc: d),
              ),
            ),
          ),
        );
  }

  /// Événements des équipes où [authUid] est coach (hors convocation joueur).
  Stream<List<ClubEvent>> watchUpcomingEventsAsCoach({
    required String clubId,
    required String authUid,
  }) {
    return _teams(clubId)
        .where(FirestoreFields.coachIds, arrayContains: authUid)
        .snapshots()
        .asyncExpand((teamsSnap) {
      final teamIds = teamsSnap.docs.map((d) => d.id).toList();
      if (teamIds.isEmpty) return Stream.value(<ClubEvent>[]);

      final lowerBound = _upcomingQueryLowerBound;
      final streams = teamIds.map((teamId) {
        return _events(clubId)
            .where(FirestoreFields.teamIds, arrayContains: teamId)
            .where(
              FirestoreFields.date,
              isGreaterThanOrEqualTo: lowerBound,
            )
            .orderBy(FirestoreFields.date)
            .snapshots()
            .map(
              (snap) => sortedByDate(
                _filterUpcomingWindow(
                  snap.docs.map(
                    (d) => ClubEvent.fromFirestore(clubId: clubId, doc: d),
                  ),
                ),
              ),
            );
      }).toList();

      return combineLatestListStreams(streams).map(_dedupeEvents);
    });
  }

  /// Joueur convoqué + entraînements des équipes coachées.
  Stream<List<ClubEvent>> watchUpcomingEventsForClubMember({
    required String clubId,
    required String audienceId,
    required String authUid,
  }) {
    final asPlayer = watchUpcomingEventsForClub(
      clubId: clubId,
      uid: audienceId,
      alternateUid: authUid,
    );
    final asCoach =
        watchUpcomingEventsAsCoach(clubId: clubId, authUid: authUid);
    final asTeamPlayer = watchUpcomingEventsForPlayerTeams(
      clubId: clubId,
      audienceId: audienceId,
      authUid: authUid,
    );

    return combineLatestListStreams([asPlayer, asCoach, asTeamPlayer])
        .map(_dedupeEvents);
  }

  /// Événements des équipes du joueur (compat. v1 : `teamIds` / `teamName`).
  Stream<List<ClubEvent>> watchUpcomingEventsForPlayerTeams({
    required String clubId,
    required String audienceId,
    required String authUid,
  }) {
    return _teams(clubId).snapshots().asyncExpand((teamsSnap) {
      final playerTeamIds = <String>[];
      final playerTeamNames = <String>{};

      for (final doc in teamsSnap.docs) {
        final data = doc.data();
        final playerIds =
            (data[FirestoreFields.playerIds] as List<dynamic>?)
                ?.whereType<String>() ??
            [];
        if (playerIds.contains(audienceId) || playerIds.contains(authUid)) {
          playerTeamIds.add(doc.id);
          final name = data[FirestoreFields.name] as String?;
          if (name != null && name.isNotEmpty) playerTeamNames.add(name);
        }
      }

      if (playerTeamIds.isEmpty) return Stream.value(<ClubEvent>[]);

      final lowerBound = _upcomingQueryLowerBound;
      final streams = <Stream<List<ClubEvent>>>[];

      for (final teamId in playerTeamIds) {
        streams.add(
          _events(clubId)
              .where(FirestoreFields.teamIds, arrayContains: teamId)
              .where(FirestoreFields.date, isGreaterThanOrEqualTo: lowerBound)
              .orderBy(FirestoreFields.date)
              .snapshots()
              .map(
                (snap) => sortedByDate(
                  _filterUpcomingWindow(
                    snap.docs.map(
                      (d) => ClubEvent.fromFirestore(clubId: clubId, doc: d),
                    ),
                  ),
                ),
              ),
        );
      }

      // Événements v1 sans `teamIds` mais avec `teamName`.
      if (playerTeamNames.isNotEmpty) {
        streams.add(
          _events(clubId)
              .where(FirestoreFields.date, isGreaterThanOrEqualTo: lowerBound)
              .orderBy(FirestoreFields.date)
              .snapshots()
              .map(
                (snap) => sortedByDate(
                  _filterUpcomingWindow(
                    snap.docs.where((doc) {
                      final data = doc.data();
                      final teamIds =
                          (data[FirestoreFields.teamIds] as List<dynamic>?)
                              ?.whereType<String>() ??
                          [];
                      if (teamIds.isNotEmpty) return false;
                      final legacyName = data['teamName'] as String?;
                      if (legacyName == null ||
                          !playerTeamNames.contains(legacyName)) {
                        return false;
                      }
                      return true;
                    }).map(
                      (d) => ClubEvent.fromFirestore(clubId: clubId, doc: d),
                    ),
                  ),
                ),
              ),
        );
      }

      return combineLatestListStreams(streams).map(_dedupeEvents);
    });
  }

  static int compareByDate(ClubEvent a, ClubEvent b) =>
      a.date.compareTo(b.date);

  static List<ClubEvent> sortedByDate(Iterable<ClubEvent> events) {
    final list = events.toList();
    list.sort(compareByDate);
    return list;
  }

  static List<ClubEvent> _dedupeEvents(List<ClubEvent> events) {
    final byKey = <String, ClubEvent>{};
    for (final event in events) {
      byKey['${event.clubId}_${event.id}'] = event;
    }
    return sortedByDate(byKey.values);
  }

  /// ID présent dans `teamMemberIds` / `playerIds` (doc `members/{memberId}`).
  static String _rosterAudienceId(ClubMember member, String authUid) =>
      member.memberId;

  /// Identifiant utilisé dans `teamMemberIds` / `rsvp` pour un membre du club.
  Future<String> resolveAudienceId({
    required String clubId,
    required String authUid,
  }) async {
    final indexSnap = await _db
        .collection(ProjectConfig.clubsCollection)
        .doc(clubId)
        .collection(ProjectConfig.memberAccountsSubcollection)
        .doc(authUid)
        .get();

    if (indexSnap.exists) {
      final linked =
          indexSnap.data()?[FirestoreFields.linkedMemberId] as String?;
      if (linked != null && linked.isNotEmpty) return linked;
    }

    final memberSnap = await _memberRef(clubId, authUid).get();
    if (memberSnap.exists) {
      final accountUid =
          memberSnap.data()?[FirestoreFields.accountUid] as String?;
      if (accountUid != null && accountUid.isNotEmpty) return authUid;
      return memberSnap.id;
    }

    return authUid;
  }

  /// Événements à venir pour un membre, tous ses clubs (spec home globale).
  Stream<List<ClubEvent>> watchUpcomingEventsForUser({
    required List<String> clubIds,
    required String authUid,
  }) {
    if (clubIds.isEmpty) return Stream.value([]);

    final audienceStreams = clubIds.map((clubId) {
      return watchClubMember(clubId: clubId, uid: authUid).map(
        (member) => [
          MapEntry(
            clubId,
            member == null ? authUid : _rosterAudienceId(member, authUid),
          ),
        ],
      );
    }).toList();

    return combineLatestListStreams(audienceStreams).asyncExpand((entries) {
      final audienceByClub = Map<String, String>.fromEntries(entries);

      final eventStreams = clubIds.map((clubId) {
        final audienceId = audienceByClub[clubId] ?? authUid;
        return watchUpcomingEventsForClubMember(
          clubId: clubId,
          audienceId: audienceId,
          authUid: authUid,
        );
      }).toList();

      return combineLatestListStreams(eventStreams).map(_dedupeEvents);
    });
  }

  /// @deprecated Préférer [watchUpcomingEventsForUser].
  Stream<List<ClubEvent>> watchUpcomingEventsForClubs({
    required List<String> clubIds,
    required String uid,
  }) =>
      watchUpcomingEventsForUser(clubIds: clubIds, authUid: uid);

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

  /// Tous les événements d'un jour (vue planning club).
  Stream<List<ClubEvent>> watchClubEventsOnDay({
    required String clubId,
    required DateTime day,
  }) {
    final dayStart = _startOfDay(day);
    // Fenêtre élargie + filtre calendaire : évite les ratés timezone / Timestamp.
    final queryFrom = dayStart.subtract(const Duration(hours: 14));
    final queryTo = dayStart.add(const Duration(days: 1, hours: 14));

    return _events(clubId)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(queryFrom),
        )
        .where(
          FirestoreFields.date,
          isLessThan: Timestamp.fromDate(queryTo),
        )
        .orderBy(FirestoreFields.date)
        .snapshots()
        .map(
          (snap) => sortedByDate(
            snap.docs
                .map((d) => ClubEvent.fromFirestore(clubId: clubId, doc: d))
                .where((e) => !e.canceled && sameCalendarDay(e.date, day)),
          ),
        );
  }

  /// Événements d'un jour pour un membre (mêmes sources que l'accueil joueur).
  Stream<List<ClubEvent>> watchMemberEventsOnDay({
    required String clubId,
    required DateTime day,
    required String audienceId,
    required String authUid,
  }) {
    return watchUpcomingEventsForClubMember(
      clubId: clubId,
      audienceId: audienceId,
      authUid: authUid,
    ).map(
      (events) => sortedByDate(
        events.where((e) => sameCalendarDay(e.date, day)),
      ),
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
        FirestoreFields.date: Timestamp.fromDate(
          DateTime.utc(date.year, date.month, date.day),
        ),
        FirestoreFields.dateId: dateIdFor(date),
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
    required String authUid,
  }) async {
    final audienceId = await resolveAudienceId(
      clubId: clubId,
      authUid: authUid,
    );
    final since = DateTime.now().subtract(const Duration(days: 30));
    final snap = await _events(clubId)
        .where(FirestoreFields.teamMemberIds, arrayContains: audienceId)
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
      final entry = attendance[audienceId] ?? attendance[authUid];
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

  /// Ajoute un convoqué aux événements à venir d'une équipe (ex. coach aussi joueur).
  Future<void> addAudienceToUpcomingTeamEvents({
    required String clubId,
    required String teamId,
    required String audienceId,
  }) async {
    if (audienceId.isEmpty) return;

    final snap = await _events(clubId)
        .where(FirestoreFields.teamIds, arrayContains: teamId)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfToday()),
        )
        .get();

    final batch = _db.batch();
    var pending = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data[FirestoreFields.canceled] == true) continue;
      final members =
          (data[FirestoreFields.teamMemberIds] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [];
      if (members.contains(audienceId)) continue;

      batch.update(doc.reference, {
        FirestoreFields.teamMemberIds: FieldValue.arrayUnion([audienceId]),
      });
      pending++;
      if (pending >= 400) {
        await batch.commit();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  /// Retire un convoqué des événements à venir (ex. coach retiré du roster joueurs).
  Future<void> removeAudienceFromUpcomingTeamEvents({
    required String clubId,
    required String teamId,
    required String audienceId,
  }) async {
    if (audienceId.isEmpty) return;

    final snap = await _events(clubId)
        .where(FirestoreFields.teamIds, arrayContains: teamId)
        .where(
          FirestoreFields.date,
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfToday()),
        )
        .get();

    final batch = _db.batch();
    var pending = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data[FirestoreFields.canceled] == true) continue;
      final members =
          (data[FirestoreFields.teamMemberIds] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [];
      if (!members.contains(audienceId)) continue;

      batch.update(doc.reference, {
        FirestoreFields.teamMemberIds: FieldValue.arrayRemove([audienceId]),
      });
      pending++;
      if (pending >= 400) {
        await batch.commit();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}
