import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/announcements/announcement_target_types.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

class AnnouncementService {
  AnnouncementService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _announcements(String clubId) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.announcementsSubcollection);

  DocumentReference<Map<String, dynamic>> _memberRef(
    String clubId,
    String memberId,
  ) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.membersSubcollection)
          .doc(memberId);

  Stream<List<ClubAnnouncement>> watchAnnouncements({
    required String clubId,
    int limit = 50,
  }) {
    return _announcements(clubId)
        .orderBy(FirestoreFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ClubAnnouncement.fromFirestore(clubId: clubId, doc: d),
              )
              .toList(),
        );
  }

  Stream<Set<String>> watchDismissedAnnouncementIds({
    required String clubId,
    required String memberId,
  }) {
    return _memberRef(clubId, memberId).snapshots().map((doc) {
      if (!doc.exists) return <String>{};
      final data = doc.data() ?? {};
      final ids = data[FirestoreFields.dismissedAnnouncementIds]
          as List<dynamic>?;
      return ids?.whereType<String>().toSet() ?? {};
    });
  }

  Future<void> createAnnouncement({
    required String clubId,
    required String senderId,
    required String senderFirstName,
    required String senderLastName,
    required String message,
    required String targetType,
    required List<String> targetIds,
  }) async {
    await _announcements(clubId).add({
      FirestoreFields.senderId: senderId,
      FirestoreFields.senderFirstName: senderFirstName,
      FirestoreFields.senderLastName: senderLastName,
      FirestoreFields.message: message.trim(),
      FirestoreFields.targetType: targetType,
      FirestoreFields.targetIds: targetType == AnnouncementTargetTypes.tousLesMembres
          ? <String>[]
          : targetIds,
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAnnouncement({
    required String clubId,
    required String announcementId,
    required String message,
  }) async {
    await _announcements(clubId).doc(announcementId).update({
      FirestoreFields.message: message.trim(),
    });
  }

  Future<void> deleteAnnouncement({
    required String clubId,
    required String announcementId,
  }) async {
    await _announcements(clubId).doc(announcementId).delete();
  }

  Future<void> dismissAnnouncement({
    required String clubId,
    required String memberId,
    required String announcementId,
  }) async {
    await _memberRef(clubId, memberId).update({
      FirestoreFields.dismissedAnnouncementIds:
          FieldValue.arrayUnion([announcementId]),
    });
  }
}
