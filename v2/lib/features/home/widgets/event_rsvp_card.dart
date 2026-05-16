import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/club_chip.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class EventRsvpCard extends StatelessWidget {
  const EventRsvpCard({
    super.key,
    required this.event,
    required this.clubName,
    required this.clubColor,
    required this.onPresent,
    required this.onAbsent,
  });

  final ClubEvent event;
  final String clubName;
  final Color clubColor;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final dateStr = formatEventDate(event.date);
    final timeStr = formatEventTime(event.startTime);

    return ViroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ViroIcon(ViroIcons.calendar, size: 18, color: clubColor),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: Text(
                  '${eventTypeLabel(event.type)} · ${event.title}',
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
          const SizedBox(height: ViroSpacing.md),
          Row(
            children: [
              Expanded(
                child: _RsvpButton(
                  label: 'Présent',
                  selected: false,
                  color: ViroColors.success,
                  onTap: onPresent,
                ),
              ),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: _RsvpButton(
                  label: 'Absent',
                  selected: false,
                  color: ViroColors.error,
                  onTap: onAbsent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
        child: Container(
          height: ViroSpacing.buttonHeightMedium,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
