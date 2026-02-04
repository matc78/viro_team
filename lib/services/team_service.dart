import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';

/// Service pour gérer les opérations liées aux équipes
class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Crée une nouvelle équipe dans un club
  Future<DocumentReference?> addTeam(
    String clubId,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .add(data);
    } catch (e) {
      return null;
    }
  }

  /// Récupère toutes les équipes d'un club
  Future<List<DocumentSnapshot>> getTeamsByClub(String clubId) async {
    try {
      final snapshot = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .get();
      return snapshot.docs;
    } catch (e) {
      return [];
    }
  }

  /// Écoute les changements des équipes d'un club en temps réel
  Stream<List<DocumentSnapshot>> watchTeamsByClub(String clubId) {
    return _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Récupère une équipe spécifique
  Future<DocumentSnapshot?> getTeam(String clubId, String teamId) async {
    try {
      final doc = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .doc(teamId)
          .get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  /// Récupère les membres d'une équipe
  Future<List<String>> getTeamMemberIds(String clubId, String teamId) async {
    try {
      final team = await getTeam(clubId, teamId);
      if (team == null) return [];
      
      final data = team.data() as Map<String, dynamic>?;
      final playerIds = (data?['playerIds'] as List?)?.whereType<String>() ?? [];
      final coachIds = (data?['coachIds'] as List?)?.whereType<String>() ?? [];
      
      return [...playerIds, ...coachIds];
    } catch (e) {
      return [];
    }
  }
}
