import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_membership_summary.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';

class ClubListTile extends StatelessWidget {
  const ClubListTile({
    super.key,
    required this.club,
    required this.membership,
    required this.onTap,
  });

  final Club club;
  final ClubMembershipSummary membership;
  final VoidCallback onTap;

  ViroRole get _badgeRole => viroRoleFromMemberRole(membership.role);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final subtitle = [
      club.sport,
      if (club.city != null && club.city!.isNotEmpty) club.city,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: ViroSpacing.md),
      child: ViroCard(
        onTap: onTap,
        child: Row(
          children: [
            _ClubAvatar(logoUrl: club.logoUrl, name: club.name),
            const SizedBox(width: ViroSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: theme.titleMedium?.copyWith(
                      color: ViroColors.primary800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.bodySmall?.copyWith(
                      color: ViroColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
            ViroRoleBadge(role: _badgeRole, compact: true),
          ],
        ),
      ),
    );
  }
}

class _ClubAvatar extends StatelessWidget {
  const _ClubAvatar({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: ViroColors.primary50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.primary100),
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
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ViroColors.primary600,
              ),
            )
          : null,
    );
  }
}
