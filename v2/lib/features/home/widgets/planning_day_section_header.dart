import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';

/// En-tête de jour pour le planning global (regroupement par date).
class PlanningDaySectionHeader extends StatelessWidget {
  const PlanningDaySectionHeader({
    super.key,
    required this.day,
    this.compactTop = false,
  });

  final DateTime day;
  final bool compactTop;

  @override
  Widget build(BuildContext context) {
    final parts = planningDayHeaderParts(day);
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        top: compactTop ? ViroSpacing.xs : ViroSpacing.md,
        bottom: ViroSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                parts.weekday,
                style: theme.titleLarge?.copyWith(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ViroSpacing.xs),
                child: Text(
                  '·',
                  style: theme.titleLarge?.copyWith(
                    color: ViroColors.primary200,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                '${parts.day} ${parts.month}',
                style: theme.titleLarge?.copyWith(
                  color: ViroColors.primary600,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              if (parts.dayOffsetLabel != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    parts.dayOffsetLabel!,
                    style: theme.labelSmall?.copyWith(
                      color: ViroColors.gray400,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
              ],
              if (parts.badge != null) ...[
                const SizedBox(width: ViroSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ViroSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ViroColors.primary600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    parts.badge!,
                    style: theme.labelSmall?.copyWith(
                      color: ViroColors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: ViroSpacing.xs),
          Container(
            height: 2,
            width: 32,
            decoration: BoxDecoration(
              color: ViroColors.primary600,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
