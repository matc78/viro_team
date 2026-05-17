import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

class ClubMember {
  const ClubMember({
    required this.memberId,
    required this.role,
    required this.status,
    this.accountUid,
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.teamIds = const [],
    this.joinedAt,
    this.activeInvitationId,
    this.pendingInviteCode,
    this.pendingInviteExpiresAt,
    this.hasLinkedAccount = false,
    this.dismissedAnnouncementIds = const [],
  });

  /// ID stable du document `members/{memberId}`.
  final String memberId;

  /// UID Firebase Auth si le membre a créé son compte.
  final String? accountUid;

  final String role;
  final String status;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  final List<String> teamIds;
  final DateTime? joinedAt;
  final String? activeInvitationId;
  final String? pendingInviteCode;
  final DateTime? pendingInviteExpiresAt;

  /// `true` si un compte utilisateur est lié (users.createdAt présent).
  final bool hasLinkedAccount;

  /// Annonces masquées par le membre sur la home (croix).
  final List<String> dismissedAnnouncementIds;

  /// Compatibilité : identifiant utilisé pour RSVP/events (accountUid ou memberId).
  String get effectiveUid => accountUid ?? memberId;

  /// @deprecated Utiliser [memberId] ou [accountUid].
  String get userId => accountUid ?? memberId;

  bool get isActive => status == 'active';

  String get fullName {
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return displayName ?? '';
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool get hasPendingInvite =>
      pendingInviteCode != null &&
      pendingInviteCode!.isNotEmpty &&
      (pendingInviteExpiresAt == null ||
          DateTime.now().isBefore(pendingInviteExpiresAt!));

  /// Joueur invité sans compte (`pending_members`) affiché dans un roster.
  factory ClubMember.fromPendingRoster({
    required String pendingId,
    required String firstName,
    required String lastName,
  }) {
    return ClubMember(
      memberId: pendingId,
      role: MemberRoles.player,
      status: 'active',
      firstName: firstName,
      lastName: lastName,
      hasLinkedAccount: false,
    );
  }

  factory ClubMember.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final snapshot =
        data[FirestoreFields.snapshot] as Map<String, dynamic>? ?? {};

    final firstName = data[FirestoreFields.firstName] as String?;
    final lastName = data[FirestoreFields.lastName] as String?;
    final snapshotName = snapshot[FirestoreFields.displayName] as String?;
    final displayName = snapshotName ??
        (firstName != null || lastName != null
            ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
            : null);

    // Legacy : fondateurs / membres inscrits avant accountUid utilisaient userId.
    final legacyUserId = data[FirestoreFields.userId] as String?;
    final accountUid = data[FirestoreFields.accountUid] as String? ??
        (legacyUserId != null && legacyUserId.isNotEmpty
            ? legacyUserId
            : null);

    return ClubMember(
      memberId: data[FirestoreFields.memberId] as String? ?? doc.id,
      accountUid: accountUid,
      role: data[FirestoreFields.role] as String? ?? MemberRoles.player,
      status: data[FirestoreFields.status] as String? ?? 'active',
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      avatarUrl: snapshot[FirestoreFields.avatarUrl] as String?,
      email: snapshot[FirestoreFields.email] as String?,
      teamIds: (data[FirestoreFields.teamIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      joinedAt: (data[FirestoreFields.joinedAt] as Timestamp?)?.toDate(),
      activeInvitationId:
          data[FirestoreFields.activeInvitationId] as String?,
      dismissedAnnouncementIds:
          (data[FirestoreFields.dismissedAnnouncementIds] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [],
    );
  }

  ClubMember copyWith({
    String? accountUid,
    bool? hasLinkedAccount,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? pendingInviteCode,
    DateTime? pendingInviteExpiresAt,
    String? role,
  }) {
    return ClubMember(
      memberId: memberId,
      accountUid: accountUid ?? this.accountUid,
      role: role ?? this.role,
      status: status,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      teamIds: teamIds,
      joinedAt: joinedAt,
      activeInvitationId: activeInvitationId,
      pendingInviteCode: pendingInviteCode ?? this.pendingInviteCode,
      pendingInviteExpiresAt:
          pendingInviteExpiresAt ?? this.pendingInviteExpiresAt,
      hasLinkedAccount: hasLinkedAccount ?? this.hasLinkedAccount,
    );
  }
}
