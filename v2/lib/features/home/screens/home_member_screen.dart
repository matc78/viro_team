import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/home/providers/home_teams_provider.dart';
import 'package:viro_team_v2/features/home/providers/member_events_provider.dart';
import 'package:viro_team_v2/features/clubs/widgets/add_club_sheet.dart';
import 'package:viro_team_v2/features/home/widgets/club_selector_bar.dart';
import 'package:viro_team_v2/features/planning/utils/planning_event_display.dart';
import 'package:viro_team_v2/features/planning/widgets/planning_event_detail_sheet.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/features/home/widgets/event_planning_card.dart';
import 'package:viro_team_v2/features/home/widgets/planning_day_section_header.dart';
import 'package:viro_team_v2/features/home/widgets/home_quiet_content.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/widgets/common/section_shimmer.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class HomeMemberScreen extends ConsumerStatefulWidget {
  const HomeMemberScreen({super.key});

  @override
  ConsumerState<HomeMemberScreen> createState() => _HomeMemberScreenState();
}

class _HomeMemberScreenState extends ConsumerState<HomeMemberScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Map<String, String> _clubNames(List<UserClubEntry> clubs) => {
        for (final e in clubs) e.$1.id: e.$1.name,
      };

  Map<String, Color> _clubColors(List<UserClubEntry> clubs) => {
        for (final e in clubs)
          e.$1.id: clubAccentColor(
            brandColorHex: e.$1.brandColorHex,
            clubId: e.$1.id,
          ),
      };

  void _showEventDetail({
    required ClubEvent event,
    required Map<String, ClubTeam> teams,
    required bool canManageEvents,
  }) {
    PlanningEventDetailSheet.show(
      context: context,
      ref: ref,
      clubId: event.clubId,
      event: event,
      teamLabel: PlanningEventDisplay.teamLabel(event, teams),
      excludeCoachUids: PlanningEventDisplay.coachUidsToExclude(
        event,
        teams,
        membersByUid: ref.read(clubMembersProvider(event.clubId)).value != null
            ? indexClubMembersByUid(
                ref.read(clubMembersProvider(event.clubId)).value!,
              )
            : null,
      ),
      canManageEvents: canManageEvents,
      onCanceled: () {},
    );
  }

  Future<void> _setRsvp(ClubEvent event, RsvpStatus status) async {
    final authUid = ref.read(authStateProvider).value?.uid;
    if (authUid == null) return;

    final eventService = ref.read(eventServiceProvider);
    final audienceId = await eventService.resolveAudienceId(
      clubId: event.clubId,
      authUid: authUid,
    );

    await eventService.updateRsvp(
      clubId: event.clubId,
      eventId: event.id,
      uid: audienceId,
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(userClubsProvider);
    final eventsAsync = ref.watch(memberEventsProvider);
    final teamsByClub = ref.watch(homeClubTeamsProvider).value ??
        const <String, Map<String, ClubTeam>>{};
    final pendingCounts = ref.watch(pendingCountByClubProvider);
    final userAsync = ref.watch(viroUserProvider);

    return ViroScaffold(
      appBar: ViroAppBar(
        title: const Text(ProjectConfig.appName),
        onTitleTap: _scrollToTop,
        actions: [
          IconButton(
            icon: ViroIcon(ViroIcons.user),
            onPressed: () => context.go(AppRoutes.entry),
          ),
        ],
      ),
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (clubs) {
          if (clubs.isEmpty) {
            return _EmptyClubsBody(
              onJoin: () => showAddClubSheet(context, ref),
            );
          }

          final names = _clubNames(clubs);
          final colors = _clubColors(clubs);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClubSelectorBar(
                clubs: clubs,
                pendingByClub: pendingCounts,
                onAddClub: () => showAddClubSheet(context, ref),
              ),
              Expanded(
                child: eventsAsync.when(
                  loading: () => const _HomeLoadingBody(),
                  error: (e, _) => Center(child: Text('Erreur : $e')),
                  data: (state) {
                    final isFullyQuiet = state.upcoming.isEmpty;
                    final firstName = userAsync.value?.firstName;

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(memberEventsProvider);
                        ref.invalidate(userClubsProvider);
                        ref.invalidate(userClubsWithEventsProvider);
                        ref.invalidate(viroUserFutureProvider);
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (!isFullyQuiet)
                            SliverToBoxAdapter(
                              child: _SectionTitle(
                                icon: ViroIcons.calendar,
                                title: 'Planning à venir',
                              ),
                            ),
                          if (isFullyQuiet)
                            SliverToBoxAdapter(
                              child: HomeQuietContent(
                                clubs: clubs,
                                firstName: firstName,
                              ),
                            )
                          else
                            _UpcomingEventsSliver(
                              events: state.upcoming,
                              names: names,
                              colors: colors,
                              teamsByClub: teamsByClub,
                              onShowDetail: _showEventDetail,
                              onSetRsvp: _setRsvp,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingEventsSliver extends ConsumerWidget {
  const _UpcomingEventsSliver({
    required this.events,
    required this.names,
    required this.colors,
    required this.teamsByClub,
    required this.onShowDetail,
    required this.onSetRsvp,
  });

  final List<ClubEvent> events;
  final Map<String, String> names;
  final Map<String, Color> colors;
  final Map<String, Map<String, ClubTeam>> teamsByClub;
  final void Function({
    required ClubEvent event,
    required Map<String, ClubTeam> teams,
    required bool canManageEvents,
  }) onShowDetail;
  final Future<void> Function(ClubEvent event, RsvpStatus status) onSetRsvp;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <({DateTime day, List<ClubEvent> events})>[];
    for (final event in events) {
      final day = _dateOnly(event.date);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add((day: day, events: [event]));
      } else {
        groups.last.events.add(event);
      }
    }

    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      children.add(
        PlanningDaySectionHeader(day: group.day, compactTop: g == 0),
      );
      for (final event in group.events) {
        children.add(_buildEventCard(ref, event));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        ViroSpacing.screenHorizontal,
        0,
        ViroSpacing.screenHorizontal,
        ViroSpacing.xl,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate(children),
      ),
    );
  }

  Widget _buildEventCard(WidgetRef ref, ClubEvent event) {
    final uid = ref.read(authStateProvider).value?.uid;
    final teams = teamsByClub[event.clubId] ?? {};
    final clubMembers = ref.watch(clubMembersProvider(event.clubId)).value;
    final membersByUid = clubMembers != null
        ? indexClubMembersByUid(clubMembers)
        : null;
    final exclude = PlanningEventDisplay.coachUidsToExclude(
      event,
      teams,
      membersByUid: membersByUid,
    );
    final counts = event.rsvpCountsExcluding(exclude);
    final clubMember = ref.watch(clubMemberProvider(event.clubId)).value;
    final audienceId = uid != null ? (clubMember?.memberId ?? uid) : null;
    final audienceKeys =
        clubMember != null ? eventAudienceKeys(clubMember) : null;
    final invited = uid != null &&
        PlanningEventDisplay.isInvitedAsPlayerOnEvent(
          event,
          uid,
          teams,
          clubAudienceId: audienceId,
          member: clubMember,
          membersByUid: membersByUid,
        );
    final isCoach = uid != null &&
        PlanningEventDisplay.isCoachForEvent(
          event,
          uid,
          teams,
          member: clubMember,
          membersByUid: membersByUid,
        );
    final coachView = isCoach && !invited;
    final status = uid != null
        ? event.rsvpStatusForUser(
            uid,
            clubAudienceId: audienceId,
            memberAudienceKeys: audienceKeys,
          )
        : RsvpStatus.none;
    final canManageEvents = clubMember != null &&
        MemberRoleHierarchy.isCoachOrAbove(clubMember.role);

    return EventPlanningCard(
      event: event,
      clubName: names[event.clubId] ?? 'Club',
      clubColor: colors[event.clubId] ?? ViroColors.primary600,
      coachView: coachView,
      teamRsvpCounts: counts,
      onCoachTap: coachView
          ? () => onShowDetail(
                event: event,
                teams: teams,
                canManageEvents: canManageEvents,
              )
          : null,
      onLongPress: () => onShowDetail(
        event: event,
        teams: teams,
        canManageEvents: canManageEvents,
      ),
      rsvpStatus: coachView ? null : status,
      showRsvpButtons: invited && !coachView && status == RsvpStatus.none,
      onToggleRsvp: coachView
          ? null
          : () {
              if (uid == null) return;
              final next =
                  status == RsvpStatus.yes ? RsvpStatus.no : RsvpStatus.yes;
              onSetRsvp(event, next);
            },
      onPresent: coachView ? null : () => onSetRsvp(event, RsvpStatus.yes),
      onAbsent: coachView ? null : () => onSetRsvp(event, RsvpStatus.no),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ViroSpacing.screenHorizontal,
        ViroSpacing.md,
        ViroSpacing.screenHorizontal,
        ViroSpacing.sm,
      ),
      child: Row(
        children: [
          ViroIcon(icon, size: 20, color: ViroColors.primary800),
          const SizedBox(width: ViroSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingBody extends StatelessWidget {
  const _HomeLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(ViroSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionShimmer(itemCount: 3),
        ],
      ),
    );
  }
}

class _EmptyClubsBody extends StatelessWidget {
  const _EmptyClubsBody({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Rejoignez un club pour voir votre planning',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: ViroSpacing.lg),
          ViroPrimaryButton(
            label: 'Créer ou rejoindre un club',
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}
