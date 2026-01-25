import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';
import '../utils/app_logger.dart';

/// Service pour gérer les opérations liées aux événements
class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  /// Met à jour la présence d'un utilisateur pour un événement
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
}
