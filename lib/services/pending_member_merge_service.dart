import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/app_logger.dart';
import 'package:viro_team/services/membership_service.dart';

/// Lorsqu'un utilisateur rejoint un club (join request acceptée ou inscription via invite),
/// on vérifie s'il existe des [pending_members] (dans n'importe quel club) avec le même email.
/// Si oui, on fusionne toutes les infos (club, équipes, événements) sur l'utilisateur
/// et on supprime les entrées pending_members.
class PendingMemberMergeService {
  PendingMemberMergeService._();
  static final PendingMemberMergeService instance = PendingMemberMergeService._();

  static const String _feeMigrationMarkerField = '_migratedFromPendingId';

  final FirebaseFirestore _db = appFirestore;

  /// À appeler après qu'un utilisateur a rejoint un club (acceptation demande ou signup invite).
  /// Cherche tous les pending_members dont l'email correspond, fusionne club/équipes/events
  /// sur l'utilisateur et supprime les pending_members.
  Future<void> mergePendingMembersForUser(String userId, String userEmail) async {
    final emailNorm = userEmail.trim().toLowerCase();
    if (emailNorm.isEmpty) return;

    QuerySnapshot<Map<String, dynamic>> pendingSnap;
    try {
      pendingSnap = await _db
          .collectionGroup(FirebaseCollections.pendingMembers)
          .where('email', isEqualTo: emailNorm)
          .get();
    } catch (e) {
      AppLogger.instance.error(
        'Erreur requête pending_members par email',
        error: e,
        context: {'userId': userId, 'email': emailNorm},
      );
      return;
    }

    if (pendingSnap.docs.isEmpty) return;

    for (final doc in pendingSnap.docs) {
      final ref = doc.reference;
      // Chemin: clubs/{clubId}/pending_members/{pendingMemberId}
      if (ref.path.split('/').length < 4) continue;
      final clubId = ref.parent.parent?.id;
      final pendingMemberId = ref.id;
      if (clubId == null || clubId.isEmpty) continue;

      await _mergeOnePendingMember(
        userId: userId,
        clubId: clubId,
        pendingMemberId: pendingMemberId,
      );
    }
  }

  Future<void> _mergeOnePendingMember({
    required String userId,
    required String clubId,
    required String pendingMemberId,
  }) async {
    try {
      // Équipes du club qui contiennent ce pending
      final teamsSnap = await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .where('pendingPlayerIds', arrayContains: pendingMemberId)
          .get();

      final List<Map<String, dynamic>> teamInfos = [];
      for (final teamDoc in teamsSnap.docs) {
        final d = teamDoc.data();
        teamInfos.add({
          'teamId': teamDoc.id,
          'teamName': (d['name'] as String?) ?? '',
          'teamCategory': (d['category'] as String?) ?? '',
        });
      }

      // Fusionner le club et les équipes : member + profileSummaries (plus d'écriture roles sur le user)
      final teamIds = teamInfos
          .map((t) => t['teamId'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final teamNames = teamInfos
          .map((t) => t['teamName'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final categories = teamInfos
          .map((t) => t['teamCategory'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      await MembershipService.instance.ensureMemberAndProfileSummary(
        uid: userId,
        clubId: clubId,
        role: 'player',
        playerTeamIds: teamIds,
        playerTeamNames: teamNames,
        playerCategories: categories,
      );

      // Ajouter l'utilisateur aux members du club
      await _db.collection(FirebaseCollections.clubs).doc(clubId).update({
        'members': FieldValue.arrayUnion([userId]),
      });

      // Mettre à jour chaque équipe : ajouter userId, retirer pending
      for (final t in teamInfos) {
        final teamId = t['teamId'] as String?;
        if (teamId == null || teamId.isEmpty) continue;
        final teamRef = _db
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.teams)
            .doc(teamId);
        await teamRef.update({
          'playerIds': FieldValue.arrayUnion([userId]),
          'pendingPlayerIds': FieldValue.arrayRemove([pendingMemberId]),
          'teamMemberIds': FieldValue.arrayUnion([userId]),
        });
      }

      // Ajouter l'utilisateur aux événements des équipes et retirer l'ancien pendingMemberId
      for (final t in teamInfos) {
        final teamName = t['teamName'] as String? ?? '';
        if (teamName.isEmpty) continue;
        await _addUserToEventsForTeam(
          clubId,
          teamName,
          userId,
          replacePendingMemberId: pendingMemberId,
        );
      }

      await _migrateFeeRecords(
        clubId: clubId,
        fromId: pendingMemberId,
        toId: userId,
      );

      // Supprimer le pending_member
      await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.pendingMembers)
          .doc(pendingMemberId)
          .delete();

      AppLogger.instance.info(
        'Pending member fusionné avec l\'utilisateur',
        {
          'userId': userId,
          'clubId': clubId,
          'pendingMemberId': pendingMemberId,
          'teamsCount': teamInfos.length,
        },
      );
    } catch (e) {
      AppLogger.instance.error(
        'Erreur fusion pending_member',
        error: e,
        context: {
          'userId': userId,
          'clubId': clubId,
          'pendingMemberId': pendingMemberId,
        },
      );
      rethrow;
    }
  }

  Future<void> _migrateFeeRecords({
    required String clubId,
    required String fromId,
    required String toId,
  }) async {
    final seasonsSnap = await _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.feeSeasons)
        .get();

    for (final seasonDoc in seasonsSnap.docs) {
      final sourceRef = seasonDoc.reference
          .collection(FirebaseCollections.memberFees)
          .doc(fromId);
      final targetRef = seasonDoc.reference
          .collection(FirebaseCollections.memberFees)
          .doc(toId);

      final outcome = await _db.runTransaction<_FeeMigrationOutcome>((
        transaction,
      ) async {
        final sourceSnap = await transaction.get(sourceRef);
        if (!sourceSnap.exists) {
          return _FeeMigrationOutcome.notFound;
        }

        final targetSnap = await transaction.get(targetRef);
        if (targetSnap.exists) {
          transaction.delete(sourceRef);
          return _FeeMigrationOutcome.conflictKeptTarget;
        }

        final sourceData = sourceSnap.data();
        if (sourceData == null) {
          return _FeeMigrationOutcome.notFound;
        }

        transaction.set(targetRef, {
          ...sourceData,
          _feeMigrationMarkerField: fromId,
        });
        transaction.delete(sourceRef);
        return _FeeMigrationOutcome.migrated;
      });

      if (outcome == _FeeMigrationOutcome.migrated) {
        await targetRef.update({_feeMigrationMarkerField: FieldValue.delete()});
        AppLogger.instance.info(
          'Cotisation migrée depuis pending_member',
          {
            'clubId': clubId,
            'seasonId': seasonDoc.id,
            'fromId': fromId,
            'toId': toId,
          },
        );
      } else if (outcome == _FeeMigrationOutcome.conflictKeptTarget) {
        AppLogger.instance.warning(
          'Conflit cotisation pendant fusion pending_member: cible conservée',
          {
            'clubId': clubId,
            'seasonId': seasonDoc.id,
            'fromId': fromId,
            'toId': toId,
          },
        );
      }
    }
  }

  /// Ajoute [userId] à tous les événements du club concernant l'équipe [teamName].
  /// Si [replacePendingMemberId] est fourni, le retire des teamMemberIds et de attendance.
  Future<void> _addUserToEventsForTeam(
    String clubId,
    String teamName,
    String userId, {
    String? replacePendingMemberId,
  }) async {
    if (teamName.isEmpty) return;
    final eventsRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events);

    final List<QuerySnapshot<Map<String, dynamic>>> snaps = await Future.wait([
      eventsRef.where('teamName', isEqualTo: teamName).get(),
      eventsRef.where('teamNames', arrayContains: teamName).get(),
      eventsRef.where('allTeams', isEqualTo: true).get(),
    ]);

    final seen = <String>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        await doc.reference.set({
          'teamMemberIds': FieldValue.arrayUnion([userId]),
          'attendance.$userId': 'none',
        }, SetOptions(merge: true));

        if (replacePendingMemberId != null &&
            replacePendingMemberId.isNotEmpty) {
          await doc.reference.update({
            'teamMemberIds': FieldValue.arrayRemove([replacePendingMemberId]),
            'attendance.$replacePendingMemberId': FieldValue.delete(),
          });
        }
      }
    }
  }
}

enum _FeeMigrationOutcome {
  notFound,
  migrated,
  conflictKeptTarget,
}
