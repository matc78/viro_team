/// Noms de champs Firestore v2 — source : [ProjectConfig.firestoreModelDoc].
abstract final class FirestoreFields {
  // users/{uid}
  static const String uid = 'uid';
  static const String email = 'email';
  static const String emailNorm = 'emailNorm';
  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String displayName = 'displayName';
  static const String phone = 'phone';
  static const String avatarUrl = 'avatarUrl';
  static const String fcmToken = 'fcmToken';
  static const String clubMemberships = 'clubMemberships';
  static const String notificationPreferences = 'notificationPreferences';
  static const String flags = 'flags';
  static const String profileCompleted = 'profileCompleted';
  static const String disabled = 'disabled';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String lastConnectionAt = 'lastConnectionAt';
  static const String parentLinks = 'parentLinks';

  // parentLinks item (relation parent → enfant, pas un rôle club)
  static const String childUid = 'childUid';
  static const String permissions = 'permissions';
  static const String revokedAt = 'revokedAt';

  // clubMemberships item
  static const String clubId = 'clubId';
  static const String role = 'role';

  // clubs/{clubId}
  static const String name = 'name';
  static const String city = 'city';
  static const String postalCode = 'postalCode';
  static const String address = 'address';
  static const String sport = 'sport';
  static const String contactEmail = 'contactEmail';
  static const String description = 'description';
  static const String logoUrl = 'logoUrl';
  static const String brandColorHex = 'brandColorHex';
  static const String objectives = 'objectives';
  static const String practiceLocations = 'practiceLocations';
  static const String adminIds = 'adminIds';
  static const String memberCount = 'memberCount';
  static const String seasonEndDate = 'seasonEndDate';

  // members/{memberId}
  static const String userId = 'userId';
  static const String memberId = 'memberId';
  static const String accountUid = 'accountUid';
  static const String status = 'status';
  static const String teamIds = 'teamIds';
  static const String snapshot = 'snapshot';
  static const String joinedAt = 'joinedAt';
  static const String playerInfo = 'playerInfo';
  static const String coachInfo = 'coachInfo';
  static const String license = 'license';
  static const String activeInvitationId = 'activeInvitationId';

  // member_accounts/{accountUid} → { memberId }
  static const String linkedMemberId = 'memberId';

  // invitations
  static const String code = 'code';
  static const String sentBy = 'sentBy';
  static const String sentAt = 'sentAt';
  static const String expiresAt = 'expiresAt';
  static const String acceptedAt = 'acceptedAt';

  // events/{eventId}
  static const String type = 'type';
  static const String title = 'title';
  static const String location = 'location';
  static const String allTeams = 'allTeams';
  static const String date = 'date';
  static const String startTime = 'startTime';
  static const String endTime = 'endTime';
  static const String meetingTime = 'meetingTime';
  static const String meetingLocation = 'meetingLocation';
  static const String matchVenue = 'matchVenue';
  static const String seriesId = 'seriesId';
  static const String teamMemberIds = 'teamMemberIds';
  static const String rsvp = 'rsvp';
  static const String attendance = 'attendance';
  static const String creatorId = 'creatorId';
  static const String canceled = 'canceled';

  // teams/{teamId}
  static const String category = 'category';
  static const String playerIds = 'playerIds';
  static const String coachIds = 'coachIds';
  static const String pendingPlayerIds = 'pendingPlayerIds';
  static const String messagingLink = 'messagingLink';
  static const String parentsMessagingLink = 'parentsMessagingLink';

  // announcements
  static const String senderId = 'senderId';
  static const String senderFirstName = 'senderFirstName';
  static const String senderLastName = 'senderLastName';
  static const String targetType = 'targetType';
  static const String targetIds = 'targetIds';
  static const String durationDays = 'durationDays';

  // join_requests
  static const String clubName = 'clubName';
  static const String clubSport = 'clubSport';
  static const String roleRequested = 'roleRequested';
  static const String message = 'message';
}

/// Rôles membre d'un club — hiérarchie : admin ⊃ coach ⊃ player.
///
/// Parent n'est PAS un rôle ici : voir [FirestoreFields.parentLinks] et
/// [ProjectConfig.parentLinksField].
abstract final class MemberRoles {
  static const String admin = 'admin';
  static const String coach = 'coach';
  static const String player = 'player';
}

/// Niveaux de rôle club — coach hérite de player, admin hérite de coach.
abstract final class MemberRoleHierarchy {
  static int level(String role) => switch (role) {
        MemberRoles.admin => 3,
        MemberRoles.coach => 2,
        MemberRoles.player => 1,
        _ => 0,
      };

  /// `true` si [role] a au moins les droits de [minimum] (ex. coach ≥ player).
  static bool satisfies(String role, String minimum) =>
      level(role) >= level(minimum);

  static bool isCoachOrAbove(String role) => satisfies(role, MemberRoles.coach);

  static bool isAdmin(String role) => role == MemberRoles.admin;
}

/// Statuts invitation.
abstract final class InvitationStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
  static const String expired = 'expired';
}

/// Statuts demande d'adhésion.
abstract final class JoinRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String refused = 'refused';
}

/// Objectifs d'usage club (assistant création).
abstract final class ClubObjectives {
  static const String planning = 'planning';
  static const String attendance = 'attendance';
  static const String tournaments = 'tournaments';
  static const String fees = 'fees';
  static const String equipment = 'equipment';
  static const String communication = 'communication';

  static const List<String> all = [
    planning,
    attendance,
    tournaments,
    fees,
    equipment,
    communication,
  ];

  static String label(String key) => switch (key) {
        planning => 'Planning & événements',
        attendance => 'Présences',
        tournaments => 'Tournois',
        fees => 'Cotisations',
        equipment => 'Équipement',
        communication => 'Annonces',
        _ => key,
      };
}

/// Sports proposés à la création de club.
abstract final class ClubSports {
  static const List<String> all = [
    'Football',
    'Basketball',
    'Volleyball',
    'Handball',
    'Rugby',
    'Tennis',
    'Natation',
    'Athlétisme',
    'Judo',
    'Escrime',
    'Aviron',
    'Autre',
  ];
}
