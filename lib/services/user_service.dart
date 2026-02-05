import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';
import '../utils/firebase_helpers.dart';

/// Service pour gérer les opérations liées aux utilisateurs
class UserService {
  final FirebaseFirestore _db = appFirestore;

  /// Récupère un utilisateur par son ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _db
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();
      
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Écoute les changements d'un utilisateur en temps réel
  Stream<UserModel?> watchUser(String userId) {
    return _db
        .collection(FirebaseCollections.users)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Récupère plusieurs utilisateurs en batch (évite N+1 queries)
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    final docs = await fetchUsersBatch(userIds);
    return docs
        .where((doc) => doc.exists)
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
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
