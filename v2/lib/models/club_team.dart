import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

class ClubTeam {
  const ClubTeam({
    required this.id,
    required this.clubId,
    required this.name,
    this.category,
    this.avatarUrl,
    this.playerIds = const [],
    this.coachIds = const [],
    this.pendingPlayerIds = const [],
    this.messagingLink,
    this.parentsMessagingLink,
  });

  final String id;
  final String clubId;
  final String name;
  final String? category;
  final String? avatarUrl;
  final List<String> playerIds;
  final List<String> coachIds;
  final List<String> pendingPlayerIds;
  final String? messagingLink;
  final String? parentsMessagingLink;

  String get categoryLabel =>
      (category != null && category!.isNotEmpty) ? category! : 'Sans catégorie';

  factory ClubTeam.fromFirestore({
    required String clubId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? {};
    return ClubTeam(
      id: doc.id,
      clubId: clubId,
      name: data[FirestoreFields.name] as String? ?? 'Équipe sans nom',
      category: data[FirestoreFields.category] as String?,
      avatarUrl: data[FirestoreFields.avatarUrl] as String?,
      playerIds: (data[FirestoreFields.playerIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      coachIds: (data[FirestoreFields.coachIds] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      pendingPlayerIds:
          (data[FirestoreFields.pendingPlayerIds] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [],
      messagingLink: (data[FirestoreFields.messagingLink] as String?)?.trim(),
      parentsMessagingLink:
          (data[FirestoreFields.parentsMessagingLink] as String?)?.trim(),
    );
  }
}

/// Profil affiché pour un membre d'équipe (compte lié).
class TeamMemberProfile {
  const TeamMemberProfile({
    required this.uid,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Joueur invité sans compte utilisateur.
class PendingTeamMember {
  const PendingTeamMember({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();
}
