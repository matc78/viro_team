import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_rsvp_badge.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/club_chip.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class EventPlanningCard extends StatelessWidget {
  const EventPlanningCard({
    super.key,
    required this.event,
    required this.clubName,
    required this.clubColor,
    required this.coachView,
    this.coachRsvpCounts,
    this.presentCount,
    this.rsvpStatus,
    this.showRsvpButtons = false,
    this.onCoachTap,
    this.onLongPress,
    this.onToggleRsvp,
    this.onPresent,
    this.onAbsent,
  });

  final ClubEvent event;
  final String clubName;
  final Color clubColor;

  /// Coach : badges présents / absents / en attente.
  final bool coachView;
  final ({int yes, int no, int none})? coachRsvpCounts;

  /// Joueur : nombre de présents + RSVP personnel.
  final int? presentCount;
  final RsvpStatus? rsvpStatus;
  final bool showRsvpButtons;
  final VoidCallback? onCoachTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleRsvp;
  final VoidCallback? onPresent;
  final VoidCallback? onAbsent;

  IconData get _typeIcon => switch (event.type) {
        EventTypes.training => ViroIcons.whistle,
        EventTypes.match => ViroIcons.ball,
        EventTypes.tournament => ViroIcons.trophy,
        _ => ViroIcons.calendar,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final dateStr = formatEventDate(event.date);
    final timeStr = formatEventTime(event.startTime);

    return ViroCard(
      onTap: coachView
          ? onCoachTap
          : (showRsvpButtons ? null : onToggleRsvp),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ViroIcon(_typeIcon, size: 20, color: clubColor),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: Text(
                  event.title.isNotEmpty
                      ? event.title
                      : eventTypeLabel(event.type),
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ClubChip(label: clubName, color: clubColor),
            ],
          ),
          const SizedBox(height: ViroSpacing.sm),
          Text(
            [dateStr, if (timeStr.isNotEmpty) timeStr, event.location]
                .where((s) => s != null && s.isNotEmpty)
                .join(' · '),
            style: theme.bodySmall?.copyWith(color: ViroColors.gray600),
          ),
          const SizedBox(height: ViroSpacing.sm),
          if (coachView && coachRsvpCounts != null)
            Center(child: PlanningRsvpSummaryRow(counts: coachRsvpCounts!))
          else ...[
            Row(
              children: [
                Expanded(child: _buildPlayerRsvpRow(context)),
                if (presentCount != null) ...[
                  const SizedBox(width: ViroSpacing.md),
                  PlanningRsvpCountBadge(
                    icon: ViroIcons.check,
                    count: presentCount!,
                    color: ViroColors.success,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerRsvpRow(BuildContext context) {
    if (showRsvpButtons) {
      return Row(
        children: [
          Expanded(
            child: _StatusChip(
              label: 'Présent',
              color: ViroColors.success,
              onTap: onPresent!,
            ),
          ),
          const SizedBox(width: ViroSpacing.sm),
          Expanded(
            child: _StatusChip(
              label: 'Absent',
              color: ViroColors.error,
              onTap: onAbsent!,
            ),
          ),
        ],
      );
    }
    return _StatusBadge(status: rsvpStatus ?? RsvpStatus.none);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RsvpStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RsvpStatus.yes => ('Présent', ViroColors.success),
      RsvpStatus.no => ('Absent', ViroColors.error),
      RsvpStatus.none => ('Sans réponse', ViroColors.warning),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ViroSpacing.sm,
          vertical: ViroSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
