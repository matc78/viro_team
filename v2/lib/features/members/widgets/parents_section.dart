import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/services/member_service.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';

class ParentsSection extends ConsumerWidget {
  const ParentsSection({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentsAsync = ref.watch(clubParentsProvider(clubId));
    final theme = Theme.of(context).textTheme;

    return parentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (parents) {
        if (parents.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ViroSpacing.screenHorizontal,
                ViroSpacing.lg,
                ViroSpacing.screenHorizontal,
                ViroSpacing.sm,
              ),
              child: Text(
                'Parents connectés',
                style: theme.titleMedium?.copyWith(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...parents.map((p) => _ParentTile(parent: p)),
          ],
        );
      },
    );
  }
}

class _ParentTile extends StatelessWidget {
  const _ParentTile({required this.parent});

  final ClubParentEntry parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.screenHorizontal,
      ),
      child: ViroCard(
        margin: const EdgeInsets.only(bottom: ViroSpacing.sm),
        padding: const EdgeInsets.all(ViroSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: ViroColors.parentBadgeStart.withValues(alpha: 0.2),
              child: Text(
                parent.displayName.isNotEmpty
                    ? parent.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: ViroSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parent.displayName,
                    style: theme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (parent.email != null && parent.email!.isNotEmpty)
                    Text(
                      parent.email!,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.gray600,
                      ),
                    ),
                ],
              ),
            ),
            const ViroRoleBadge(role: ViroRole.parent, compact: true),
          ],
        ),
      ),
    );
  }
}
