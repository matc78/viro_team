import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';

/// Récupère plusieurs documents utilisateur en batch pour éviter les N+1 queries.
/// Firestore limite whereIn à 10 éléments, donc on fait plusieurs appels si nécessaire.
Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchUsersBatch(List<String> userIds) async {
  if (userIds.isEmpty) return [];

  final batches = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
  for (var i = 0; i < userIds.length; i += 10) {
    final batch = userIds.sublist(i, math.min(i + 10, userIds.length));
    batches.add(
      FirebaseFirestore.instance
          .collection(FirebaseCollections.users)
          .where(FieldPath.documentId, whereIn: batch)
          .get(),
    );
  }

  final results = await Future.wait(batches);
  final allDocs = results.expand((snap) => snap.docs).toList();

  // Créer une map pour préserver l'ordre original
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> docsMap = {
    for (var doc in allDocs) doc.id: doc,
  };

  // Retourner dans l'ordre de userIds
  return userIds
      .map((id) => docsMap[id])
      .whereType<DocumentSnapshot<Map<String, dynamic>>>()
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
    
    // Vérifier admin_fondateur (roles.admin_fondateur = liste d'ids de clubs fondés)
    if (roles['admin_fondateur'] is List) {
      final fondateurClubIds = (roles['admin_fondateur'] as List).whereType<String>();
      if (fondateurClubIds.contains(clubId)) {
        if (role == null || role == 'admin' || role == 'admin_fondateur') return true;
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
List<DocumentSnapshot<Map<String, dynamic>>> filterUsersByClub(
  List<DocumentSnapshot<Map<String, dynamic>>> users,
  String clubId, {
  String? role,
}) {
  return users.where((doc) {
    final data = doc.data();
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
    
    // Vérifier admin_fondateur (priorité sur admin)
    if (roles['admin_fondateur'] is List) {
      final fondateurClubIds = (roles['admin_fondateur'] as List).whereType<String>();
      if (fondateurClubIds.contains(clubId)) return 'admin_fondateur';
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

/// Récupère tous les rôles d'un utilisateur dans un club donné
/// Retourne une liste de rôles (peut contenir 'player', 'coach', 'admin', etc.)
List<String> getAllUserRolesInClub(Map<String, dynamic> userData, String clubId) {
  final result = <String>[];
  final roles = userData['roles'] as Map<String, dynamic>?;
  
  if (roles != null) {
    // Vérifier player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        final isInClub = clubs.any((club) => club['clubId'] == clubId);
        if (isInClub) result.add('player');
      }
      // Ancienne structure : clubId direct (compatibilité)
      else if (playerData['clubId'] == clubId) {
        result.add('player');
      }
    }
    
    // Vérifier coach
    if (roles['coach'] is List) {
      for (var coach in (roles['coach'] as List)) {
        if (coach is Map) {
          final coachClubId = coach['clubId'] as String?;
          if (coachClubId == clubId) {
            result.add('coach');
            break; // Un seul rôle coach par club
          }
        }
      }
    }
    
    // Vérifier admin_fondateur (priorité : fondateur du club)
    if (roles['admin_fondateur'] is List) {
      final fondateurClubIds = (roles['admin_fondateur'] as List).whereType<String>();
      if (fondateurClubIds.contains(clubId)) {
        result.add('admin_fondateur');
      }
    }
    // Vérifier admin (si pas déjà fondateur)
    if (roles['admin'] is List) {
      final adminClubIds = (roles['admin'] as List).whereType<String>();
      if (adminClubIds.contains(clubId) && !result.contains('admin_fondateur')) {
        result.add('admin');
      }
    }
  } else {
    // Fallback ancienne structure
    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId == clubId) {
      final legacyRole = userData['role'] as String?;
      if (legacyRole != null) {
        result.add(legacyRole);
      }
    }
  }
  
  return result;
}

/// Extrait les noms d'équipes de l'utilisateur depuis roles.player.clubs (source unifiée).
/// Fallback sur les champs racine teamNames/teamName pour les anciennes données.
List<String> getUserTeamNames(Map<String, dynamic> userData) {
  final roles = userData['roles'] as Map<String, dynamic>? ?? {};
  if (roles['player'] is Map) {
    final playerData = roles['player'] as Map;
    if (playerData['clubs'] is List) {
      final clubs = (playerData['clubs'] as List).whereType<Map>();
      final names = <String>{};
      for (var club in clubs) {
        final list = (club['teamNames'] as List?)?.whereType<String>().toList() ?? [];
        names.addAll(list);
      }
      if (names.isNotEmpty) return names.toList();
    }
    // Migration : ancienne structure clubId direct
    if (playerData['clubId'] != null) {
      final list = (playerData['teamNames'] as List?)?.whereType<String>().toList() ?? [];
      if (list.isNotEmpty) return list;
    }
  }
  // Fallback champs racine (données legacy)
  final rootList = (userData['teamNames'] as List?)?.whereType<String>().toList() ?? [];
  if (rootList.isNotEmpty) return rootList;
  final single = userData['teamName'] as String?;
  if (single != null && single.isNotEmpty) return [single];
  return [];
}

/// Extrait les catégories d'équipes de l'utilisateur depuis roles.player.clubs (source unifiée).
/// Fallback sur les champs racine categories/category pour les anciennes données.
List<String> getUserCategories(Map<String, dynamic> userData) {
  final roles = userData['roles'] as Map<String, dynamic>? ?? {};
  if (roles['player'] is Map) {
    final playerData = roles['player'] as Map;
    if (playerData['clubs'] is List) {
      final clubs = (playerData['clubs'] as List).whereType<Map>();
      final cats = <String>{};
      for (var club in clubs) {
        final list = (club['categories'] as List?)?.whereType<String>().toList() ?? [];
        cats.addAll(list);
      }
      if (cats.isNotEmpty) return cats.toList();
    }
    if (playerData['clubId'] != null) {
      final list = (playerData['categories'] as List?)?.whereType<String>().toList() ?? [];
      if (list.isNotEmpty) return list;
    }
  }
  final rootList = (userData['categories'] as List?)?.whereType<String>().toList() ?? [];
  if (rootList.isNotEmpty) return rootList;
  final single = userData['category'] as String?;
  if (single != null && single.isNotEmpty) return [single];
  return [];
}

/// Met à jour roles.player.clubs pour un joueur (ajout ou retrait d'équipe).
/// Source unifiée : teamIds, teamNames, categories stockés par club.
Future<void> updatePlayerClubsForTeam(
  FirebaseFirestore firestore,
  String userId,
  String clubId, {
  required bool add,
  required String teamId,
  required String teamName,
  required String teamCategory,
}) async {
  final userRef = firestore.collection(FirebaseCollections.users).doc(userId);
  final userSnap = await userRef.get();
  final userData = userSnap.data() ?? {};
  final roles = userData['roles'] as Map<String, dynamic>? ?? {};
  final playerData = roles['player'] as Map<String, dynamic>? ?? {};

  List<Map<String, dynamic>> clubsList;
  if (playerData['clubs'] is List) {
    clubsList = (playerData['clubs'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } else if (playerData['clubId'] != null) {
    clubsList = [
      {
        'clubId': playerData['clubId'],
        'teamIds': (playerData['teamIds'] as List?)?.toList() ?? [],
        'teamNames': (playerData['teamNames'] as List?)?.toList() ?? [],
        'categories': (playerData['categories'] as List?)?.toList() ?? [],
        if (playerData['license'] != null) 'license': playerData['license'],
      },
    ];
  } else {
    clubsList = [];
  }

  bool found = false;
  for (var club in clubsList) {
    if (club['clubId'] == clubId) {
      found = true;
      final teamIds =
          List<String>.from((club['teamIds'] as List?)?.whereType<String>() ?? []);
      final teamNames =
          List<String>.from((club['teamNames'] as List?)?.whereType<String>() ?? []);
      final categories =
          List<String>.from((club['categories'] as List?)?.whereType<String>() ?? []);

      if (add) {
        if (!teamIds.contains(teamId)) teamIds.add(teamId);
        if (teamName.isNotEmpty && !teamNames.contains(teamName)) {
          teamNames.add(teamName);
        }
        if (teamCategory.isNotEmpty && !categories.contains(teamCategory)) {
          categories.add(teamCategory);
        }
      } else {
        teamIds.remove(teamId);
        teamNames.remove(teamName);
        categories.remove(teamCategory);
      }

      club['teamIds'] = teamIds;
      club['teamNames'] = teamNames;
      club['categories'] = categories;
      break;
    }
  }

  if (!found && add) {
    clubsList.add({
      'clubId': clubId,
      'teamIds': [teamId],
      'teamNames': teamName.isNotEmpty ? [teamName] : [],
      'categories': teamCategory.isNotEmpty ? [teamCategory] : [],
    });
  }

  final updatedRoles = Map<String, dynamic>.from(roles);
  updatedRoles['player'] = {...playerData, 'clubs': clubsList};

  await userRef.set({'roles': updatedRoles}, SetOptions(merge: true));
}

/// Vérifie si un joueur a un numéro de licence dans un club donné
/// Retourne true si la licence existe et n'est pas vide, false sinon
bool playerHasLicense(Map<String, dynamic> userData, String clubId) {
  final roles = userData['roles'] as Map<String, dynamic>?;
  
  if (roles != null && roles['player'] is Map) {
    final playerData = roles['player'] as Map;
    
    // Nouvelle structure : liste de clubs
    if (playerData['clubs'] is List) {
      final clubs = (playerData['clubs'] as List).whereType<Map>();
      final club = clubs.firstWhere(
        (c) => c['clubId'] == clubId,
        orElse: () => <String, dynamic>{},
      );
      final license = club['license'] as String?;
      return license != null && license.trim().isNotEmpty;
    }
    // Ancienne structure : clubId direct (compatibilité)
    else if (playerData['clubId'] == clubId) {
      final license = playerData['license'] as String?;
      return license != null && license.trim().isNotEmpty;
    }
  }
  
  return false;
}
