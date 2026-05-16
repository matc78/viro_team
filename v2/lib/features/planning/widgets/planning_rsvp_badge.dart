import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/models/club_event.dart';

/// Badge icône + compteur (résumé).
class PlanningRsvpCountBadge extends StatelessWidget {
  const PlanningRsvpCountBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: ViroIcon(icon, size: 18, color: color),
        ),
        if (count > 0)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ViroColors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ViroColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Badge RSVP d'un joueur (icône seule).
class PlanningRsvpStatusBadge extends StatelessWidget {
  const PlanningRsvpStatusBadge({super.key, required this.status});

  final RsvpStatus status;

  (IconData icon, Color color) get _style => switch (status) {
        RsvpStatus.yes => (ViroIcons.check, ViroColors.success),
        RsvpStatus.no => (ViroIcons.close, ViroColors.error),
        RsvpStatus.none => (ViroIcons.clock, ViroColors.warning),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: ViroIcon(icon, size: 18, color: color),
    );
  }
}

class PlanningRsvpSummaryRow extends StatelessWidget {
  const PlanningRsvpSummaryRow({super.key, required this.counts});

  final ({int yes, int no, int none}) counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlanningRsvpCountBadge(
          icon: ViroIcons.check,
          count: counts.yes,
          color: ViroColors.success,
        ),
        const SizedBox(width: ViroSpacing.sm),
        PlanningRsvpCountBadge(
          icon: ViroIcons.close,
          count: counts.no,
          color: ViroColors.error,
        ),
        if (counts.none > 0) ...[
          const SizedBox(width: ViroSpacing.sm),
          PlanningRsvpCountBadge(
            icon: ViroIcons.clock,
            count: counts.none,
            color: ViroColors.warning,
          ),
        ],
      ],
    );
  }
}
