import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';

class ViroUser {
  const ViroUser({
    required this.uid,
    required this.email,
    required this.emailNorm,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.phone,
    this.avatarUrl,
    this.clubMemberships = const [],
    this.profileCompleted = false,
    this.disabled = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String emailNorm;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? phone;
  final String? avatarUrl;
  final List<ClubMembershipSummary> clubMemberships;
  final bool profileCompleted;
  final bool disabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasClubs => clubMemberships.isNotEmpty;

  factory ViroUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final flags = data[FirestoreFields.flags] as Map<String, dynamic>? ?? {};
    final membershipsRaw =
        data[FirestoreFields.clubMemberships] as List<dynamic>? ?? [];

    return ViroUser(
      uid: data[FirestoreFields.uid] as String? ?? doc.id,
      email: data[FirestoreFields.email] as String? ?? '',
      emailNorm: data[FirestoreFields.emailNorm] as String? ?? '',
      firstName: data[FirestoreFields.firstName] as String? ?? '',
      lastName: data[FirestoreFields.lastName] as String? ?? '',
      displayName: data[FirestoreFields.displayName] as String? ?? '',
      phone: data[FirestoreFields.phone] as String?,
      avatarUrl: data[FirestoreFields.avatarUrl] as String?,
      clubMemberships: membershipsRaw
          .whereType<Map<String, dynamic>>()
          .map(ClubMembershipSummary.fromMap)
          .toList(),
      profileCompleted:
          flags[FirestoreFields.profileCompleted] as bool? ?? false,
      disabled: flags[FirestoreFields.disabled] as bool? ?? false,
      createdAt: (data[FirestoreFields.createdAt] as Timestamp?)?.toDate(),
      updatedAt: (data[FirestoreFields.updatedAt] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    final now = FieldValue.serverTimestamp();
    return {
      FirestoreFields.uid: uid,
      FirestoreFields.email: email,
      FirestoreFields.emailNorm: emailNorm,
      FirestoreFields.firstName: firstName,
      FirestoreFields.lastName: lastName,
      FirestoreFields.displayName: displayName,
      if (phone != null) FirestoreFields.phone: phone,
      FirestoreFields.clubMemberships: <Map<String, dynamic>>[],
      FirestoreFields.flags: {
        FirestoreFields.profileCompleted: profileCompleted,
        FirestoreFields.disabled: disabled,
      },
      FirestoreFields.createdAt: now,
      FirestoreFields.updatedAt: now,
    };
  }
}
