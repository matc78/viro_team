import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

class ClubInvitation {
  const ClubInvitation({
    required this.id,
    required this.clubId,
    required this.code,
    required this.role,
    required this.status,
    this.memberId,
    this.email,
    this.sentBy,
    this.sentAt,
    this.expiresAt,
    this.acceptedAt,
    this.clubName,
    this.clubSport,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String clubId;
  final String code;
  final String role;
  final String status;
  final String? memberId;
  final String? email;
  final String? sentBy;
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? clubName;
  final String? clubSport;
  final String? firstName;
  final String? lastName;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isPending =>
      status == InvitationStatus.pending && !isExpired;

  factory ClubInvitation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ClubInvitation(
      id: doc.id,
      clubId: doc.reference.parent.parent?.id ?? '',
      code: data[FirestoreFields.code] as String? ?? '',
      role: data[FirestoreFields.role] as String? ?? MemberRoles.player,
      status: data[FirestoreFields.status] as String? ?? InvitationStatus.pending,
      memberId: data[FirestoreFields.memberId] as String?,
      email: data[FirestoreFields.email] as String?,
      sentBy: data[FirestoreFields.sentBy] as String?,
      sentAt: (data[FirestoreFields.sentAt] as Timestamp?)?.toDate(),
      expiresAt: (data[FirestoreFields.expiresAt] as Timestamp?)?.toDate(),
      acceptedAt: (data[FirestoreFields.acceptedAt] as Timestamp?)?.toDate(),
      clubName: data[FirestoreFields.clubName] as String?,
      clubSport: data[FirestoreFields.clubSport] as String?,
      firstName: data[FirestoreFields.firstName] as String?,
      lastName: data[FirestoreFields.lastName] as String?,
    );
  }

  factory ClubInvitation.fromQuery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ClubInvitation(
      id: doc.id,
      clubId: doc.reference.parent.parent?.id ?? '',
      code: data[FirestoreFields.code] as String? ?? '',
      role: data[FirestoreFields.role] as String? ?? MemberRoles.player,
      status: data[FirestoreFields.status] as String? ?? InvitationStatus.pending,
      memberId: data[FirestoreFields.memberId] as String?,
      email: data[FirestoreFields.email] as String?,
      sentBy: data[FirestoreFields.sentBy] as String?,
      sentAt: (data[FirestoreFields.sentAt] as Timestamp?)?.toDate(),
      expiresAt: (data[FirestoreFields.expiresAt] as Timestamp?)?.toDate(),
      acceptedAt: (data[FirestoreFields.acceptedAt] as Timestamp?)?.toDate(),
      clubName: data[FirestoreFields.clubName] as String?,
      clubSport: data[FirestoreFields.clubSport] as String?,
      firstName: data[FirestoreFields.firstName] as String?,
      lastName: data[FirestoreFields.lastName] as String?,
    );
  }
}
