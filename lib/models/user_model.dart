import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle utilisateur pour l'architecture multi-tenant/multi-role
/// 
/// Structure Firestore :
/// {
///   "uid": "...",
///   "email": "...",
///   "activeContext": { "role": "coach", "clubId": "clubA" },
///   "roles": {
///     "player": { "clubId": "clubB", "teamIds": ["u15"], "license": "123" },
///     "coach": [
///       { "clubId": "clubA", "teams": ["u11"] },
///       { "clubId": "clubC", "teams": ["senior"] }
///     ],
///     "admin": ["clubA", "clubD"]
///   }
/// }
class UserModel {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarUrl;
  
  /// Contexte actif de la session utilisateur
  final ActiveContext? activeContext;
  
  /// Tous les rôles de l'utilisateur
  final UserRoles roles;

  /// Indique si l'utilisateur a une demande (rejoindre un club, etc.) en attente
  final bool hasPendingRequest;

  /// Indique si le profil a été complété (page post-connexion Google pour nom, prénom, téléphone).
  /// Défaut true pour rétrocompatibilité avec les utilisateurs existants.
  final bool profileCompleted;

  UserModel({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.activeContext,
    required this.roles,
    this.hasPendingRequest = false,
    this.profileCompleted = true,
  });

  static PlayerClubInfo _parseClubInfo(Map<String, dynamic> m) {
    return PlayerClubInfo(
      clubId: m['clubId'] as String?,
      teamIds: (m['teamIds'] as List?)?.whereType<String>().toList() ?? [],
      teamNames: (m['teamNames'] as List?)?.whereType<String>().toList() ?? [],
      categories: (m['categories'] as List?)?.whereType<String>().toList() ?? [],
      license: m['license'] as String?,
    );
  }

  /// Parse une liste de chaînes depuis Firestore (List, Map, ou String unique).
  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is Map) {
      return value.values.whereType<String>().toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return [];
  }

  /// Parse depuis un document Firestore
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Parse activeContext
    ActiveContext? activeCtx;
    if (data['activeContext'] is Map) {
      final ctxData = data['activeContext'] as Map<String, dynamic>;
      activeCtx = ActiveContext(
        role: ctxData['role'] as String?,
        clubId: ctxData['clubId'] as String?,
      );
    }

    // Parse roles
    final rolesData = data['roles'] as Map<String, dynamic>? ?? {};
    
    // Player : objet unique ou null (peut contenir plusieurs clubs)
    PlayerProfile? playerProfile;
    if (rolesData['player'] is Map) {
      final playerData = rolesData['player'] as Map<String, dynamic>;
      
      List<PlayerClubInfo> clubs = [];
      
      // Nouvelle structure : liste de clubs (List ou Map "0","1",...)
      final clubsRaw = playerData['clubs'];
      if (clubsRaw is List) {
        for (var clubItem in clubsRaw) {
          if (clubItem is Map) {
            clubs.add(_parseClubInfo(clubItem as Map<String, dynamic>));
          }
        }
      } else if (clubsRaw is Map) {
        for (var clubItem in clubsRaw.values) {
          if (clubItem is Map) {
            clubs.add(_parseClubInfo(clubItem as Map<String, dynamic>));
          }
        }
      }
      // Ancienne structure : clubId direct (compatibilité)
      else if (playerData['clubId'] != null) {
        clubs.add(PlayerClubInfo(
          clubId: playerData['clubId'] as String?,
          teamIds: (playerData['teamIds'] as List?)?.whereType<String>().toList() ?? [],
          teamNames: (playerData['teamNames'] as List?)?.whereType<String>().toList() ??
              (data['teamNames'] as List?)?.whereType<String>().toList() ?? [],
          categories: (playerData['categories'] as List?)?.whereType<String>().toList() ??
              (data['categories'] as List?)?.whereType<String>().toList() ?? [],
          license: playerData['license'] as String?, // Migration depuis l'ancienne structure
        ));
      }
      
      if (clubs.isNotEmpty) {
        playerProfile = PlayerProfile(
          clubs: clubs,
        );
      }
    }

    // Coach : liste de profils
    final List<CoachProfile> coachProfiles = [];
    if (rolesData['coach'] is List) {
      final coachList = rolesData['coach'] as List;
      for (var item in coachList) {
        if (item is Map) {
          coachProfiles.add(CoachProfile(
            clubId: item['clubId'] as String?,
            teams: (item['teams'] as List?)?.whereType<String>().toList() ?? [],
          ));
        }
      }
    }

    // Admin : liste de clubIds (Firestore peut renvoyer List ou Map avec clés "0","1",...)
    final List<String> adminClubIds = _parseStringList(rolesData['admin']);

    // Admin fondateur : liste de clubIds (clubs fondés)
    final List<String> adminFondateurClubIds = _parseStringList(
        rolesData['admin_fondateur'] ?? rolesData['adminFondateur']);

    final hasPending = data['hasPendingRequest'] == true;
    final profileCompletedRaw = data['profileCompleted'];
    final profileCompleted = identical(profileCompletedRaw, false)
        ? false
        : true;

    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      phone: data['phone'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      activeContext: activeCtx,
      roles: UserRoles(
        player: playerProfile,
        coach: coachProfiles,
        admin: adminClubIds,
        adminFondateur: adminFondateurClubIds,
      ),
      hasPendingRequest: hasPending,
      profileCompleted: profileCompleted,
    );
  }

  /// Construit un UserModel à partir du document user et des documents member (clubs/{clubId}/members/{uid}).
  /// Source de vérité : profileSummaries sur le user + données détaillées dans chaque member.
  factory UserModel.fromUserDocAndMembers(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
    Map<String, Map<String, dynamic>> membersByClub,
  ) {
    final data = userDoc.data() ?? {};
    ActiveContext? activeCtx;
    if (data['activeContext'] is Map) {
      final ctxData = data['activeContext'] as Map<String, dynamic>;
      activeCtx = ActiveContext(
        role: ctxData['role'] as String?,
        clubId: ctxData['clubId'] as String?,
      );
    }

    final raw = data['profileSummaries'] as List? ?? [];
    final summaries = raw
        .whereType<Map>()
        .map((m) => {'clubId': m['clubId'] as String? ?? '', 'role': m['role'] as String? ?? ''})
        .where((e) => (e['clubId'] ?? '').isNotEmpty && (e['role'] ?? '').isNotEmpty)
        .toList();

    final playerClubs = <PlayerClubInfo>[];
    final coachProfiles = <CoachProfile>[];
    final adminClubIds = <String>[];
    final adminFondateurClubIds = <String>[];

    for (final e in summaries) {
      final clubId = e['clubId']!;
      final role = e['role']!;
      final member = membersByClub[clubId];

      if (role == 'player' && member != null && member['player'] is Map) {
        final p = member['player'] as Map<String, dynamic>;
        playerClubs.add(PlayerClubInfo(
          clubId: clubId,
          teamIds: (p['teamIds'] as List?)?.whereType<String>().toList() ?? [],
          teamNames: (p['teamNames'] as List?)?.whereType<String>().toList() ?? [],
          categories: (p['categories'] as List?)?.whereType<String>().toList() ?? [],
          license: p['license'] as String?,
        ));
      } else if (role == 'coach' && member != null && member['coach'] is Map) {
        final c = member['coach'] as Map<String, dynamic>;
        final teams = (c['teamIds'] as List?)?.whereType<String>().toList() ??
            (c['teamNames'] as List?)?.whereType<String>().toList() ?? [];
        coachProfiles.add(CoachProfile(clubId: clubId, teams: teams));
      } else if (role == 'coach') {
        coachProfiles.add(CoachProfile(clubId: clubId, teams: const []));
      } else if (role == 'admin') {
        adminClubIds.add(clubId);
      } else if (role == 'admin_fondateur') {
        adminFondateurClubIds.add(clubId);
      }
    }

    PlayerProfile? playerProfile =
        playerClubs.isEmpty ? null : PlayerProfile(clubs: playerClubs);

    final hasPending = data['hasPendingRequest'] == true;
    final profileCompletedRaw = data['profileCompleted'];
    final profileCompleted =
        identical(profileCompletedRaw, false) ? false : true;

    return UserModel(
      uid: userDoc.id,
      email: data['email'] as String?,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      phone: data['phone'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      activeContext: activeCtx,
      roles: UserRoles(
        player: playerProfile,
        coach: coachProfiles,
        admin: adminClubIds,
        adminFondateur: adminFondateurClubIds,
      ),
      hasPendingRequest: hasPending,
      profileCompleted: profileCompleted,
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> rolesMap = {};
    
    // Player
    if (roles.player != null && roles.player!.clubs.isNotEmpty) {
      rolesMap['player'] = {
        'clubs': roles.player!.clubs.map((club) => {
          'clubId': club.clubId,
          'teamIds': club.teamIds,
          if (club.teamNames.isNotEmpty) 'teamNames': club.teamNames,
          if (club.categories.isNotEmpty) 'categories': club.categories,
          if (club.license != null) 'license': club.license,
        }).toList(),
      };
    }

    // Coach
    if (roles.coach.isNotEmpty) {
      rolesMap['coach'] = roles.coach.map((cp) => {
        'clubId': cp.clubId,
        'teams': cp.teams,
      }).toList();
    }

    // Admin
    if (roles.admin.isNotEmpty) {
      rolesMap['admin'] = roles.admin;
    }

    // Admin fondateur
    if (roles.adminFondateur.isNotEmpty) {
      rolesMap['admin_fondateur'] = roles.adminFondateur;
    }

    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (activeContext != null) 'activeContext': {
        'role': activeContext!.role,
        'clubId': activeContext!.clubId,
      },
      'roles': rolesMap,
    };
  }

  /// Getters utilitaires
  bool get isMultiProfile {
    int count = 0;
    if (roles.player != null) count++;
    count += roles.coach.length;
    count += roles.admin.length;
    count += roles.adminFondateur.length;
    return count > 1;
  }

  bool get hasPlayerProfile => roles.player != null;

  /// True si l'utilisateur a au moins un rôle (player, coach ou admin)
  bool get hasAnyRole =>
      roles.player != null ||
      roles.coach.isNotEmpty ||
      roles.admin.isNotEmpty ||
      roles.adminFondateur.isNotEmpty;

  List<String> get coachClubIds => roles.coach.map((c) => c.clubId ?? '').where((id) => id.isNotEmpty).toList();
  
  List<String> get allClubIds {
    final Set<String> clubIds = {};
    if (roles.player != null) {
      clubIds.addAll(roles.player!.clubs.map((c) => c.clubId ?? '').where((id) => id.isNotEmpty));
    }
    clubIds.addAll(coachClubIds);
    clubIds.addAll(roles.admin);
    clubIds.addAll(roles.adminFondateur);
    return clubIds.toList();
  }

  /// Vérifie si le activeContext stocké correspond encore à un rôle réel de l'utilisateur.
  /// Utile après reconnexion pour éviter d'afficher admin alors que l'utilisateur n'a plus ce rôle.
  bool get isActiveContextCoherent {
    final ctx = activeContext;
    if (ctx == null || !ctx.isValid) return false;
    return hasRoleInClub(ctx.role!, ctx.clubId!);
  }

  /// Vérifie si l'utilisateur a un rôle spécifique dans un club
  bool hasRoleInClub(String role, String clubId) {
    switch (role) {
      case 'player':
        return roles.player?.clubs.any((c) => c.clubId == clubId) ?? false;
      case 'coach':
        return roles.coach.any((c) => c.clubId == clubId);
      case 'admin':
        return roles.admin.contains(clubId);
      case 'admin_fondateur':
        return roles.adminFondateur.contains(clubId);
      default:
        return false;
    }
  }
}

/// Contexte actif de la session
class ActiveContext {
  final String? role; // 'player', 'coach', ou 'admin'
  final String? clubId;

  ActiveContext({this.role, this.clubId});

  bool get isValid => role != null && clubId != null && role!.isNotEmpty && clubId!.isNotEmpty;
}

/// Tous les rôles de l'utilisateur
class UserRoles {
  /// Max 1 seul profil Player (null si pas joueur)
  final PlayerProfile? player;
  
  /// Liste illimitée de profils Coach
  final List<CoachProfile> coach;
  
  /// Liste illimitée de clubIds Admin
  final List<String> admin;

  /// Liste des clubIds où l'utilisateur est administrateur fondateur
  final List<String> adminFondateur;

  UserRoles({
    this.player,
    this.coach = const [],
    this.admin = const [],
    this.adminFondateur = const [],
  });
}

/// Profil joueur (unique, mais peut contenir plusieurs clubs)
class PlayerProfile {
  final List<PlayerClubInfo> clubs;

  PlayerProfile({
    this.clubs = const [],
  });
}

/// Information sur un club dans lequel le player joue
/// teamIds, teamNames et categories sont synchronisés (même longueur logique par équipe)
class PlayerClubInfo {
  final String? clubId;
  final List<String> teamIds;
  final List<String> teamNames; // Noms des équipes (dénormalisés pour affichage)
  final List<String> categories; // Catégories des équipes
  final String? license; // Numéro de licence spécifique à ce club

  PlayerClubInfo({
    this.clubId,
    this.teamIds = const [],
    this.teamNames = const [],
    this.categories = const [],
    this.license,
  });
}

/// Profil coach (peut être multiple)
class CoachProfile {
  final String? clubId;
  final List<String> teams;

  CoachProfile({
    this.clubId,
    this.teams = const [],
  });
}

// ---------------------------------------------------------------------------
// Nouveau modèle (Option A) : UserProfile + profileSummaries
// ---------------------------------------------------------------------------

/// Un profil disponible dans le switcher (dérivé de profileSummaries).
class ProfileSummary {
  final String clubId;
  final String role;

  ProfileSummary({required this.clubId, required this.role});
}

/// Profil utilisateur global (document users/{uid}) avec profileSummaries.
/// Les champs modération sont fusionnés depuis users/{uid}/avatar_moderation/state.
class UserProfile {
  final String uid;
  final String? email;
  final String? emailNorm;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final bool avatarModerationRejected;
  final bool avatarModerationPending;
  final String? avatarModerationReason;
  final DateTime? avatarModerationRejectedAt;
  final bool avatarModerationOk;
  final ActiveContext? activeContext;
  final List<ProfileSummary> profileSummaries;
  final bool profileCompleted;
  final bool hasPendingRequest;
  final bool disabled;
  final Map<String, bool> notificationPreferences;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    this.email,
    this.emailNorm,
    this.firstName,
    this.lastName,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.avatarModerationRejected = false,
    this.avatarModerationPending = false,
    this.avatarModerationReason,
    this.avatarModerationRejectedAt,
    this.avatarModerationOk = false,
    this.activeContext,
    this.profileSummaries = const [],
    this.profileCompleted = true,
    this.hasPendingRequest = false,
    this.disabled = false,
    this.notificationPreferences = const {},
    this.createdAt,
    this.updatedAt,
  });

  /// Construit à partir d'un Map déjà fusionné (user doc + avatar_moderation/state).
  /// Si profileSummaries est vide, dérive depuis roles (rétrocompatibilité).
  factory UserProfile.fromMergedData(String uid, Map<String, dynamic> d) {
    final flags = d['flags'] as Map<String, dynamic>? ?? {};
    final prefs = d['notificationPreferences'] as Map<String, dynamic>? ?? {};
    final summariesRaw = d['profileSummaries'] as List? ?? [];
    List<ProfileSummary> list = summariesRaw
        .whereType<Map>()
        .map((m) => ProfileSummary(
              clubId: m['clubId'] as String? ?? '',
              role: m['role'] as String? ?? '',
            ))
        .where((s) => s.clubId.isNotEmpty && s.role.isNotEmpty)
        .toList();

    ActiveContext? ctx;
    if (d['activeContext'] is Map) {
      final c = d['activeContext'] as Map<String, dynamic>;
      ctx = ActiveContext(
        role: c['role'] as String?,
        clubId: c['clubId'] as String?,
      );
    }

    return UserProfile(
      uid: uid,
      email: d['email'] as String?,
      emailNorm: d['emailNorm'] as String?,
      firstName: d['firstName'] as String?,
      lastName: d['lastName'] as String?,
      displayName: d['displayName'] as String?,
      phone: d['phone'] as String?,
      avatarUrl: d['avatarUrl'] as String?,
      avatarModerationRejected: d['avatarModerationRejected'] == true,
      avatarModerationPending: d['avatarModerationPending'] == true,
      avatarModerationReason: d['avatarModerationReason'] as String?,
      avatarModerationRejectedAt:
          (d['avatarModerationRejectedAt'] as Timestamp?)?.toDate(),
      avatarModerationOk: d['avatarModerationOk'] == true,
      activeContext: ctx,
      profileSummaries: list,
      profileCompleted: identical(flags['profileCompleted'], false) || identical(d['profileCompleted'], false) ? false : true,
      hasPendingRequest: flags['hasPendingRequest'] == true || d['hasPendingRequest'] == true,
      disabled: flags['disabled'] == true,
      notificationPreferences:
          prefs.map((k, v) => MapEntry(k, v == true)),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Map fusionné pour effectiveAvatarUrl et autres usages (avatarUrl + champs modération).
  Map<String, dynamic> toAvatarMergeMap() {
    return {
      'avatarUrl': avatarUrl,
      'avatarModerationRejected': avatarModerationRejected,
      'avatarModerationPending': avatarModerationPending,
      'avatarModerationReason': avatarModerationReason,
      'avatarModerationRejectedAt': avatarModerationRejectedAt,
      'avatarModerationOk': avatarModerationOk,
    };
  }

  bool get hasAnyRole => profileSummaries.isNotEmpty;

  bool get isActiveContextCoherent {
    final ctx = activeContext;
    if (ctx == null || !ctx.isValid) return false;
    return profileSummaries.any((s) =>
        s.clubId == ctx.clubId && s.role == ctx.role);
  }

  bool hasRoleInClub(String role, String clubId) {
    return profileSummaries
        .any((s) => s.clubId == clubId && s.role == role);
  }
}
