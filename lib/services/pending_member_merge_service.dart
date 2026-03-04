import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Lorsqu'un utilisateur rejoint un club (join request acceptée ou inscription via invite),
/// on vérifie s'il existe des [pending_members] (dans n'importe quel club) avec le même email.
/// Si oui, on fusionne toutes les infos (club, équipes, événements) sur l'utilisateur
/// et on supprime les entrées pending_members.
class PendingMemberMergeService {
  PendingMemberMergeService._();
  static final PendingMemberMergeService instance = PendingMemberMergeService._();

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

      // Fusionner le club et les équipes dans le profil joueur
      final userRef = _db.collection(FirebaseCollections.users).doc(userId);
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

      Map<String, dynamic>? clubEntry;
      for (var c in clubsList) {
        if (c['clubId'] == clubId) {
          clubEntry = c;
          break;
        }
      }

      if (clubEntry == null) {
        clubEntry = {
          'clubId': clubId,
          'teamIds': <String>[],
          'teamNames': <String>[],
          'categories': <String>[],
        };
        clubsList.add(clubEntry);
      }

      final teamIds = List<String>.from((clubEntry['teamIds'] as List?)?.whereType<String>() ?? []);
      final teamNames = List<String>.from((clubEntry['teamNames'] as List?)?.whereType<String>() ?? []);
      final categories = List<String>.from((clubEntry['categories'] as List?)?.whereType<String>() ?? []);

      for (final t in teamInfos) {
        final tid = t['teamId'] as String? ?? '';
        final tname = t['teamName'] as String? ?? '';
        final tcat = t['teamCategory'] as String? ?? '';
        if (tid.isEmpty) continue;
        if (!teamIds.contains(tid)) teamIds.add(tid);
        if (tname.isNotEmpty && !teamNames.contains(tname)) teamNames.add(tname);
        if (tcat.isNotEmpty && !categories.contains(tcat)) categories.add(tcat);
      }

      clubEntry['teamIds'] = teamIds;
      clubEntry['teamNames'] = teamNames;
      clubEntry['categories'] = categories;

      final updatedRoles = Map<String, dynamic>.from(roles);
      updatedRoles['player'] = {...playerData, 'clubs': clubsList};

      await userRef.set({
        'roles': updatedRoles,
      }, SetOptions(merge: true));

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

      // Ajouter l'utilisateur aux événements des équipes (teamMemberIds + attendance)
      for (final t in teamInfos) {
        final teamName = t['teamName'] as String? ?? '';
        if (teamName.isEmpty) continue;
        await _addUserToEventsForTeam(clubId, teamName, userId);
      }

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

  /// Ajoute [userId] à tous les événements du club concernant l'équipe [teamName].
  Future<void> _addUserToEventsForTeam(
    String clubId,
    String teamName,
    String userId,
  ) async {
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
      }
    }
  }
}
