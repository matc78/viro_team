// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Migration one-shot : ancienne structure users.roles + champs modération à la racine
/// vers :
/// - clubs/{clubId}/members/{uid} (source de vérité des rôles par club)
/// - users/{uid}.profileSummaries (liste pour le switcher)
/// - users/{uid}/avatar_moderation/state (champs modération)
///
/// **Utilisée uniquement sur la base Firestore "test".** Ne pas lancer en release.
/// Exécuter manuellement (ex. script, bouton admin) après sauvegarde des données.
///
/// Étapes :
/// 1. Pour chaque user avec roles : créer les docs members et remplir profileSummaries.
/// 2. Pour chaque user avec champs avatarModeration* à la racine : les copier dans
///    avatar_moderation/state puis les supprimer du doc user.
Future<void> runMigrationUserToMemberships({
  required bool dryRun,
  void Function(String)? onProgress,
}) async {
  if (kReleaseMode) {
    throw StateError(
      'Migration autorisée uniquement sur la base test. Ne pas lancer en release.',
    );
  }
  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'test',
  );
  final usersSnap = await db.collection(FirebaseCollections.users).get();
  int membersCreated = 0;
  int profileSummariesUpdated = 0;
  int moderationMoved = 0;

  for (final userDoc in usersSnap.docs) {
    final uid = userDoc.id;
    final data = userDoc.data();
    onProgress?.call('User $uid');

    // ---- 1. Construire profileSummaries depuis roles et créer members ----
    final roles = data['roles'] as Map<String, dynamic>? ?? {};
    final List<Map<String, String>> summaries = [];

    // Admin fondateur
    final adminFondateurList = _parseStringList(roles['admin_fondateur'] ?? roles['adminFondateur']);
    for (final clubId in adminFondateurList) {
      if (clubId.isEmpty) continue;
      summaries.add({'clubId': clubId, 'role': 'admin_fondateur'});
      if (!dryRun) {
        await _ensureMemberDoc(db, uid, clubId, 'admin_fondateur', true, userData: data);
        membersCreated++;
      }
    }

    // Admin (hors fondateur)
    final adminList = _parseStringList(roles['admin']);
    final fondateurSet = adminFondateurList.toSet();
    for (final clubId in adminList) {
      if (clubId.isEmpty || fondateurSet.contains(clubId)) continue;
      summaries.add({'clubId': clubId, 'role': 'admin'});
      if (!dryRun) {
        await _ensureMemberDoc(db, uid, clubId, 'admin', false, userData: data);
        membersCreated++;
      }
    }

    // Coach
    if (roles['coach'] is List) {
      for (final item in (roles['coach'] as List)) {
        if (item is! Map) continue;
        final clubId = item['clubId'] as String?;
        if (clubId == null || clubId.isEmpty) continue;
        summaries.add({'clubId': clubId, 'role': 'coach'});
        if (!dryRun) {
          await _ensureMemberDoc(db, uid, clubId, 'coach', false, userData: data, coachTeamIds: (item['teams'] as List?)?.whereType<String>().toList() ?? []);
          membersCreated++;
        }
      }
    }

    // Player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      List<Map<String, dynamic>> clubs = [];
      if (playerData['clubs'] is List) {
        clubs = (playerData['clubs'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (playerData['clubId'] != null) {
        clubs = [
          {
            'clubId': playerData['clubId'],
            'teamIds': (playerData['teamIds'] as List?)?.toList() ?? [],
            'teamNames': (playerData['teamNames'] as List?)?.toList() ?? [],
            'categories': (playerData['categories'] as List?)?.toList() ?? [],
            'license': playerData['license'],
          },
        ];
      }
      for (final clubEntry in clubs) {
        final clubId = clubEntry['clubId'] as String?;
        if (clubId == null || clubId.isEmpty) continue;
        summaries.add({'clubId': clubId, 'role': 'player'});
        if (!dryRun) {
          await _ensureMemberDoc(
            db,
            uid,
            clubId,
            'player',
            false,
            userData: data,
            playerLicense: clubEntry['license'] as String?,
            playerTeamIds: (clubEntry['teamIds'] as List?)?.whereType<String>().toList() ?? [],
            playerTeamNames: (clubEntry['teamNames'] as List?)?.whereType<String>().toList() ?? [],
            playerCategories: (clubEntry['categories'] as List?)?.whereType<String>().toList() ?? [],
          );
          membersCreated++;
        }
      }
    }

    if (summaries.isNotEmpty && !dryRun) {
      await db.collection(FirebaseCollections.users).doc(uid).update({
        'profileSummaries': summaries,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      profileSummariesUpdated++;
    }

    // ---- 2. Déplacer modération vers sous-collection ----
    final hasModerationAtRoot = data['avatarModerationRejected'] != null ||
        data['avatarModerationPending'] != null ||
        data['avatarModerationReason'] != null ||
        data['avatarModerationRejectedAt'] != null ||
        data['avatarModerationOk'] != null;
    if (hasModerationAtRoot && !dryRun) {
      final modRef = db
          .collection(FirebaseCollections.users)
          .doc(uid)
          .collection(FirebaseCollections.avatarModeration)
          .doc(FirebaseCollections.avatarModerationStateDocId);
      await modRef.set({
        'avatarModerationRejected': data['avatarModerationRejected'] ?? false,
        'avatarModerationPending': data['avatarModerationPending'] ?? false,
        if (data['avatarModerationReason'] != null) 'avatarModerationReason': data['avatarModerationReason'],
        if (data['avatarModerationRejectedAt'] != null) 'avatarModerationRejectedAt': data['avatarModerationRejectedAt'],
        'avatarModerationOk': data['avatarModerationOk'] ?? false,
      }, SetOptions(merge: true));
      moderationMoved++;
      await userDoc.reference.update({
        'avatarModerationRejected': FieldValue.delete(),
        'avatarModerationPending': FieldValue.delete(),
        'avatarModerationReason': FieldValue.delete(),
        'avatarModerationRejectedAt': FieldValue.delete(),
        'avatarModerationOk': FieldValue.delete(),
      });
    }

    // ---- 3. Nettoyage champs legacy à la racine (nouvelle architecture seule) ----
    final toDelete = <String>[];
    if (data['clubId'] != null) toDelete.add('clubId');
    if (data['clubName'] != null) toDelete.add('clubName');
    if (data['coachedTeams'] != null) toDelete.add('coachedTeams');
    if (data['roles'] != null) toDelete.add('roles');
    if (!dryRun && toDelete.isNotEmpty) {
      try {
        await userDoc.reference.update(
          Map.fromEntries(toDelete.map((k) => MapEntry(k, FieldValue.delete()))),
        );
      } catch (_) {
        // Ignorer si les champs sont déjà absents ou erreur mineure
      }
    }
  }

  AppLogger.instance.info('Migration terminée', {
    'dryRun': dryRun,
    'membersCreated': membersCreated,
    'profileSummariesUpdated': profileSummariesUpdated,
    'moderationMoved': moderationMoved,
  });
}

List<String> _parseStringList(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  if (value is Map) return value.values.whereType<String>().toList();
  if (value is String && value.isNotEmpty) return [value];
  return [];
}

Future<void> _ensureMemberDoc(
  FirebaseFirestore db,
  String uid,
  String clubId,
  String role,
  bool isFounderAdmin, {
  required Map<String, dynamic> userData,
  List<String> coachTeamIds = const [],
  String? playerLicense,
  List<String> playerTeamIds = const [],
  List<String> playerTeamNames = const [],
  List<String> playerCategories = const [],
}) async {
  final memberRef = db
      .collection(FirebaseCollections.clubs)
      .doc(clubId)
      .collection(FirebaseCollections.members)
      .doc(uid);

  final existing = await memberRef.get();
  final List<String> roles = existing.exists
      ? List<String>.from((existing.data()?['roles'] as List?)?.whereType<String>() ?? [])
      : [];
  if (!roles.contains(role)) roles.add(role);

  final displayName = _displayNameFromUserData(userData);
  final snapshot = {
    'displayName': displayName,
    'avatarUrl': userData['avatarUrl'],
    'email': userData['email'],
  };

  final Map<String, dynamic> updates = {
    'userId': uid,
    'roles': roles,
    'isFounderAdmin': isFounderAdmin || (existing.data()?['isFounderAdmin'] == true),
    'status': 'active',
    'updatedAt': FieldValue.serverTimestamp(),
    'snapshot': snapshot,
  };
  if (role == 'coach') {
    updates['coach'] = {
      'teamIds': coachTeamIds,
      'teamNames': coachTeamIds,
    };
  }
  if (role == 'player') {
    updates['player'] = {
      if (playerLicense != null) 'license': playerLicense,
      'teamIds': playerTeamIds,
      'teamNames': playerTeamNames,
      'categories': playerCategories,
    };
  }
  if (role == 'admin' || role == 'admin_fondateur') {
    updates['admin'] = {'scopes': ['full']};
  }
  if (!existing.exists) {
    updates['joinedAt'] = FieldValue.serverTimestamp();
  }
  // Conserver les sous-docs existants pour les autres rôles (même club)
  if (existing.exists) {
    final existingData = existing.data() ?? {};
    if (!updates.containsKey('coach') && existingData['coach'] is Map) updates['coach'] = existingData['coach'];
    if (!updates.containsKey('player') && existingData['player'] is Map) updates['player'] = existingData['player'];
    if (!updates.containsKey('admin') && existingData['admin'] is Map) updates['admin'] = existingData['admin'];
  }

  await memberRef.set(updates, SetOptions(merge: true));
}

String _displayNameFromUserData(Map<String, dynamic> userData) {
  final first = (userData['firstName'] as String?)?.trim() ?? '';
  final last = (userData['lastName'] as String?)?.trim() ?? '';
  if (first.isEmpty && last.isEmpty) return userData['email'] as String? ?? '';
  return [first, last.toUpperCase()].where((e) => e.isNotEmpty).join(' ').trim();
}
