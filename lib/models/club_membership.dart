import 'package:cloud_firestore/cloud_firestore.dart';

/// Appartenance à un club (document clubs/{clubId}/members/{uid}).
/// Source de vérité des rôles et infos joueur/coach/admin par club.
class ClubMembership {
  final String userId;
  final String clubId;
  final List<String> roles;
  final bool isFounderAdmin;
  final String status;
  final PlayerMembershipInfo? player;
  final CoachMembershipInfo? coach;
  final AdminMembershipInfo? admin;
  final DateTime? joinedAt;
  final DateTime? updatedAt;
  final MemberSnapshot? snapshot;

  ClubMembership({
    required this.userId,
    required this.clubId,
    this.roles = const [],
    this.isFounderAdmin = false,
    this.status = 'active',
    this.player,
    this.coach,
    this.admin,
    this.joinedAt,
    this.updatedAt,
    this.snapshot,
  });

  factory ClubMembership.fromFirestore(
    String clubId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rolesList = (d['roles'] as List?)?.whereType<String>().toList() ?? [];

    PlayerMembershipInfo? playerInfo;
    if (d['player'] is Map) {
      final p = d['player'] as Map<String, dynamic>;
      playerInfo = PlayerMembershipInfo(
        license: p['license'] as String?,
        teamIds: (p['teamIds'] as List?)?.whereType<String>().toList() ?? [],
        teamNames: (p['teamNames'] as List?)?.whereType<String>().toList() ?? [],
        categories:
            (p['categories'] as List?)?.whereType<String>().toList() ?? [],
      );
    }

    CoachMembershipInfo? coachInfo;
    if (d['coach'] is Map) {
      final c = d['coach'] as Map<String, dynamic>;
      coachInfo = CoachMembershipInfo(
        teamIds: (c['teamIds'] as List?)?.whereType<String>().toList() ?? [],
        teamNames: (c['teamNames'] as List?)?.whereType<String>().toList() ?? [],
      );
    }

    AdminMembershipInfo? adminInfo;
    if (d['admin'] is Map) {
      final a = d['admin'] as Map<String, dynamic>;
      adminInfo = AdminMembershipInfo(
        scopes: (a['scopes'] as List?)?.whereType<String>().toList() ?? [],
      );
    }

    MemberSnapshot? snap;
    if (d['snapshot'] is Map) {
      final s = d['snapshot'] as Map<String, dynamic>;
      snap = MemberSnapshot(
        displayName: s['displayName'] as String?,
        avatarUrl: s['avatarUrl'] as String?,
        email: s['email'] as String?,
      );
    }

    return ClubMembership(
      userId: doc.id,
      clubId: clubId,
      roles: rolesList,
      isFounderAdmin: d['isFounderAdmin'] == true,
      status: d['status'] as String? ?? 'active',
      player: playerInfo,
      coach: coachInfo,
      admin: adminInfo,
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      snapshot: snap,
    );
  }

  bool get isPlayer => roles.contains('player');
  bool get isCoach => roles.contains('coach');
  bool get isAdmin =>
      roles.contains('admin') || roles.contains('admin_fondateur');
}

class PlayerMembershipInfo {
  final String? license;
  final List<String> teamIds;
  final List<String> teamNames;
  final List<String> categories;

  PlayerMembershipInfo({
    this.license,
    this.teamIds = const [],
    this.teamNames = const [],
    this.categories = const [],
  });
}

class CoachMembershipInfo {
  final List<String> teamIds;
  final List<String> teamNames;

  CoachMembershipInfo({
    this.teamIds = const [],
    this.teamNames = const [],
  });
}

class AdminMembershipInfo {
  final List<String> scopes;

  AdminMembershipInfo({this.scopes = const []});
}

class MemberSnapshot {
  final String? displayName;
  final String? avatarUrl;
  final String? email;

  MemberSnapshot({
    this.displayName,
    this.avatarUrl,
    this.email,
  });
}
