import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/club_setup/models/club_setup_draft.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/services/retour_user_service.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

class ClubService {
  ClubService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    RetourUserService? retourUserService,
  })  : _db = firestore ?? appFirestore,
        _storage = storage ?? FirebaseStorage.instance,
        _retourUser = retourUserService ?? RetourUserService(firestore: firestore);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final RetourUserService _retourUser;

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection(ProjectConfig.clubsCollection);

  Future<Club?> getClub(String clubId) async {
    final doc = await _clubs.doc(clubId).get();
    if (!doc.exists) return null;
    return Club.fromFirestore(doc);
  }

  Future<List<Club>> getClubsForUser(ViroUser user) async {
    return getClubsByIds(user.clubMemberships.map((m) => m.clubId).toList());
  }

  Future<List<Club>> getClubsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final results = <Club>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap = await _clubs
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map(Club.fromFirestore));
    }
    return results;
  }

  Future<String> createClubFromDraft({
    required String founderUid,
    required ViroUser founder,
    required ClubSetupDraft draft,
  }) async {
    final clubRef = _clubs.doc();
    final memberRef = clubRef
        .collection(ProjectConfig.membersSubcollection)
        .doc(founderUid);
    final userRef =
        _db.collection(ProjectConfig.usersCollection).doc(founderUid);

    String? logoUrl;
    if (draft.logoBytes != null) {
      try {
        final storageRef =
            _storage.ref().child('clubs/${clubRef.id}/logo.jpg');
        await storageRef.putData(
          draft.logoBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        logoUrl = await storageRef.getDownloadURL();
      } catch (_) {
        // Logo optionnel — ne bloque pas la création du club.
      }
    }

    final displayName = founder.displayName.isNotEmpty
        ? founder.displayName
        : '${founder.firstName} ${founder.lastName}'.trim();

    await _db.runTransaction((tx) async {
      // Firestore : toutes les lectures avant les écritures.
      final userSnap = await tx.get(userRef);
      final data = userSnap.data() ?? {};
      final memberships = (data[FirestoreFields.clubMemberships]
                  as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      memberships.add(
        ClubMembershipSummary(
          clubId: clubRef.id,
          role: MemberRoles.admin,
        ).toMap(),
      );

      tx.set(clubRef, {
        FirestoreFields.name: draft.name.trim(),
        FirestoreFields.sport: draft.sport,
        FirestoreFields.city: draft.city.trim(),
        FirestoreFields.postalCode: draft.postalCode.trim(),
        FirestoreFields.address: draft.address.trim(),
        if (draft.description.trim().isNotEmpty)
          FirestoreFields.description: draft.description.trim(),
        if (logoUrl != null) FirestoreFields.logoUrl: logoUrl,
        if (draft.brandColorHex != null)
          FirestoreFields.brandColorHex: draft.brandColorHex,
        FirestoreFields.practiceLocations:
            draft.practiceLocations.map((l) => l.toMap()).toList(),
        FirestoreFields.adminIds: [founderUid],
        FirestoreFields.memberCount: 1,
        FirestoreFields.createdAt: FieldValue.serverTimestamp(),
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      });

      tx.set(memberRef, {
        FirestoreFields.memberId: founderUid,
        FirestoreFields.accountUid: founderUid,
        FirestoreFields.userId: founderUid,
        FirestoreFields.firstName: founder.firstName,
        FirestoreFields.lastName: founder.lastName,
        FirestoreFields.role: MemberRoles.admin,
        FirestoreFields.status: 'active',
        FirestoreFields.teamIds: <String>[],
        FirestoreFields.snapshot: {
          FirestoreFields.displayName: displayName,
          FirestoreFields.email: founder.email,
          if (founder.avatarUrl != null)
            FirestoreFields.avatarUrl: founder.avatarUrl,
        },
        FirestoreFields.joinedAt: FieldValue.serverTimestamp(),
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      });

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
    });

    try {
      await _retourUser.saveClubSetupObjectives(
        userId: founderUid,
        clubId: clubRef.id,
        objectiveKeys: draft.objectives,
        clubName: draft.name.trim(),
        clubSport: draft.sport,
      );
    } catch (_) {
      // Objectifs déjà créés côté club ; retour_user optionnel si règles non déployées.
    }

    return clubRef.id;
  }
}
