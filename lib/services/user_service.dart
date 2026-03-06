import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';
import '../utils/firebase_helpers.dart';

/// Service pour gérer les opérations liées aux utilisateurs
class UserService {
  final FirebaseFirestore _db = appFirestore;

  /// Charge les documents member pour un utilisateur (clubs/{clubId}/members/{uid}) à partir de profileSummaries.
  Future<Map<String, Map<String, dynamic>>> _loadMembersByClub(
    String uid,
    List<dynamic> profileSummariesRaw,
  ) async {
    final clubIds = profileSummariesRaw
        .whereType<Map>()
        .map((m) => m['clubId'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (clubIds.isEmpty) return {};

    final membersByClub = <String, Map<String, dynamic>>{};
    await Future.wait(clubIds.map((clubId) async {
      final snap = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.members)
          .doc(uid)
          .get();
      final d = snap.data();
      if (d != null) membersByClub[clubId] = d;
    }));
    return membersByClub;
  }

  /// Récupère un utilisateur par son ID (user doc + members pour construire UserModel).
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _db
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();

      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final summariesRaw = data['profileSummaries'] as List? ?? [];
      final membersByClub = await _loadMembersByClub(doc.id, summariesRaw);
      return UserModel.fromUserDocAndMembers(doc, membersByClub);
    } catch (e) {
      return null;
    }
  }

  /// Écoute les changements d'un utilisateur en temps réel (recharge les members à chaque snapshot).
  Stream<UserModel?> watchUser(String userId) {
    return _db
        .collection(FirebaseCollections.users)
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return null;
          final data = doc.data() ?? {};
          final summariesRaw = data['profileSummaries'] as List? ?? [];
          final membersByClub = await _loadMembersByClub(doc.id, summariesRaw);
          return UserModel.fromUserDocAndMembers(doc, membersByClub);
        });
  }

  /// Récupère plusieurs utilisateurs en batch (charge user docs puis members pour chacun).
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final docs = await fetchUsersBatch(userIds);
    final futures = docs.where((doc) => doc.exists).map((doc) async {
      final data = doc.data() ?? {};
      final summariesRaw = data['profileSummaries'] as List? ?? [];
      final membersByClub = await _loadMembersByClub(doc.id, summariesRaw);
      return UserModel.fromUserDocAndMembers(doc, membersByClub);
    });
    return Future.wait(futures);
  }

  /// Met à jour le contexte actif d'un utilisateur
  Future<bool> updateActiveContext(
    String userId,
    String role,
    String clubId,
  ) async {
    try {
      await _db
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update({
        'activeContext': {
          'role': role,
          'clubId': clubId,
        },
      });
      AppLogger.instance.info(
        'Contexte actif mis à jour',
        {
          'userId': userId,
          'role': role,
          'clubId': clubId,
        },
      );
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la mise à jour du contexte actif',
        error: e,
        context: {
          'userId': userId,
          'role': role,
          'clubId': clubId,
        },
      );
      return false;
    }
  }

  /// Vérifie si un utilisateur a un rôle dans un club
  Future<bool> hasRoleInClub(
    String userId,
    String clubId,
    String role,
  ) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return false;
      return user.hasRoleInClub(role, clubId);
    } catch (e) {
      return false;
    }
  }
}
