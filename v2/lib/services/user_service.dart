import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(ProjectConfig.usersCollection).doc(uid);

  Stream<ViroUser?> watchUser(String uid) {
    return _userRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ViroUser.fromFirestore(doc);
    });
  }

  Future<ViroUser?> getUser(String uid) async {
    final doc = await _userRef(uid).get();
    if (!doc.exists) return null;
    return ViroUser.fromFirestore(doc);
  }

  Future<void> createUserProfile(ViroUser user) async {
    await _userRef(user.uid).set(user.toCreateMap());
  }

  Future<void> addClubMembership({
    required String uid,
    required String clubId,
    required String role,
    bool profileCompleted = true,
  }) async {
    final ref = _userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final existing = (data[FirestoreFields.clubMemberships] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      final alreadyMember = existing.any(
        (m) => m[FirestoreFields.clubId] == clubId,
      );
      if (!alreadyMember) {
        existing.add(
          ClubMembershipSummary(clubId: clubId, role: role).toMap(),
        );
      }

      tx.set(
        ref,
        {
          FirestoreFields.clubMemberships: existing,
          FirestoreFields.flags: {
            FirestoreFields.profileCompleted: profileCompleted,
            FirestoreFields.disabled: false,
          },
          FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
