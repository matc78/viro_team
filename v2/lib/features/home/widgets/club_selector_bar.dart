import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';

class ClubSelectorBar extends StatelessWidget {
  const ClubSelectorBar({
    super.key,
    required this.clubs,
    required this.pendingByClub,
  });

  final List<UserClubEntry> clubs;
  final Map<String, int> pendingByClub;

  static const double _barHeight = 88;
  static const double _logoSize = 56;

  @override
  Widget build(BuildContext context) {
    final items = clubs.map((entry) {
      final club = entry.$1;
      final membership = entry.$2;
      final pending = pendingByClub[club.id] ?? 0;
      return _ClubBarItem(
        label: _shortName(club.name),
        logoUrl: club.logoUrl,
        role: viroRoleFromMemberRole(membership.role),
        accentColor: clubAccentColor(
          brandColorHex: club.brandColorHex,
          clubId: club.id,
        ),
        badgeCount: pending > 0 ? pending : null,
        onTap: () => context.push(AppRoutes.clubDetailPath(club.id)),
      );
    }).toList();

    return SizedBox(
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ViroSpacing.screenHorizontal,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    constraints.maxWidth - ViroSpacing.screenHorizontal * 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: items,
              ),
            ),
          );
        },
      ),
    );
  }

  String _shortName(String name) {
    if (name.length <= 12) return name;
    return '${name.substring(0, 10)}…';
  }
}

class _ClubBarItem extends StatelessWidget {
  const _ClubBarItem({
    required this.label,
    required this.onTap,
    required this.role,
    this.logoUrl,
    this.accentColor,
    this.badgeCount,
  });

  final String label;
  final VoidCallback onTap;
  final ViroRole role;
  final String? logoUrl;
  final Color? accentColor;
  final int? badgeCount;

  static const double _logoSize = ClubSelectorBar._logoSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = accentColor ?? ViroColors.primary600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ViroSpacing.sm / 2),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _logoSize,
                  height: _logoSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                    image: logoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(logoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: logoUrl == null
                      ? Text(
                          label.isNotEmpty ? label[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        )
                      : null,
                ),
                if (badgeCount != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: ViroColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: theme.labelSmall?.copyWith(
                          color: ViroColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: ViroRoleSatelliteBadge(role: role),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              height: 14,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  color: ViroColors.gray600,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
