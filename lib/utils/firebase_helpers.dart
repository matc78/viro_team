import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/membership_service.dart';
import 'package:viro_team/utils/firestore_instance.dart';

/// Récupère plusieurs documents utilisateur en batch pour éviter les N+1 queries.
/// Firestore limite whereIn à 10 éléments, donc on fait plusieurs appels si nécessaire.
Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchUsersBatch(
  List<String> userIds,
) async {
  if (userIds.isEmpty) return [];

  final batches = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
  for (var i = 0; i < userIds.length; i += 10) {
    final batch = userIds.sublist(i, math.min(i + 10, userIds.length));
    batches.add(
      appFirestore
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

/// Met à jour le champ profileSummaries de users/{uid} (liste [{ clubId, role }, ...]).
/// À appeler après chaque création/modification/suppression d'un membership.
Future<void> updateProfileSummariesForUser(
  String uid,
  List<Map<String, String>> summaries,
) async {
  await appFirestore.collection(FirebaseCollections.users).doc(uid).set({
    'profileSummaries': summaries,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Vérifie si un utilisateur appartient à un club avec un rôle donné
/// Utilise profileSummaries et activeContext.
bool userBelongsToClub(
  Map<String, dynamic> userData,
  String clubId, {
  String? role,
}) {
  // Option A : profileSummaries (liste [{ clubId, role }])
  final summaries = userData['profileSummaries'] as List?;
  if (summaries != null) {
    for (final e in summaries) {
      if (e is Map && e['clubId'] == clubId) {
        final r = e['role'] as String?;
        if (role == null || r == role) return true;
      }
    }
  }

  // Contexte actif
  final activeContext = userData['activeContext'] as Map<String, dynamic>?;
  if (activeContext != null && activeContext['clubId'] == clubId) {
    if (role == null || role == activeContext['role']) return true;
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
  // Option A : profileSummaries
  final summaries = userData['profileSummaries'] as List?;
  if (summaries != null) {
    for (final e in summaries) {
      if (e is Map && e['clubId'] == clubId) {
        final r = e['role'] as String?;
        if (r != null && r.isNotEmpty) return r;
      }
    }
  }

  // Contexte actif
  final activeContext = userData['activeContext'] as Map<String, dynamic>?;
  if (activeContext != null && activeContext['clubId'] == clubId) {
    return activeContext['role'] as String?;
  }

  return null;
}

/// Récupère tous les rôles d'un utilisateur dans un club donné
/// Retourne une liste de rôles (peut contenir 'player', 'coach', 'admin', etc.)
List<String> getAllUserRolesInClub(
  Map<String, dynamic> userData,
  String clubId,
) {
  final result = <String>[];
  // Option A : profileSummaries
  final summaries = userData['profileSummaries'] as List?;
  if (summaries != null) {
    for (final e in summaries) {
      if (e is Map && e['clubId'] == clubId) {
        final r = e['role'] as String?;
        if (r != null && r.isNotEmpty && !result.contains(r)) result.add(r);
      }
    }
    if (result.isNotEmpty) return result;
  }

  // Contexte actif
  final activeContext = userData['activeContext'] as Map<String, dynamic>?;
  if (activeContext != null && activeContext['clubId'] == clubId) {
    final activeRole = activeContext['role'] as String?;
    if (activeRole != null &&
        activeRole.isNotEmpty &&
        !result.contains(activeRole)) {
      result.add(activeRole);
    }
  }

  return result;
}

/// Récupère les données du document member pour un utilisateur dans un club.
Future<Map<String, dynamic>?> getMemberData(
  FirebaseFirestore firestore,
  String uid,
  String clubId,
) async {
  final snap = await firestore
      .collection(FirebaseCollections.clubs)
      .doc(clubId)
      .collection(FirebaseCollections.members)
      .doc(uid)
      .get();
  return snap.data();
}

/// Extrait les noms d'équipes du joueur depuis les documents member.
/// Si [clubId] est fourni, lit uniquement ce club ; sinon agrège tous les clubs player via profileSummaries.
Future<List<String>> getUserTeamNames(
  FirebaseFirestore firestore,
  String uid, {
  String? clubId,
  List<Map<String, String>>? profileSummaries,
}) async {
  if (clubId != null) {
    final member = await getMemberData(firestore, uid, clubId);
    final player = member?['player'] as Map<String, dynamic>?;
    final list =
        (player?['teamNames'] as List?)?.whereType<String>().toList() ?? [];
    return list;
  }
  List<Map<String, String>> summaries = profileSummaries ?? [];
  if (summaries.isEmpty) {
    final userSnap = await firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .get();
    final raw = userSnap.data()?['profileSummaries'] as List?;
    if (raw != null) {
      summaries = raw
          .whereType<Map>()
          .map(
            (e) => Map<String, String>.from(
              Map.from(
                e,
              ).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
            ),
          )
          .toList();
    }
  }
  final names = <String>{};
  for (final e in summaries) {
    if (e['role'] == 'player') {
      final cid = e['clubId'];
      if (cid != null && cid.isNotEmpty) {
        final member = await getMemberData(firestore, uid, cid);
        final player = member?['player'] as Map<String, dynamic>?;
        final list = (player?['teamNames'] as List?)?.whereType<String>() ?? [];
        names.addAll(list);
      }
    }
  }
  return names.toList();
}

/// Extrait les catégories du joueur depuis les documents member.
Future<List<String>> getUserCategories(
  FirebaseFirestore firestore,
  String uid, {
  String? clubId,
  List<Map<String, String>>? profileSummaries,
}) async {
  if (clubId != null) {
    final member = await getMemberData(firestore, uid, clubId);
    final player = member?['player'] as Map<String, dynamic>?;
    final list =
        (player?['categories'] as List?)?.whereType<String>().toList() ?? [];
    return list;
  }
  List<Map<String, String>> summaries = profileSummaries ?? [];
  if (summaries.isEmpty) {
    final userSnap = await firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .get();
    final raw = userSnap.data()?['profileSummaries'] as List?;
    if (raw != null) {
      summaries = raw
          .whereType<Map>()
          .map(
            (e) => Map<String, String>.from(
              Map.from(
                e,
              ).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
            ),
          )
          .toList();
    }
  }
  final cats = <String>{};
  for (final e in summaries) {
    if (e['role'] == 'player') {
      final cid = e['clubId'];
      if (cid != null && cid.isNotEmpty) {
        final member = await getMemberData(firestore, uid, cid);
        final player = member?['player'] as Map<String, dynamic>?;
        final list =
            (player?['categories'] as List?)?.whereType<String>() ?? [];
        cats.addAll(list);
      }
    }
  }
  return cats.toList();
}

/// Met à jour le document member pour un joueur (ajout ou retrait d'équipe).
/// Ne lit ni n'écrit plus le champ roles du document user.
Future<void> updatePlayerClubsForTeam(
  FirebaseFirestore firestore,
  String userId,
  String clubId, {
  required bool add,
  required String teamId,
  required String teamName,
  required String teamCategory,
}) async {
  final memberData = await getMemberData(firestore, userId, clubId);
  if (memberData == null) return;

  final player = Map<String, dynamic>.from(
    (memberData['player'] as Map?) ?? {},
  );
  final teamIds = List<String>.from(
    (player['teamIds'] as List?)?.whereType<String>() ?? [],
  );
  final teamNames = List<String>.from(
    (player['teamNames'] as List?)?.whereType<String>() ?? [],
  );
  final categories = List<String>.from(
    (player['categories'] as List?)?.whereType<String>() ?? [],
  );

  if (add) {
    if (!teamIds.contains(teamId)) teamIds.add(teamId);
    if (teamName.isNotEmpty && !teamNames.contains(teamName))
      teamNames.add(teamName);
    if (teamCategory.isNotEmpty && !categories.contains(teamCategory))
      categories.add(teamCategory);
  } else {
    teamIds.remove(teamId);
    teamNames.remove(teamName);
    categories.remove(teamCategory);
  }

  await MembershipService.instance.updateMemberPlayer(
    uid: userId,
    clubId: clubId,
    license: player['license'] as String?,
    teamIds: teamIds,
    teamNames: teamNames,
    categories: categories,
  );
}

/// Vérifie si un joueur a un numéro de licence dans un club donné (lecture depuis le document member).
Future<bool> playerHasLicense(
  FirebaseFirestore firestore,
  String uid,
  String clubId,
) async {
  final member = await getMemberData(firestore, uid, clubId);
  final player = member?['player'] as Map<String, dynamic>?;
  final license = player?['license'] as String?;
  return license != null && license.trim().isNotEmpty;
}
