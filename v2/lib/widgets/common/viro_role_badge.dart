import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

/// Rôles affichables en UI.
///
/// [ViroRole.parent] = relation parent↔enfant ([ProjectConfig.parentLinksField]),
/// pas un rôle `members/{uid}.role`. Utiliser [viroRoleFromMemberRole] pour
/// les badges issus d'une adhésion club.
enum ViroRole { player, coach, parent, admin }

/// Mappe un rôle club (`player` | `coach` | `admin`) vers le badge UI.
ViroRole viroRoleFromMemberRole(String role) => switch (role) {
      MemberRoles.admin => ViroRole.admin,
      MemberRoles.coach => ViroRole.coach,
      _ => ViroRole.player,
    };

/// Badge de rôle coloré (joueur, entraîneur, parent, admin).
class ViroRoleBadge extends StatelessWidget {
  const ViroRoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  final ViroRole role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = RoleBadgeVisual.forRole(role);
    final label = RoleBadgeVisual.labelFor(role);
    final height = compact ? 28.0 : 36.0;
    final iconSize = compact ? 14.0 : 16.0;
    final fontSize = compact ? 11.0 : 13.0;

    return Container(
      height: height,
      padding: EdgeInsets.only(
        left: compact ? 6 : 8,
        right: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.start, style.end],
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        boxShadow: [
          BoxShadow(
            color: style.end.withValues(alpha: 0.45),
            blurRadius: compact ? 8 : 12,
            offset: Offset(0, compact ? 3 : 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 20 : 24,
            height: compact ? 20 : 24,
            decoration: BoxDecoration(
              color: ViroColors.roleBadgeIconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: ViroIcon(
              style.icon,
              size: iconSize,
              color: ViroColors.roleBadgeText,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: ViroColors.roleBadgeText,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge satellite (icône seule) — ancré sur un avatar / logo de club.
class ViroRoleSatelliteBadge extends StatelessWidget {
  const ViroRoleSatelliteBadge({super.key, required this.role});

  final ViroRole role;

  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    final style = RoleBadgeVisual.forRole(role);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.start, style.end],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: ViroColors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: style.end.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: ViroIcon(
        style.icon,
        size: 12,
        color: ViroColors.roleBadgeText,
      ),
    );
  }
}

abstract final class RoleBadgeVisual {
  static String labelFor(ViroRole role) => switch (role) {
        ViroRole.player => 'Joueur',
        ViroRole.coach => 'Entraîneur',
        ViroRole.parent => 'Parent',
        ViroRole.admin => 'Admin',
      };

  static RoleBadgeStyle forRole(ViroRole role) => switch (role) {
        ViroRole.player => RoleBadgeStyle(
            start: ViroColors.playerBadgeStart,
            end: ViroColors.playerBadgeEnd,
            icon: ViroIcons.rolePlayer,
          ),
        ViroRole.coach => RoleBadgeStyle(
            start: ViroColors.coachBadgeStart,
            end: ViroColors.coachBadgeEnd,
            icon: ViroIcons.roleCoach,
          ),
        ViroRole.parent => RoleBadgeStyle(
            start: ViroColors.parentBadgeStart,
            end: ViroColors.parentBadgeEnd,
            icon: ViroIcons.roleParent,
          ),
        ViroRole.admin => RoleBadgeStyle(
            start: ViroColors.adminBadgeStart,
            end: ViroColors.adminBadgeEnd,
            icon: ViroIcons.roleAdmin,
          ),
      };
}

class RoleBadgeStyle {
  const RoleBadgeStyle({
    required this.start,
    required this.end,
    required this.icon,
  });

  final Color start;
  final Color end;
  final IconData icon;
}
