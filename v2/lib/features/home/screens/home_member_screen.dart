import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/home/providers/member_events_provider.dart';
import 'package:viro_team_v2/features/home/widgets/club_selector_bar.dart';
import 'package:viro_team_v2/features/home/widgets/event_planning_card.dart';
import 'package:viro_team_v2/features/home/widgets/event_rsvp_card.dart';
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
  final _hiddenPendingIds = <String>{};
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

  String _eventKey(ClubEvent e) => '${e.clubId}_${e.id}';

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

  Future<void> _setRsvp(ClubEvent event, RsvpStatus status) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _hiddenPendingIds.add(_eventKey(event)));

    await ref.read(eventServiceProvider).updateRsvp(
          clubId: event.clubId,
          eventId: event.id,
          uid: uid,
          status: status,
        );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(userClubsProvider);
    final eventsAsync = ref.watch(memberEventsProvider);
    final pendingCounts = ref.watch(pendingCountByClubProvider);
    final userAsync = ref.watch(viroUserFutureProvider);
    final theme = Theme.of(context).textTheme;

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
              onJoin: () => context.go(AppRoutes.entry),
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
              ),
              Expanded(
                child: eventsAsync.when(
                  loading: () => const _HomeLoadingBody(),
                  error: (e, _) => Center(child: Text('Erreur : $e')),
                  data: (state) {
                    final pending = state.pending
                        .where((e) => !_hiddenPendingIds.contains(_eventKey(e)))
                        .toList();
                    final isFullyQuiet =
                        pending.isEmpty && state.upcoming.isEmpty;
                    final firstName = userAsync.value?.firstName;

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(memberEventsProvider);
                        ref.invalidate(userClubsProvider);
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (pending.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _SectionTitle(
                                icon: ViroIcons.bell,
                                title: 'À répondre',
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ViroSpacing.screenHorizontal,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final event = pending[index];
                                    return AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: EventRsvpCard(
                                        event: event,
                                        clubName:
                                            names[event.clubId] ?? 'Club',
                                        clubColor:
                                            colors[event.clubId] ??
                                                ViroColors.primary600,
                                        onPresent: () => _setRsvp(
                                          event,
                                          RsvpStatus.yes,
                                        ),
                                        onAbsent: () => _setRsvp(
                                          event,
                                          RsvpStatus.no,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: pending.length,
                                ),
                              ),
                            ),
                          ],
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
                          else if (state.upcoming.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  ViroSpacing.screenHorizontal,
                                  0,
                                  ViroSpacing.screenHorizontal,
                                  ViroSpacing.lg,
                                ),
                                child: Text(
                                  'Aucun autre événement à venir',
                                  style: theme.bodyMedium?.copyWith(
                                    color: ViroColors.gray600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                ViroSpacing.screenHorizontal,
                                0,
                                ViroSpacing.screenHorizontal,
                                ViroSpacing.xl,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final event = state.upcoming[index];
                                    final uid = ref
                                        .read(authStateProvider)
                                        .value
                                        ?.uid;
                                    final status = uid != null
                                        ? event.rsvpFor(uid)
                                        : RsvpStatus.none;

                                    return EventPlanningCard(
                                      event: event,
                                      clubName:
                                          names[event.clubId] ?? 'Club',
                                      clubColor: colors[event.clubId] ??
                                          ViroColors.primary600,
                                      rsvpStatus: status,
                                      showRsvpButtons:
                                          status == RsvpStatus.none,
                                      onToggleRsvp: () {
                                        if (uid == null) return;
                                        final next = status == RsvpStatus.yes
                                            ? RsvpStatus.no
                                            : RsvpStatus.yes;
                                        _setRsvp(event, next);
                                      },
                                      onPresent: () => _setRsvp(
                                        event,
                                        RsvpStatus.yes,
                                      ),
                                      onAbsent: () => _setRsvp(
                                        event,
                                        RsvpStatus.no,
                                      ),
                                    );
                                  },
                                  childCount: state.upcoming.length,
                                ),
                              ),
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
          SectionShimmer(itemCount: 2),
          SizedBox(height: ViroSpacing.lg),
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
            label: 'Rejoindre un club',
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}
