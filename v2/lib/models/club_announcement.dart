import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

class ClubAnnouncement {
  const ClubAnnouncement({
    required this.id,
    required this.senderId,
    required this.senderFirstName,
    required this.senderLastName,
    required this.message,
    required this.createdAt,
    this.targetType = 'all',
    this.targetIds = const [],
  });

  final String id;
  final String senderId;
  final String senderFirstName;
  final String senderLastName;
  final String message;
  final DateTime createdAt;
  final String targetType;
  final List<String> targetIds;

  String get authorName =>
      '$senderFirstName $senderLastName'.trim();

  factory ClubAnnouncement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ClubAnnouncement(
      id: doc.id,
      senderId: data[FirestoreFields.senderId] as String? ?? '',
      senderFirstName:
          data[FirestoreFields.senderFirstName] as String? ?? '',
      senderLastName: data[FirestoreFields.senderLastName] as String? ?? '',
      message: data[FirestoreFields.message] as String? ?? '',
      createdAt:
          (data[FirestoreFields.createdAt] as Timestamp?)?.toDate() ??
              DateTime.now(),
      targetType: data[FirestoreFields.targetType] as String? ?? 'all',
      targetIds: (data[FirestoreFields.targetIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
    );
  }
}
