import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_invitation.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

class InvitationLookupResult {
  const InvitationLookupResult({
    required this.invitation,
    required this.club,
  });

  final ClubInvitation invitation;
  final Club club;
}

class InvitationService {
  InvitationService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  Future<InvitationLookupResult?> findByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    final snap = await _db
        .collectionGroup(ProjectConfig.invitationsSubcollection)
        .where(FirestoreFields.code, isEqualTo: code)
        .where(FirestoreFields.status, isEqualTo: InvitationStatus.pending)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final inviteDoc = snap.docs.first;
    var invitation = ClubInvitation.fromQuery(inviteDoc);
    if (!invitation.isPending) return null;

    final clubDoc = await _db
        .collection(ProjectConfig.clubsCollection)
        .doc(invitation.clubId)
        .get();
    if (!clubDoc.exists) return null;

    final club = Club.fromFirestore(clubDoc);
    invitation = ClubInvitation(
      id: invitation.id,
      clubId: invitation.clubId,
      code: invitation.code,
      role: invitation.role,
      status: invitation.status,
      memberId: invitation.memberId,
      email: invitation.email,
      sentBy: invitation.sentBy,
      sentAt: invitation.sentAt,
      expiresAt: invitation.expiresAt,
      acceptedAt: invitation.acceptedAt,
      clubName: club.name,
      clubSport: club.sport,
    );

    return InvitationLookupResult(invitation: invitation, club: club);
  }

  Future<void> acceptInvitation({
    required ClubInvitation invitation,
    required ViroUser user,
  }) async {
    if (invitation.email != null &&
        invitation.email!.trim().toLowerCase() !=
            user.emailNorm.trim().toLowerCase()) {
      throw StateError('Cette invitation est réservée à un autre email.');
    }

    final clubRef =
        _db.collection(ProjectConfig.clubsCollection).doc(invitation.clubId);
    final inviteRef = clubRef
        .collection(ProjectConfig.invitationsSubcollection)
        .doc(invitation.id);
    final userRef =
        _db.collection(ProjectConfig.usersCollection).doc(user.uid);

    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : '${user.firstName} ${user.lastName}'.trim();

    final linkedMemberId = invitation.memberId;
    final memberRef = linkedMemberId != null && linkedMemberId.isNotEmpty
        ? clubRef
            .collection(ProjectConfig.membersSubcollection)
            .doc(linkedMemberId)
        : clubRef
            .collection(ProjectConfig.membersSubcollection)
            .doc(user.uid);

    final accountIndexRef = clubRef
        .collection(ProjectConfig.memberAccountsSubcollection)
        .doc(user.uid);

    await _db.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      final memberSnap = await tx.get(memberRef);
      final clubSnap = await tx.get(clubRef);
      final userSnap = await tx.get(userRef);

      if (!inviteSnap.exists) {
        throw StateError('Invitation introuvable.');
      }
      final inviteData = inviteSnap.data()!;
      if (inviteData[FirestoreFields.status] != InvitationStatus.pending) {
        throw StateError('Invitation déjà utilisée.');
      }

      final expiresAt =
          (inviteData[FirestoreFields.expiresAt] as Timestamp?)?.toDate();
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw StateError('Invitation expirée.');
      }

      final isPreCreatedMember =
          linkedMemberId != null && linkedMemberId.isNotEmpty;

      if (isPreCreatedMember) {
        if (!memberSnap.exists) {
          throw StateError('Membre du club introuvable.');
        }
        tx.update(memberRef, {
          FirestoreFields.accountUid: user.uid,
          FirestoreFields.userId: user.uid,
          FirestoreFields.snapshot: {
            FirestoreFields.displayName: displayName,
            FirestoreFields.email: user.email,
            if (user.avatarUrl != null)
              FirestoreFields.avatarUrl: user.avatarUrl,
          },
          FirestoreFields.activeInvitationId: FieldValue.delete(),
          FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        });

        tx.set(accountIndexRef, {
          FirestoreFields.linkedMemberId: linkedMemberId,
        });
      } else {
        final createMember = !memberSnap.exists;
        if (createMember) {
          tx.set(memberRef, {
            FirestoreFields.memberId: user.uid,
            FirestoreFields.accountUid: user.uid,
            FirestoreFields.userId: user.uid,
            FirestoreFields.firstName: user.firstName,
            FirestoreFields.lastName: user.lastName,
            FirestoreFields.role: invitation.role,
            FirestoreFields.status: 'active',
            FirestoreFields.teamIds: <String>[],
            FirestoreFields.snapshot: {
              FirestoreFields.displayName: displayName,
              FirestoreFields.email: user.email,
              if (user.avatarUrl != null)
                FirestoreFields.avatarUrl: user.avatarUrl,
            },
            if (invitation.role == MemberRoles.player)
              FirestoreFields.playerInfo: {FirestoreFields.license: ''},
            if (invitation.role == MemberRoles.coach)
              FirestoreFields.coachInfo: {'headCoach': false},
            FirestoreFields.joinedAt: FieldValue.serverTimestamp(),
            FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          });

          final memberCount =
              (clubSnap.data()?[FirestoreFields.memberCount] as num?)
                      ?.toInt() ??
                  0;
          tx.update(clubRef, {
            FirestoreFields.memberCount: memberCount + 1,
            FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      if (invitation.role == MemberRoles.admin) {
        final adminIds = (clubSnap.data()?[FirestoreFields.adminIds]
                    as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            [];
        if (!adminIds.contains(user.uid)) {
          adminIds.add(user.uid);
          tx.update(clubRef, {
            FirestoreFields.adminIds: adminIds,
            FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      final userData = userSnap.data() ?? {};
      final memberships = (userData[FirestoreFields.clubMemberships]
                  as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final already = memberships.any(
        (m) => m[FirestoreFields.clubId] == invitation.clubId,
      );
      if (!already) {
        memberships.add(
          ClubMembershipSummary(
            clubId: invitation.clubId,
            role: invitation.role,
          ).toMap(),
        );
        tx.set(
          userRef,
          {
            FirestoreFields.clubMemberships: memberships,
            FirestoreFields.flags: {
              FirestoreFields.profileCompleted: true,
              FirestoreFields.disabled: false,
            },
            FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      tx.update(inviteRef, {
        FirestoreFields.status: InvitationStatus.accepted,
        FirestoreFields.acceptedAt: FieldValue.serverTimestamp(),
        'acceptedBy': user.uid,
      });
    });
  }

  /// Invitations en attente adressées à l'email de l'utilisateur (collection group).
  Future<List<ClubInvitation>> getPendingInvitationsForEmail(
    String email,
  ) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final snap = await _db
        .collectionGroup(ProjectConfig.invitationsSubcollection)
        .where(FirestoreFields.email, isEqualTo: normalized)
        .where(FirestoreFields.status, isEqualTo: InvitationStatus.pending)
        .get();

    final invites = <ClubInvitation>[];
    for (final doc in snap.docs) {
      var invitation = ClubInvitation.fromQuery(doc);
      if (!invitation.isPending) continue;

      final clubDoc = await _db
          .collection(ProjectConfig.clubsCollection)
          .doc(invitation.clubId)
          .get();
      if (!clubDoc.exists) continue;

      final club = Club.fromFirestore(clubDoc);
      invites.add(
        ClubInvitation(
          id: invitation.id,
          clubId: invitation.clubId,
          code: invitation.code,
          role: invitation.role,
          status: invitation.status,
          memberId: invitation.memberId,
          email: invitation.email,
          sentBy: invitation.sentBy,
          sentAt: invitation.sentAt,
          expiresAt: invitation.expiresAt,
          acceptedAt: invitation.acceptedAt,
          clubName: club.name,
          clubSport: club.sport,
        ),
      );
    }

    invites.sort((a, b) {
      final at = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return invites;
  }

  Future<void> declineInvitation(ClubInvitation invitation) async {
    await _db
        .collection(ProjectConfig.clubsCollection)
        .doc(invitation.clubId)
        .collection(ProjectConfig.invitationsSubcollection)
        .doc(invitation.id)
        .update({
      FirestoreFields.status: InvitationStatus.declined,
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}
