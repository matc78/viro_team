import 'package:viro_team_v2/constants/firestore_fields.dart';

class ClubMembershipSummary {
  const ClubMembershipSummary({
    required this.clubId,
    required this.role,
  });

  final String clubId;
  final String role;

  factory ClubMembershipSummary.fromMap(Map<String, dynamic> map) {
    return ClubMembershipSummary(
      clubId: map[FirestoreFields.clubId] as String? ?? '',
      role: map[FirestoreFields.role] as String? ?? MemberRoles.player,
    );
  }

  Map<String, dynamic> toMap() => {
        FirestoreFields.clubId: clubId,
        FirestoreFields.role: role,
      };
}
