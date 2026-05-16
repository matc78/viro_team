import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/planning/utils/planning_event_display.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_rsvp_badge.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class PlanningEventTile extends StatelessWidget {
  const PlanningEventTile({
    super.key,
    required this.event,
    this.teamLabel,
    this.excludeCoachUids = const {},
    this.onTap,
  });

  final ClubEvent event;
  final String? teamLabel;
  final Set<String> excludeCoachUids;
  final VoidCallback? onTap;

  IconData get _typeIcon => switch (event.type) {
        EventTypes.training => ViroIcons.whistle,
        EventTypes.match => ViroIcons.ball,
        EventTypes.tournament => ViroIcons.trophy,
        _ => ViroIcons.calendar,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final counts = event.rsvpCountsExcluding(excludeCoachUids);
    final startStr = formatEventTime(event.startTime);
    final endStr = formatEventTime(event.endTime);
    final rdvStr = formatEventTime(event.meetingTime);
    final headline = PlanningEventDisplay.headline(event);
    final subtitle = PlanningEventDisplay.subtitle(event, teamLabel);
    final location = PlanningEventDisplay.locationLine(event);

    return ViroCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: ViroSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        startStr,
                        style: theme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ViroColors.primary600,
                          height: 1.1,
                        ),
                      ),
                      if (event.type == EventTypes.match && rdvStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'RDV $rdvStr',
                            style: theme.labelSmall?.copyWith(
                              color: ViroColors.gray600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (endStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            endStr,
                            style: theme.labelSmall?.copyWith(
                              color: ViroColors.gray400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ViroIcon(
                          _typeIcon,
                          size: 18,
                          color: ViroColors.primary600,
                        ),
                        const SizedBox(width: ViroSpacing.xs),
                        Expanded(
                          child: Text(
                            headline,
                            style: theme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ViroColors.primary800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.bodyMedium?.copyWith(
                          color: ViroColors.gray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: theme.bodySmall?.copyWith(
                          color: ViroColors.gray400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.sm),
          Center(child: PlanningRsvpSummaryRow(counts: counts)),
        ],
      ),
    );
  }
}
