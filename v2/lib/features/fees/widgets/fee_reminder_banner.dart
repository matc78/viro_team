import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/fees/providers/fee_providers.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

class FeeReminderBanner extends ConsumerWidget {
  const FeeReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(homeFeeRemindersProvider);

    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            ViroSpacing.screenHorizontal,
            ViroSpacing.sm,
            ViroSpacing.screenHorizontal,
            0,
          ),
          child: Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
                  child: _FeeReminderCard(
                    item: item,
                    onTap: () => context.push(
                      AppRoutes.clubMyFeePath(item.clubId),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FeeReminderCard extends StatelessWidget {
  const _FeeReminderCard({
    required this.item,
    required this.onTap,
  });

  final HomeFeeReminderItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final accent = clubAccentColor(
      brandColorHex: item.brandColorHex,
      clubId: item.clubId,
    );
    final warning = item.isOverdue;
    final borderColor = warning ? ViroColors.error : accent;
    final bgColor = warning
        ? ViroColors.error.withValues(alpha: 0.08)
        : accent.withValues(alpha: 0.08);

    final amount = formatFeeAmountCents(item.fee.amountDueCents(item.season));
    final deadline = item.season.paymentDeadlineAt;
    final deadlineText = deadline != null
        ? DateFormat.yMMMMd('fr_FR').format(deadline)
        : null;

    final subtitle = warning
        ? 'En retard — $amount à régler'
        : deadlineText != null
            ? '$amount à régler avant le $deadlineText'
            : '$amount à régler';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: ViroPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.md),
          child: Row(
            children: [
              ViroIcon(
                ViroIcons.payments,
                color: borderColor,
                size: 22,
              ),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cotisation ${item.season.seasonLabel}',
                      style: theme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ViroColors.primary800,
                      ),
                    ),
                    const SizedBox(height: ViroSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.bodyMedium?.copyWith(
                        color: warning
                            ? ViroColors.error
                            : ViroColors.gray600,
                      ),
                    ),
                    Text(
                      item.clubName,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              ViroIcon(
                ViroIcons.chevronRight,
                color: ViroColors.gray400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
