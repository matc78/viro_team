import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/event_type_queries.dart';
import '../constants/firebase_collections.dart';
import '../utils/app_logger.dart';
import '../utils/firebase_helpers.dart';
import '../utils/firestore_instance.dart';
import 'player_club_stats_helpers.dart';

/// Résumé chiffré + classements pour l’écran « Statistiques du club ».
class ClubStatsHubSnapshot {
  final int playersCount;
  final int teamsCount;
  final int coachesCount;
  final int adminsCount;
  final int eventsTotal;
  final int trainingsPast;
  final int matchesPast;
  /// Passés dont le type n’est ni entraînement ni match (ex. Évènement, Autre).
  /// Dérivé : événements datés dans le passé, moins entraînements et matchs.
  final int otherPast;
  final int eventsUpcoming;
  final int sampleSize;
  final double? avgTrainingReal;
  final double? avgRsvpPresent;
  final List<ClubPlayerRank> topPresenceReal;
  final List<ClubPlayerRank> worstPresenceReal;
  final List<ClubPlayerRank> topRsvpTraining;
  final List<ClubPlayerRank> worstRsvpTraining;
  final List<ClubPlayerLateRank> topLate;
  final List<ClubPlayerRank> topMatchRsvp;
  final List<ClubPlayerRank> worstMatchRsvp;

  const ClubStatsHubSnapshot({
    required this.playersCount,
    required this.teamsCount,
    required this.coachesCount,
    required this.adminsCount,
    required this.eventsTotal,
    required this.trainingsPast,
    required this.matchesPast,
    required this.otherPast,
    required this.eventsUpcoming,
    required this.sampleSize,
    this.avgTrainingReal,
    this.avgRsvpPresent,
    required this.topPresenceReal,
    required this.worstPresenceReal,
    required this.topRsvpTraining,
    required this.worstRsvpTraining,
    required this.topLate,
    required this.topMatchRsvp,
    required this.worstMatchRsvp,
  });
}

class ClubPlayerRank {
  final String uid;
  final String displayName;
  final double value;
  final String valueLabel;

  const ClubPlayerRank({
    required this.uid,
    required this.displayName,
    required this.value,
    required this.valueLabel,
  });
}

class ClubPlayerLateRank {
  final String uid;
  final String displayName;
  final int lateCount;

  const ClubPlayerLateRank({
    required this.uid,
    required this.displayName,
    required this.lateCount,
  });
}

String _displayName(Map<String, dynamic>? userData) {
  if (userData == null || userData.isEmpty) return 'Joueur';
  final f = userData['firstName'] as String? ?? '';
  final l = userData['lastName'] as String? ?? '';
  final s = '$f $l'.trim();
  return s.isEmpty ? 'Joueur' : s;
}

Future<List<String>> _allPlayerMemberIds(String clubId) async {
  final out = <String>[];
  final base = appFirestore
      .collection(FirebaseCollections.clubs)
      .doc(clubId)
      .collection(FirebaseCollections.members);
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  while (true) {
    Query<Map<String, dynamic>> q = base
        .where('roles', arrayContains: 'player')
        .orderBy(FieldPath.documentId)
        .limit(400);
    if (cursor != null) {
      q = q.startAfterDocument(cursor);
    }
    final snap = await q.get();
    if (snap.docs.isEmpty) break;
    out.addAll(snap.docs.map((d) => d.id));
    if (snap.docs.length < 400) break;
    cursor = snap.docs.last;
  }
  return out;
}

Future<int> _safeCount(AggregateQuery query, String context) async {
  try {
    final snap = await query.get();
    return snap.count ?? 0;
  } catch (e, st) {
    AppLogger.instance.error(
      'club stats count failed',
      error: e,
      stackTrace: st,
      context: {'ctx': context},
    );
    return -1;
  }
}

/// Types « Évènement », « Autre » ou inconnus parmi les docs avec date passée.
int _derivedOtherPast(int eventsPast, int trainingsPast, int matchesPast) {
  if (eventsPast < 0 || trainingsPast < 0 || matchesPast < 0) return -1;
  return (eventsPast - trainingsPast - matchesPast).clamp(0, 1000000);
}

/// Charge agrégats club + classements (saison courante, [referenceDate] pour tests).
Future<ClubStatsHubSnapshot> loadClubStatsHubSnapshot(
  String clubId, [
  DateTime? referenceDate,
]) async {
  final db = appFirestore;
  final clubRef = db.collection(FirebaseCollections.clubs).doc(clubId);
  final eventsRef = clubRef.collection(FirebaseCollections.events);
  final now = Timestamp.fromDate(referenceDate ?? DateTime.now());

  final clubSnap = await clubRef.get();
  final clubData = clubSnap.data();

  final adminId = clubData?['adminId'] as String?;
  final adminsList =
      (clubData?['admins'] as List?)?.whereType<String>().toList() ?? [];
  final coachesList =
      (clubData?['coaches'] as List?)?.whereType<String>().toList() ?? [];
  final adminsCount = {
    ...{if (adminId != null && adminId.isNotEmpty) adminId},
    ...adminsList,
  }.length;
  final coachesCount = coachesList.length;

  final countFutures = await Future.wait([
    _safeCount(eventsRef.count(), 'eventsTotal'),
    _safeCount(
      eventsRef
          .where('type', whereIn: kTrainingEventTypesForQuery)
          .where('date', isLessThan: now)
          .count(),
      'trainingsPast',
    ),
    _safeCount(
      eventsRef
          .where('type', whereIn: kMatchEventTypesForQuery)
          .where('date', isLessThan: now)
          .count(),
      'matchesPast',
    ),
    _safeCount(
      eventsRef.where('date', isLessThan: now).count(),
      'eventsPast',
    ),
    _safeCount(
      eventsRef.where('date', isGreaterThanOrEqualTo: now).count(),
      'eventsUpcoming',
    ),
    _safeCount(
      clubRef
          .collection(FirebaseCollections.members)
          .where('roles', arrayContains: 'player')
          .count(),
      'players',
    ),
    _safeCount(
      clubRef.collection(FirebaseCollections.teams).count(),
      'teams',
    ),
  ]);

  final eventsTotal = countFutures[0];
  final trainingsPast = countFutures[1];
  final matchesPast = countFutures[2];
  final eventsPast = countFutures[3];
  final eventsUpcoming = countFutures[4];
  final playersCount = countFutures[5];
  final teamsCount = countFutures[6];

  final otherPast = _derivedOtherPast(eventsPast, trainingsPast, matchesPast);

  final memberIds = await _allPlayerMemberIds(clubId);
  if (memberIds.isEmpty) {
    return ClubStatsHubSnapshot(
      playersCount: playersCount >= 0 ? playersCount : 0,
      teamsCount: teamsCount >= 0 ? teamsCount : 0,
      coachesCount: coachesCount,
      adminsCount: adminsCount,
      eventsTotal: eventsTotal >= 0 ? eventsTotal : 0,
      trainingsPast: trainingsPast >= 0 ? trainingsPast : 0,
      matchesPast: matchesPast >= 0 ? matchesPast : 0,
      otherPast: _derivedOtherPast(eventsPast, trainingsPast, matchesPast),
      eventsUpcoming: eventsUpcoming >= 0 ? eventsUpcoming : 0,
      sampleSize: 0,
      avgTrainingReal: null,
      avgRsvpPresent: null,
      topPresenceReal: const [],
      worstPresenceReal: const [],
      topRsvpTraining: const [],
      worstRsvpTraining: const [],
      topLate: const [],
      topMatchRsvp: const [],
      worstMatchRsvp: const [],
    );
  }

  final userDocs = await fetchUsersBatch(memberIds);
  final ref = referenceDate ?? DateTime.now();

  var n = 0;
  double sumTr = 0;
  var nTr = 0;
  double sumRsvp = 0;
  var nRsvp = 0;

  final presenceCandidates = <({String uid, Map<String, dynamic> u, double rate})>[];
  final rsvpCandidates = <({String uid, Map<String, dynamic> u, double rate})>[];
  final matchRsvpCandidates = <({String uid, Map<String, dynamic> u, double rate})>[];
  final lateList = <({String uid, Map<String, dynamic> u, int lateCount})>[];

  for (final doc in userDocs) {
    final raw = doc.data();
    if (raw == null) continue;
    final s = playerSeasonStatsForClub(raw, clubId, ref);
    if (!s.hasAnyData) continue;
    n++;
    final tr = s.trainingRealRate;
    if (tr != null) {
      sumTr += tr;
      nTr++;
    }
    final rp = s.rsvpPresentAmongAnswered;
    if (rp != null) {
      sumRsvp += rp;
      nRsvp++;
    }

    if (s.trainingTotal > 0) {
      final rate = s.trainingRealRate;
      if (rate != null) {
        presenceCandidates.add((uid: doc.id, u: raw, rate: rate));
      }
    }
    final rsvpN = s.rsvpPresent + s.rsvpAbsent;
    if (rsvpN > 0) {
      final r = s.rsvpPresentAmongAnswered;
      if (r != null) {
        rsvpCandidates.add((uid: doc.id, u: raw, rate: r));
      }
    }
    final matchN = s.matchPresent + s.matchAbsent;
    if (matchN > 0) {
      final r = s.matchPresentAmongAnswered;
      if (r != null) {
        matchRsvpCandidates.add((uid: doc.id, u: raw, rate: r));
      }
    }
    if (s.trainingLate > 0) {
      lateList.add((uid: doc.id, u: raw, lateCount: s.trainingLate));
    }
  }

  int cmpPresence(
    ({String uid, Map<String, dynamic> u, double rate}) a,
    ({String uid, Map<String, dynamic> u, double rate}) b,
  ) {
    final c = b.rate.compareTo(a.rate);
    if (c != 0) return c;
    return _displayName(a.u).compareTo(_displayName(b.u));
  }

  int cmpPresenceWorst(
    ({String uid, Map<String, dynamic> u, double rate}) a,
    ({String uid, Map<String, dynamic> u, double rate}) b,
  ) {
    final c = a.rate.compareTo(b.rate);
    if (c != 0) return c;
    return _displayName(a.u).compareTo(_displayName(b.u));
  }

  presenceCandidates.sort(cmpPresence);
  final topP = presenceCandidates.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  final worstSorted = [...presenceCandidates]..sort(cmpPresenceWorst);
  final worstP = worstSorted.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  rsvpCandidates.sort(cmpPresence);
  final topR = rsvpCandidates.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  final worstRsvpSorted = [...rsvpCandidates]..sort(cmpPresenceWorst);
  final worstR = worstRsvpSorted.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  matchRsvpCandidates.sort(cmpPresence);
  final topM = matchRsvpCandidates.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  final worstMSorted = [...matchRsvpCandidates]..sort(cmpPresenceWorst);
  final worstM = worstMSorted.take(3).map((e) {
    return ClubPlayerRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      value: e.rate,
      valueLabel: formatPercent(e.rate),
    );
  }).toList();

  lateList.sort((a, b) {
    final c = b.lateCount.compareTo(a.lateCount);
    if (c != 0) return c;
    return _displayName(a.u).compareTo(_displayName(b.u));
  });
  final topLate = lateList.take(3).map((e) {
    return ClubPlayerLateRank(
      uid: e.uid,
      displayName: _displayName(e.u),
      lateCount: e.lateCount,
    );
  }).toList();

  return ClubStatsHubSnapshot(
    playersCount: playersCount >= 0 ? playersCount : memberIds.length,
    teamsCount: teamsCount >= 0 ? teamsCount : 0,
    coachesCount: coachesCount,
    adminsCount: adminsCount,
    eventsTotal: eventsTotal >= 0 ? eventsTotal : 0,
    trainingsPast: trainingsPast >= 0 ? trainingsPast : 0,
    matchesPast: matchesPast >= 0 ? matchesPast : 0,
    otherPast: otherPast,
    eventsUpcoming: eventsUpcoming >= 0 ? eventsUpcoming : 0,
    sampleSize: n,
    avgTrainingReal: nTr > 0 ? sumTr / nTr : null,
    avgRsvpPresent: nRsvp > 0 ? sumRsvp / nRsvp : null,
    topPresenceReal: topP,
    worstPresenceReal: worstP,
    topRsvpTraining: topR,
    worstRsvpTraining: worstR,
    topLate: topLate,
    topMatchRsvp: topM,
    worstMatchRsvp: worstM,
  );
}
