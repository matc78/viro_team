import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/planning/utils/planning_event_display.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_member_rsvp_row.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_rsvp_badge.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';

enum _CancelScope { single, series }

class PlanningEventDetailSheet extends ConsumerStatefulWidget {
  const PlanningEventDetailSheet({
    super.key,
    required this.clubId,
    required this.event,
    required this.scrollController,
    this.teamLabel,
    this.excludeCoachUids = const {},
    this.canManageEvents = true,
    required this.onCanceled,
  });

  final String clubId;
  final ClubEvent event;
  final ScrollController scrollController;
  final String? teamLabel;
  final Set<String> excludeCoachUids;
  final bool canManageEvents;
  final VoidCallback onCanceled;

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String clubId,
    required ClubEvent event,
    String? teamLabel,
    Set<String> excludeCoachUids = const {},
    bool canManageEvents = true,
    required VoidCallback onCanceled,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => PlanningEventDetailSheet(
          clubId: clubId,
          event: event,
          scrollController: scrollController,
          teamLabel: teamLabel,
          excludeCoachUids: excludeCoachUids,
          canManageEvents: canManageEvents,
          onCanceled: onCanceled,
        ),
      ),
    );
  }

  @override
  ConsumerState<PlanningEventDetailSheet> createState() =>
      _PlanningEventDetailSheetState();
}

class _PlanningEventDetailSheetState
    extends ConsumerState<PlanningEventDetailSheet> {
  IconData get _typeIcon => switch (widget.event.type) {
        EventTypes.training => ViroIcons.whistle,
        EventTypes.match => ViroIcons.ball,
        EventTypes.tournament => ViroIcons.trophy,
        _ => ViroIcons.calendar,
      };

  List<({String id, ClubMember member})> _sortedEntries(
    Map<String, ClubMember> byUid,
  ) {
    int order(RsvpStatus s) => switch (s) {
          RsvpStatus.yes => 0,
          RsvpStatus.no => 1,
          RsvpStatus.none => 2,
        };

    final entries = <({String id, ClubMember member})>[];
    for (final id in widget.event.playerMemberIds(widget.excludeCoachUids)) {
      final member = clubMemberForTeamUid(byUid, id);
      if (member != null) entries.add((id: id, member: member));
    }

    entries.sort((a, b) {
      final oa = order(widget.event.rsvpFor(a.id));
      final ob = order(widget.event.rsvpFor(b.id));
      if (oa != ob) return oa.compareTo(ob);
      return a.member.fullName
          .toLowerCase()
          .compareTo(b.member.fullName.toLowerCase());
    });
    return entries;
  }

  Widget _buildMembersList(TextTheme theme) {
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));

    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(ViroSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Erreur : $e'),
      data: (members) {
        final byUid = indexClubMembersByUid(members);
        final entries = _sortedEntries(byUid);

        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ViroSpacing.lg),
            child: Text(
              'Aucun membre convoqué',
              style: theme.bodyMedium?.copyWith(color: ViroColors.gray600),
            ),
          );
        }

        return Column(
          children: [
            for (final entry in entries)
              PlanningMemberRsvpRow(
                member: entry.member,
                status: widget.event.rsvpFor(entry.id),
              ),
          ],
        );
      },
    );
  }

  Future<void> _cancelEvent() async {
    final scope = await _askCancelScope();
    if (scope == null || !mounted) return;

    final service = ref.read(eventServiceProvider);
    if (scope == _CancelScope.series) {
      final seriesId = widget.event.seriesId!;
      final count = await service.cancelEventSeries(
        clubId: widget.clubId,
        seriesId: seriesId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCanceled();
      ViroSnackBar.show(
        context,
        count > 1 ? '$count événements annulés' : 'Événement annulé',
      );
      return;
    }

    await service.cancelEvent(
      clubId: widget.clubId,
      eventId: widget.event.id,
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onCanceled();
    ViroSnackBar.show(context, 'Événement annulé');
  }

  Future<_CancelScope?> _askCancelScope() async {
    if (!widget.event.isRecurringSeries) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Annuler l\'événement ?'),
          content: const Text(
            'Les membres ne verront plus cet événement dans leur planning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Annuler'),
            ),
          ],
        ),
      );
      return confirm == true ? _CancelScope.single : null;
    }

    return showDialog<_CancelScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'événement'),
        content: const Text(
          'Cet entraînement fait partie d\'une série récurrente. '
          'Que souhaitez-vous annuler ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _CancelScope.single),
            child: const Text('Cet événement seulement'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _CancelScope.series),
            child: const Text('Toute la série'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context).textTheme;
    final headline = PlanningEventDisplay.headline(event);
    final subtitle = PlanningEventDisplay.subtitle(event, widget.teamLabel);
    final location = PlanningEventDisplay.locationLine(event);
    final schedule = PlanningEventDisplay.scheduleLine(event);
    final startStr = formatEventTime(event.startTime);
    final endStr = formatEventTime(event.endTime);
    final rdvStr = formatEventTime(event.meetingTime);
    final counts = event.rsvpCountsExcluding(widget.excludeCoachUids);
    final playerCount =
        event.playerMemberIds(widget.excludeCoachUids).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(
              ViroSpacing.lg,
              ViroSpacing.md,
              ViroSpacing.lg,
              ViroSpacing.md,
            ),
            children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (startStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: ViroSpacing.md,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  startStr,
                                  style: theme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: ViroColors.primary600,
                                    height: 1.1,
                                  ),
                                ),
                                if (event.type == EventTypes.match &&
                                    rdvStr.isNotEmpty)
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
                                    size: 20,
                                    color: ViroColors.primary600,
                                  ),
                                  const SizedBox(width: ViroSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      headline,
                                      style: theme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: ViroColors.primary800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: theme.bodyLarge?.copyWith(
                                    color: ViroColors.gray600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ViroSpacing.sm),
                    Text(
                      schedule,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.gray600,
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ViroIcon(
                            ViroIcons.place,
                            size: 16,
                            color: ViroColors.gray400,
                          ),
                          const SizedBox(width: ViroSpacing.xs),
                          Expanded(
                            child: Text(
                              location,
                              style: theme.bodyMedium?.copyWith(
                                color: ViroColors.gray600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: ViroSpacing.lg),
                    Center(child: PlanningRsvpSummaryRow(counts: counts)),
                    const SizedBox(height: ViroSpacing.lg),
                    Text(
                      'Réponses ($playerCount)',
                      style: theme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ViroColors.primary800,
                      ),
                    ),
                    const SizedBox(height: ViroSpacing.sm),
                    _buildMembersList(theme),
                    if (widget.canManageEvents) ...[
                      const SizedBox(height: ViroSpacing.lg),
                      OutlinedButton(
                        onPressed: _cancelEvent,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ViroColors.error,
                          side: const BorderSide(color: ViroColors.error),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Annuler l\'événement'),
                      ),
                    ],
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ],
    );
  }
}
