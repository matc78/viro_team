import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_rsvp_badge.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/club_chip.dart';
import 'package:viro_team_v2/widgets/common/rsvp_choice_button.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class EventPlanningCard extends StatelessWidget {
  const EventPlanningCard({
    super.key,
    required this.event,
    required this.clubName,
    required this.clubColor,
    required this.coachView,
    this.teamRsvpCounts,
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

  /// Coach seul : compteurs agrégés uniquement (pas de RSVP perso).
  final bool coachView;

  /// Compteurs équipe (présents / absents / en attente).
  final ({int yes, int no, int none})? teamRsvpCounts;

  /// Joueur ou double casquette : RSVP personnel.
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
    final typeLabel = eventTypeLabel(event.type);
    final title = event.title.trim();
    final showTitle = title.isNotEmpty && title != typeLabel;
    final timeStr = formatEventTime(event.startTime);
    final location = event.location?.trim();
    final scheduleParts = [
      if (timeStr.isNotEmpty) timeStr,
      if (location != null && location.isNotEmpty) location,
    ];

    final showPlayerRsvp = !coachView;

    return ViroCard(
      onTap: coachView
          ? onCoachTap
          : (showRsvpButtons ? null : onToggleRsvp),
      onLongPress: onLongPress,
      accentColor: clubColor,
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.md,
        vertical: ViroSpacing.sm + 2,
      ),
      margin: const EdgeInsets.only(bottom: ViroSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ViroIcon(_typeIcon, size: 18, color: clubColor),
              const SizedBox(width: ViroSpacing.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: typeLabel,
                        style: theme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: clubColor,
                          height: 1.2,
                        ),
                      ),
                      if (showTitle)
                        TextSpan(
                          text: ' · $title',
                          style: theme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ViroColors.primary800,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: ViroSpacing.xs),
              ClubChip(label: clubName, color: clubColor),
            ],
          ),
          if (scheduleParts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              scheduleParts.join(' · '),
              style: theme.bodySmall?.copyWith(
                color: ViroColors.gray600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (showPlayerRsvp && !showRsvpButtons) ...[
            const SizedBox(height: ViroSpacing.xs),
            _buildMemberRsvpFooter(context),
          ],
          if (showRsvpButtons) ...[
            const SizedBox(height: ViroSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: RsvpChoiceButton(
                    label: 'Présent',
                    color: ViroColors.success,
                    onTap: onPresent!,
                  ),
                ),
                const SizedBox(width: ViroSpacing.sm),
                Expanded(
                  child: RsvpChoiceButton(
                    label: 'Absent',
                    color: ViroColors.error,
                    onTap: onAbsent!,
                  ),
                ),
              ],
            ),
          ],
          if (coachView && teamRsvpCounts != null) ...[
            const SizedBox(height: ViroSpacing.xs),
            _buildCoachRsvpFooter(),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRsvpFooter(BuildContext context) {
    final badge = _StatusBadge(status: rsvpStatus ?? RsvpStatus.none);
    final counts = teamRsvpCounts;
    if (counts == null) {
      return Align(alignment: Alignment.centerLeft, child: badge);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        _TeamRsvpCountRow(counts: counts),
      ],
    );
  }

  Widget _buildCoachRsvpFooter() {
    return Center(
      child: PlanningRsvpSummaryRow(counts: teamRsvpCounts!),
    );
  }
}

class _TeamRsvpCountRow extends StatelessWidget {
  const _TeamRsvpCountRow({required this.counts});

  final ({int yes, int no, int none}) counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
      ),
    );
  }
}

