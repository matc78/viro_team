import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

class JoinRequestService {
  JoinRequestService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  Future<void> createRoleChangeRequest({
    required ViroUser user,
    required Club club,
    required String currentRole,
    required String roleRequested,
    String message = '',
  }) async {
    if (currentRole == roleRequested) {
      throw StateError('Vous avez déjà ce rôle.');
    }

    await _db.collection(ProjectConfig.joinRequestsCollection).add({
      FirestoreFields.userId: user.uid,
      FirestoreFields.clubId: club.id,
      FirestoreFields.clubName: club.name,
      FirestoreFields.clubSport: club.sport,
      FirestoreFields.roleRequested: roleRequested,
      FirestoreFields.firstName: user.firstName,
      FirestoreFields.lastName: user.lastName,
      if (user.phone != null) FirestoreFields.phone: user.phone,
      FirestoreFields.message: message,
      FirestoreFields.status: JoinRequestStatus.pending,
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}
