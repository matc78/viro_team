import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class ClubStatsRow extends StatelessWidget {
  const ClubStatsRow({
    super.key,
    required this.attendanceRate,
    required this.nextEvent,
    required this.club,
    this.onMembersTap,
    this.onNextEventTap,
    this.onAttendanceTap,
  });

  final double? attendanceRate;
  final ClubEvent? nextEvent;
  final Club club;
  final VoidCallback? onMembersTap;
  final VoidCallback? onNextEventTap;
  final VoidCallback? onAttendanceTap;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];

    if (attendanceRate != null) {
      cards.add(
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 150,
            child: ViroStatsCard(
              label: 'Présence (30 j)',
              value: '${attendanceRate!.round()} %',
              subtitle: 'Séances pointées',
              onTap: onAttendanceTap,
            ),
          ),
        ),
      );
    }

    if (nextEvent != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: ViroSpacing.sm));
      cards.add(
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 180,
            child: ViroStatsCard(
              label: 'Prochain event',
              value:
                  '${eventTypeLabel(nextEvent!.type)} · ${formatEventDate(nextEvent!.date)}',
              onTap: onNextEventTap,
            ),
          ),
        ),
      );
    }

    if (club.memberCount > 0) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: ViroSpacing.sm));
      cards.add(
        Align(
          alignment: Alignment.center,
          child: _MemberCountStatCard(
            count: club.memberCount,
            onTap: onMembersTap,
          ),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ViroSpacing.screenHorizontal,
        ),
        children: cards,
      ),
    );
  }
}

/// Carte compacte pour le nombre de membres (chiffre mis en avant).
class _MemberCountStatCard extends StatelessWidget {
  const _MemberCountStatCard({
    required this.count,
    this.onTap,
  });

  final int count;
  final VoidCallback? onTap;

  static double _widthFor(int count) {
    final digits = count.toString().length;
    return switch (digits) {
      <= 2 => 140,
      _ => 156,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SizedBox(
      width: _widthFor(count),
      child: ViroCard(
        onTap: onTap,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: ViroSpacing.md + 2,
          vertical: ViroSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membres',
              style: theme.bodySmall?.copyWith(
                color: ViroColors.gray600,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            const SizedBox(height: ViroSpacing.xs),
            Text(
              '$count',
              style: theme.titleLarge?.copyWith(
                color: ViroColors.primary800,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
