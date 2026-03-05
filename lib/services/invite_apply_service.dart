import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/firebase_helpers.dart';
import 'package:viro_team/utils/app_logger.dart';
import 'pending_member_merge_service.dart';

/// Applique un lien d'invitation à un utilisateur déjà connecté :
/// ajout au club, aux équipes, aux événements, suppression du pending_member.
class InviteApplyService {
  InviteApplyService._();
  static final InviteApplyService instance = InviteApplyService._();

  final _db = appFirestore;

  /// Applique l'invite (token, clubId) à l'utilisateur [userId] dont l'email est [userEmail].
  /// Retourne null en cas de succès, sinon un message d'erreur.
  Future<String?> applyInviteForLoggedInUser({
    required String userId,
    required String userEmail,
    required String token,
    required String clubId,
  }) async {
    final emailNorm = userEmail.trim().toLowerCase();
    if (emailNorm.isEmpty) return 'Email utilisateur manquant.';

    try {
      final inviteRef = _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(token);
      final inviteSnap = await inviteRef.get();

      if (!inviteSnap.exists) return 'Lien invalide.';
      final data = inviteSnap.data()!;
      final usedAt = data['usedAt'] as Timestamp?;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (usedAt != null) return 'Ce lien a déjà été utilisé.';
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        return 'Ce lien a expiré.';
      }

      final inviteEmail = (data['email'] as String? ?? '').trim().toLowerCase();
      if (inviteEmail.isEmpty) return 'Lien invalide.';
      if (inviteEmail != emailNorm) {
        return 'Cette invitation est pour $inviteEmail. Vous êtes connecté avec un autre compte.';
      }

      final pendingMemberId = data['pendingMemberId'] as String? ?? '';
      if (pendingMemberId.isEmpty) return 'Lien invalide.';

      final teamsRaw = data['teams'] as List? ?? [];
      final teams = teamsRaw
          .map((e) => e is Map<String, dynamic>
              ? e
              : (e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          .toList();

      final userRef = _db.collection(FirebaseCollections.users).doc(userId);

      for (final t in teams) {
        final teamId = t['teamId'] as String? ?? '';
        final teamName = t['teamName'] as String? ?? '';
        final teamCategory = t['category'] as String? ?? '';
        if (teamId.isEmpty) continue;
        await updatePlayerClubsForTeam(
          _db,
          userId,
          clubId,
          add: true,
          teamId: teamId,
          teamName: teamName,
          teamCategory: teamCategory,
        );
      }

      await userRef.set({
        'activeContext': {
          'role': 'player',
          'clubId': clubId,
        },
      }, SetOptions(merge: true));

      await _db.collection(FirebaseCollections.clubs).doc(clubId).update({
        'members': FieldValue.arrayUnion([userId]),
      });

      for (final t in teams) {
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

      for (final t in teams) {
        final teamName = t['teamName'] as String? ?? '';
        if (teamName.isEmpty) continue;
        await _addUserToEventsForTeam(
          clubId,
          teamName,
          userId,
          replacePendingMemberId: pendingMemberId,
        );
      }

      await _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.pendingMembers)
          .doc(pendingMemberId)
          .delete();

      await inviteRef.update({'usedAt': FieldValue.serverTimestamp()});

      try {
        await PendingMemberMergeService.instance
            .mergePendingMembersForUser(userId, emailNorm);
      } catch (_) {}

      AppLogger.instance.info(
        'Invite appliquée pour utilisateur connecté',
        {'userId': userId, 'clubId': clubId, 'pendingMemberId': pendingMemberId},
      );
      return null;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur application invite (utilisateur connecté)',
        error: e,
        context: {'userId': userId, 'clubId': clubId},
      );
      return e.toString();
    }
  }

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
