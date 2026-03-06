// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Rollback de la migration user → memberships (à utiliser avec précaution).
///
/// **Utilisé uniquement sur la base Firestore "test".** Ne pas lancer en release.
///
/// Étapes :
/// 1. Remet les champs avatarModeration* de users/{uid}/avatar_moderation/state
///    vers la racine du document user, puis supprime le doc state.
/// 2. Supprime profileSummaries des documents users.
///
/// Les documents clubs/{clubId}/members/{uid} ne sont pas supprimés (on ne peut pas
/// distinguer ceux créés par la migration des préexistants).
Future<void> runRollbackMembershipsToUser({
  required bool dryRun,
  void Function(String)? onProgress,
}) async {
  if (kReleaseMode) {
    throw StateError(
      'Rollback autorisé uniquement sur la base test. Ne pas lancer en release.',
    );
  }

  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'test',
  );

  final usersSnap = await db.collection(FirebaseCollections.users).get();
  int moderationRestored = 0;
  int profileSummariesRemoved = 0;

  for (final userDoc in usersSnap.docs) {
    final uid = userDoc.id;
    onProgress?.call('User $uid');

    // 1. Restaurer modération : avatar_moderation/state -> racine user
    final modRef = db
        .collection(FirebaseCollections.users)
        .doc(uid)
        .collection(FirebaseCollections.avatarModeration)
        .doc(FirebaseCollections.avatarModerationStateDocId);
    final modSnap = await modRef.get();
    if (modSnap.exists && modSnap.data() != null && !dryRun) {
      final modData = modSnap.data()!;
      await userDoc.reference.update({
        'avatarModerationRejected': modData['avatarModerationRejected'] ?? false,
        'avatarModerationPending': modData['avatarModerationPending'] ?? false,
        if (modData['avatarModerationReason'] != null)
          'avatarModerationReason': modData['avatarModerationReason'],
        if (modData['avatarModerationRejectedAt'] != null)
          'avatarModerationRejectedAt': modData['avatarModerationRejectedAt'],
        'avatarModerationOk': modData['avatarModerationOk'] ?? false,
      });
      await modRef.delete();
      moderationRestored++;
    }

    // 2. Supprimer profileSummaries
    final data = userDoc.data();
    if (data['profileSummaries'] != null && !dryRun) {
      await userDoc.reference.update({
        'profileSummaries': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      profileSummariesRemoved++;
    }
  }

  AppLogger.instance.info('Rollback terminé', {
    'dryRun': dryRun,
    'moderationRestored': moderationRestored,
    'profileSummariesRemoved': profileSummariesRemoved,
  });
}
