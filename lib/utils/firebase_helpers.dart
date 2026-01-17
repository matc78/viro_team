import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Récupère plusieurs documents utilisateur en batch pour éviter les N+1 queries.
/// Firestore limite whereIn à 10 éléments, donc on fait plusieurs appels si nécessaire.
Future<List<DocumentSnapshot>> fetchUsersBatch(List<String> userIds) async {
  if (userIds.isEmpty) return [];

  final batches = <Future<QuerySnapshot>>[];
  for (var i = 0; i < userIds.length; i += 10) {
    final batch = userIds.sublist(i, math.min(i + 10, userIds.length));
    batches.add(
      FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get(),
    );
  }

  final results = await Future.wait(batches);
  final allDocs = results.expand((snap) => snap.docs).toList();

  // Créer une map pour préserver l'ordre original
  final Map<String, DocumentSnapshot> docsMap = {
    for (var doc in allDocs) doc.id: doc,
  };

  // Retourner dans l'ordre de userIds
  return userIds
      .map((id) => docsMap[id])
      .whereType<DocumentSnapshot>()
      .toList();
}

/// Vérifie si un utilisateur appartient à un club avec un rôle donné
/// Compatible avec l'ancienne structure (clubId/role à la racine) et la nouvelle (roles/activeContext)
bool userBelongsToClub(Map<String, dynamic> userData, String clubId, {String? role}) {
  // Nouvelle structure : vérifier dans roles
  final roles = userData['roles'] as Map<String, dynamic>?;
  
  if (roles != null) {
    // Vérifier player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        final isInClub = clubs.any((club) => club['clubId'] == clubId);
        if (isInClub) {
          if (role == null || role == 'player') return true;
        }
      }
      // Ancienne structure : clubId direct (compatibilité)
      else if (playerData['clubId'] == clubId) {
        if (role == null || role == 'player') return true;
      }
    }
    
    // Vérifier coach
    if (roles['coach'] is List) {
      for (var coach in (roles['coach'] as List)) {
        if (coach is Map) {
          final coachClubId = coach['clubId'] as String?;
          if (coachClubId == clubId) {
            if (role == null || role == 'coach') return true;
          }
        }
      }
    }
    
    // Vérifier admin
    if (roles['admin'] is List) {
      final adminClubIds = (roles['admin'] as List).whereType<String>();
      if (adminClubIds.contains(clubId)) {
        if (role == null || role == 'admin' || role == 'admin_fondateur') return true;
      }
    }
  }
  
  // Ancienne structure (fallback pour compatibilité)
  final legacyClubId = userData['clubId'] as String?;
  if (legacyClubId == clubId) {
    if (role != null) {
      final legacyRole = userData['role'] as String?;
      if (role == 'admin_fondateur') {
        return legacyRole == 'admin_fondateur' || legacyRole == 'admin';
      }
      return legacyRole == role;
    }
    return true;
  }
  
  return false;
}

/// Filtre une liste de documents utilisateur pour ne garder que ceux qui appartiennent au club
List<DocumentSnapshot> filterUsersByClub(
  List<DocumentSnapshot> users,
  String clubId, {
  String? role,
}) {
  return users.where((doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    return userBelongsToClub(data, clubId, role: role);
  }).toList();
}

/// Récupère le rôle principal d'un utilisateur dans un club donné
String? getUserRoleInClub(Map<String, dynamic> userData, String clubId) {
  final roles = userData['roles'] as Map<String, dynamic>?;
  
  if (roles != null) {
    // Vérifier player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        final isInClub = clubs.any((club) => club['clubId'] == clubId);
        if (isInClub) return 'player';
      }
      // Ancienne structure : clubId direct (compatibilité)
      else if (playerData['clubId'] == clubId) {
        return 'player';
      }
    }
    
    // Vérifier coach
    if (roles['coach'] is List) {
      for (var coach in (roles['coach'] as List)) {
        if (coach is Map) {
          final coachClubId = coach['clubId'] as String?;
          if (coachClubId == clubId) return 'coach';
        }
      }
    }
    
    // Vérifier admin
    if (roles['admin'] is List) {
      final adminClubIds = (roles['admin'] as List).whereType<String>();
      if (adminClubIds.contains(clubId)) return 'admin';
    }
  }
  
  // Fallback ancienne structure
  final legacyClubId = userData['clubId'] as String?;
  if (legacyClubId == clubId) {
    return userData['role'] as String?;
  }
  
  return null;
}
