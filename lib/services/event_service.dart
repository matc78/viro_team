import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';
import '../models/training_session_attendance.dart';
import '../utils/rsvp_stats_math.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../utils/app_logger.dart';

/// Service pour gérer les opérations liées aux événements
class EventService {
  final FirebaseFirestore _db = appFirestore;

  /// Récupère un événement spécifique
  Future<DocumentSnapshot?> getEvent(String clubId, String eventId) async {
    try {
      final doc = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  /// Écoute les changements d'un événement en temps réel
  Stream<DocumentSnapshot?> watchEvent(String clubId, String eventId) {
    return _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events)
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.exists ? doc : null);
  }

  /// Récupère tous les événements d'un club
  Stream<List<DocumentSnapshot>> watchEventsByClub(String clubId) {
    return _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Récupère les événements d'un club avec filtres
  Stream<List<DocumentSnapshot>> watchFilteredEvents(
    String clubId, {
    DateTime? startDate,
    DateTime? endDate,
    String? teamId,
    List<String>? teamMemberIds,
  }) {
    Query query = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }
    if (teamId != null) {
      query = query.where('teamId', isEqualTo: teamId);
    }
    if (teamMemberIds != null && teamMemberIds.isNotEmpty) {
      // Note: Firestore limite arrayContains à un seul élément
      // Pour plusieurs IDs, il faudrait restructurer les données
      query = query.where('teamMemberIds', arrayContains: teamMemberIds.first);
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  /// Démarre une session d'entraînement (enregistre qui a lancé et quand)
  Future<bool> startTrainingSession(
    String clubId,
    String eventId,
    String coachUid,
  ) async {
    try {
      await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .update({
        'sessionStartedAt': FieldValue.serverTimestamp(),
        'sessionStartedBy': coachUid,
      });
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du démarrage de la session',
        error: e,
        context: {'clubId': clubId, 'eventId': eventId, 'coachUid': coachUid},
      );
      return false;
    }
  }

  /// Enregistre ou met à jour la présence réelle d'un joueur lors d'un entraînement.
  /// Écrit de manière atomique sur les 3 niveaux :
  ///   1. event.sessionAttendance (temps réel)
  ///   2. training_attendances sub-collection (requêtes historiques)
  ///   3. users/{uid}.trainingStats (résumé dénormalisé)
  Future<bool> setSessionAttendance({
    required String clubId,
    required String eventId,
    required String playerId,
    required SessionStatus status,
    required String coachUid,
    required DateTime eventDate,
    required String teamName,
    int? lateMinutes,
    SessionStatus? previousStatus,
  }) async {
    try {
      final season = computeSeason(eventDate);
      final statsKey = '${clubId}_$season';
      final attendanceData = {
        'status': status.name,
        if (lateMinutes != null && status == SessionStatus.late)
          'lateMinutes': lateMinutes,
        'markedBy': coachUid,
        'markedAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();

      // Niveau 1 : champ sessionAttendance dans le document event
      final eventRef = _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId);
      batch.update(eventRef, {'sessionAttendance.$playerId': attendanceData});

      // Niveau 2 : sous-collection training_attendances (upsert par eventId+playerId)
      final taQuery = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.trainingAttendances)
          .where('eventId', isEqualTo: eventId)
          .where('playerId', isEqualTo: playerId)
          .limit(1)
          .get();

      final taRef = taQuery.docs.isNotEmpty
          ? taQuery.docs.first.reference
          : _db
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .collection(FirebaseCollections.trainingAttendances)
              .doc();

      batch.set(taRef, {
        'eventId': eventId,
        'playerId': playerId,
        'status': status.name,
        if (lateMinutes != null && status == SessionStatus.late)
          'lateMinutes': lateMinutes,
        'date': Timestamp.fromDate(eventDate),
        'teamName': teamName,
        'season': season,
        'markedBy': coachUid,
        'markedAt': FieldValue.serverTimestamp(),
      });

      // Niveau 3 : résumé dans users/{uid}.trainingStats
      // _trainingStatsClubId est un champ hint utilisé par les règles Firestore
      // pour vérifier que l'appelant est bien coach/admin du club concerné.
      final userRef = _db.collection(FirebaseCollections.users).doc(playerId);
      final Map<String, dynamic> statsUpdate = {
        '_trainingStatsClubId': clubId,
        'trainingStats.$statsKey.total': FieldValue.increment(
          previousStatus == null ? 1 : 0,
        ),
        'trainingStats.$statsKey.${status.name}': FieldValue.increment(1),
      };
      // Si on change de statut, on décrémente l'ancien
      if (previousStatus != null && previousStatus != status) {
        statsUpdate['trainingStats.$statsKey.${previousStatus.name}'] =
            FieldValue.increment(-1);
      }
      batch.update(userRef, statsUpdate);

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de l\'enregistrement de la présence session',
        error: e,
        context: {
          'clubId': clubId,
          'eventId': eventId,
          'playerId': playerId,
          'status': status.name,
        },
      );
      return false;
    }
  }

  /// Met à jour la présence d'un utilisateur pour un événement (sans agrégats stats).
  Future<bool> updateAttendance(
    String clubId,
    String eventId,
    String userId,
    String status,
  ) async {
    try {
      await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .update({
        'attendance.$userId': status,
      });
      AppLogger.instance.info(
        'Présence mise à jour',
        {
          'clubId': clubId,
          'eventId': eventId,
          'userId': userId,
          'status': status,
        },
      );
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la mise à jour de présence',
        error: e,
        context: {
          'clubId': clubId,
          'eventId': eventId,
          'userId': userId,
          'status': status,
        },
      );
      return false;
    }
  }

  /// Mise à jour de la réponse joueur (présent / absent / suppression) avec
  /// horodatage [attendanceMeta] et agrégats [rsvpTrainingStats] / [rsvpMatchStats] sur le user.
  Future<bool> updatePlayerAttendanceWithStats({
    required String clubId,
    required String eventId,
    required String userId,
    /// `null` = retirer la réponse (sans réponse).
    String? newStatus,
  }) async {
    final eventRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events)
        .doc(eventId);
    final userRef = _db.collection(FirebaseCollections.users).doc(userId);

    try {
      final preSnap = await eventRef.get();
      if (!preSnap.exists) return false;
      final preData = preSnap.data() as Map<String, dynamic>;
      final preAtt = Map<String, dynamic>.from(preData['attendance'] ?? {});
      final preOld = preAtt[userId]?.toString();
      if (preOld == newStatus) {
        return true;
      }

      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(eventRef);
        if (!snap.exists) {
          throw StateError('event_missing');
        }
        final data = snap.data() as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        final statsField = rsvpStatsFieldForEventType(type);

        final attendance = Map<String, dynamic>.from(data['attendance'] ?? {});
        final metaRoot = Map<String, dynamic>.from(data['attendanceMeta'] ?? {});
        final oldStatus = attendance[userId]?.toString();
        final oldMeta = metaRoot[userId] is Map
            ? Map<String, dynamic>.from(metaRoot[userId] as Map)
            : <String, dynamic>{};
        final oldDelay = oldMeta['delayContributionSec'] as int?;

        if (oldStatus == newStatus) {
          return;
        }

        final now = DateTime.now();
        final refTime = rsvpReferenceTime(data);
        final dateTs = data['date'] as Timestamp?;
        if (dateTs == null) {
          throw StateError('event_date_missing');
        }
        final season = computeSeason(dateTs.toDate());
        final statsKey = '${clubId}_$season';

        final eventPatch = <String, dynamic>{};

        if (newStatus == null) {
          eventPatch['attendance.$userId'] = FieldValue.delete();
          eventPatch['attendanceMeta.$userId'] = FieldValue.delete();
        } else {
          eventPatch['attendance.$userId'] = newStatus;
          if (newStatus == 'present') {
            final d = delaySecondsSinceReference(refTime, now);
            eventPatch['attendanceMeta.$userId'] = {
              'delayContributionSec': d,
              'firstRsvpAt': FieldValue.serverTimestamp(),
            };
          } else {
            eventPatch['attendanceMeta.$userId'] = {
              'firstRsvpAt': FieldValue.serverTimestamp(),
            };
          }
        }

        transaction.update(eventRef, eventPatch);

        if (statsField == null) {
          return;
        }

        var answeredD = 0;
        var presentD = 0;
        var absentD = 0;
        var delaySumD = 0;
        var delayCountD = 0;

        void undoOld() {
          if (oldStatus == 'present') {
            presentD--;
            if (oldDelay != null) {
              delaySumD -= oldDelay;
              delayCountD--;
            }
          } else if (oldStatus == 'absent') {
            absentD--;
          }
        }

        void applyNew() {
          if (newStatus == 'present') {
            presentD++;
            final d = delaySecondsSinceReference(refTime, now);
            delaySumD += d;
            delayCountD++;
          } else if (newStatus == 'absent') {
            absentD++;
          }
        }

        if (oldStatus == 'present' || oldStatus == 'absent') {
          undoOld();
        }
        if (newStatus == null) {
          if (oldStatus == 'present' || oldStatus == 'absent') {
            answeredD--;
          }
        } else {
          if (oldStatus != 'present' && oldStatus != 'absent') {
            answeredD++;
          }
          applyNew();
        }

        if (answeredD == 0 &&
            presentD == 0 &&
            absentD == 0 &&
            delaySumD == 0 &&
            delayCountD == 0) {
          return;
        }

        final userPatch = <String, dynamic>{
          '_rsvpStatsClubId': clubId,
          '$statsField.$statsKey.answered': FieldValue.increment(answeredD),
          '$statsField.$statsKey.present': FieldValue.increment(presentD),
          '$statsField.$statsKey.absent': FieldValue.increment(absentD),
          '$statsField.$statsKey.delaySumSec': FieldValue.increment(delaySumD),
          '$statsField.$statsKey.delayCount': FieldValue.increment(delayCountD),
        };
        transaction.set(userRef, userPatch, SetOptions(merge: true));
      });

      AppLogger.instance.info(
        'Présence + stats RSVP',
        {
          'clubId': clubId,
          'eventId': eventId,
          'userId': userId,
          'status': newStatus ?? 'deleted',
        },
      );
      return true;
    } catch (e, st) {
      AppLogger.instance.error(
        'Erreur mise à jour présence + stats',
        error: e,
        stackTrace: st,
        context: {
          'clubId': clubId,
          'eventId': eventId,
          'userId': userId,
          'status': newStatus,
        },
      );
      return false;
    }
  }
}
