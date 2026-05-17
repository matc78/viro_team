import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/planning/providers/planning_providers.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/features/planning/utils/planning_event_display.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_day_picker.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_event_detail_sheet.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_event_tile.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/widgets/common/viro_floating_icon_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubPlanningScreen extends ConsumerStatefulWidget {
  const ClubPlanningScreen({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<ClubPlanningScreen> createState() => _ClubPlanningScreenState();
}

class _ClubPlanningScreenState extends ConsumerState<ClubPlanningScreen> {
  final _dayScrollController = ScrollController();
  List<DateTime> _days = [];
  bool _daysReady = false;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _initDays();
  }

  Future<void> _initDays() async {
    final first = await ref
        .read(eventServiceProvider)
        .getFirstEventDate(widget.clubId);
    if (!mounted) return;
    setState(() {
      _days = buildPlanningDays(firstEventDate: first);
      _daysReady = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollPlanningToDay(
        controller: _dayScrollController,
        days: _days,
        day: _selectedDay,
      );
    });
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = day);
    scrollPlanningToDay(
      controller: _dayScrollController,
      days: _days,
      day: day,
    );
  }

  void _showEventSheet(
    ClubEvent event,
    Map<String, ClubTeam> teamsById, {
    required bool canManage,
  }) {
    PlanningEventDetailSheet.show(
      context: context,
      ref: ref,
      clubId: widget.clubId,
      event: event,
      teamLabel: PlanningEventDisplay.teamLabel(event, teamsById),
      excludeCoachUids:
          PlanningEventDisplay.coachUidsToExclude(event, teamsById),
      canManageEvents: canManage,
      onCanceled: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubId;
    final member = ref.watch(clubMemberProvider(clubId)).value;
    final canManage = member != null &&
        MemberRoleHierarchy.isCoachOrAbove(member.role);
    final dayParams = (clubId: clubId, day: _selectedDay);
    final eventsAsync = canManage
        ? ref.watch(clubPlanningEventsProvider(dayParams))
        : ref.watch(memberClubPlanningEventsProvider(dayParams));
    final teamsAsync = ref.watch(clubTeamsProvider(clubId));

    final teamsById = teamsAsync.value?.fold<Map<String, ClubTeam>>(
          {},
          (map, t) => map..[t.id] = t,
        ) ??
        {};

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Planning'),
      ),
      floatingActionButton: canManage
          ? ViroFloatingActionButton(
              icon: ViroIcons.add,
              onPressed: () {
                final iso = _selectedDay.toIso8601String().split('T').first;
                context.push(AppRoutes.clubAddEventPath(clubId, date: iso));
              },
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: ViroSpacing.sm),
          if (!_daysReady)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_days.isNotEmpty)
            PlanningDayPicker(
              days: _days,
              selectedDay: _selectedDay,
              scrollController: _dayScrollController,
              onDaySelected: _selectDay,
            ),
          const Divider(height: 1, color: ViroColors.gray200),
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (events) {
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(ViroSpacing.xl),
                      child: Text(
                        canManage
                            ? 'Aucun événement ce jour-là.\nAppuyez sur + pour en créer un.'
                            : 'Aucun événement ce jour-là.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ViroColors.gray600,
                            ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    ViroSpacing.screenHorizontal,
                    ViroSpacing.md,
                    ViroSpacing.screenHorizontal,
                    ViroSpacing.xl,
                  ),
                  itemCount: events.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ViroSpacing.sm),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final label =
                        PlanningEventDisplay.teamLabel(event, teamsById);
                    final excludeCoaches =
                        PlanningEventDisplay.coachUidsToExclude(
                      event,
                      teamsById,
                    );
                    return PlanningEventTile(
                      event: event,
                      teamLabel: label,
                      excludeCoachUids: excludeCoaches,
                      onTap: () => _showEventSheet(
                        event,
                        teamsById,
                        canManage: canManage,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
