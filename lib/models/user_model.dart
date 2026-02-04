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

  UserModel({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.activeContext,
    required this.roles,
  });

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
      
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubsList = playerData['clubs'] as List;
        for (var clubItem in clubsList) {
          if (clubItem is Map) {
            clubs.add(PlayerClubInfo(
              clubId: clubItem['clubId'] as String?,
              teamIds: (clubItem['teamIds'] as List?)?.whereType<String>().toList() ?? [],
              teamNames: (clubItem['teamNames'] as List?)?.whereType<String>().toList() ?? [],
              categories: (clubItem['categories'] as List?)?.whereType<String>().toList() ?? [],
              license: clubItem['license'] as String?,
            ));
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

    // Admin : liste de clubIds
    final List<String> adminClubIds = [];
    if (rolesData['admin'] is List) {
      adminClubIds.addAll(
        (rolesData['admin'] as List).whereType<String>(),
      );
    }

    // Admin fondateur : liste de clubIds (clubs fondés)
    final List<String> adminFondateurClubIds = [];
    if (rolesData['admin_fondateur'] is List) {
      adminFondateurClubIds.addAll(
        (rolesData['admin_fondateur'] as List).whereType<String>(),
      );
    }

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
