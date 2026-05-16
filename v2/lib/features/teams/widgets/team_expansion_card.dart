import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/members/widgets/member_list_tile.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class TeamExpansionCard extends ConsumerStatefulWidget {
  const TeamExpansionCard({
    super.key,
    required this.team,
    required this.club,
    required this.accent,
  });

  final ClubTeam team;
  final Club club;
  final Color accent;

  @override
  ConsumerState<TeamExpansionCard> createState() => _TeamExpansionCardState();
}

class _TeamExpansionCardState extends ConsumerState<TeamExpansionCard> {
  List<PendingTeamMember>? _pending;
  bool _loadingPending = false;
  bool _expanded = false;

  Future<void> _loadPending() async {
    if (_pending != null || widget.team.pendingPlayerIds.isEmpty) return;
    setState(() => _loadingPending = true);

    final pending = await ref.read(teamServiceProvider).fetchPendingMembers(
          clubId: widget.team.clubId,
          pendingIds: widget.team.pendingPlayerIds,
        );

    if (!mounted) return;
    setState(() {
      _pending = pending;
      _loadingPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final theme = Theme.of(context).textTheme;
    final club = widget.club;
    final hasAvatar = team.avatarUrl != null && team.avatarUrl!.isNotEmpty;
    final useClubLogo =
        !hasAvatar && club.logoUrl != null && club.logoUrl!.isNotEmpty;

    final membersAsync = ref.watch(clubMembersProvider(team.clubId));
    final viewerRole =
        ref.watch(clubMemberProvider(team.clubId)).value?.role ??
            MemberRoles.player;
    final membersByUid = membersAsync.value != null
        ? indexClubMembersByUid(membersAsync.value!)
        : <String, ClubMember>{};

    return ViroCard(
      margin: const EdgeInsets.only(bottom: ViroSpacing.sm),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _expanded = expanded);
            if (expanded) _loadPending();
          },
          tilePadding: const EdgeInsets.symmetric(
            horizontal: ViroSpacing.md,
            vertical: ViroSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            ViroSpacing.md,
            0,
            ViroSpacing.md,
            ViroSpacing.md,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: widget.accent.withValues(alpha: 0.12),
            backgroundImage: hasAvatar
                ? NetworkImage(team.avatarUrl!)
                : useClubLogo
                    ? NetworkImage(club.logoUrl!)
                    : null,
            child: hasAvatar || useClubLogo
                ? null
                : ViroIcon(ViroIcons.users, color: widget.accent),
          ),
          title: Text(
            team.name,
            style: theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: ViroColors.primary800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                team.categoryLabel,
                style: theme.labelSmall?.copyWith(
                  color: widget.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          children: [
            const Divider(height: 1),
            if (!_expanded)
              const SizedBox.shrink()
            else if (membersAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(ViroSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              ..._buildMemberSection(
                context,
                title: 'Staff / Coachs',
                uids: team.coachIds,
                membersByUid: membersByUid,
                viewerRole: viewerRole,
              ),
              ..._buildMemberSection(
                context,
                title: 'Coéquipiers',
                uids: team.playerIds,
                membersByUid: membersByUid,
                viewerRole: viewerRole,
              ),
              if (team.pendingPlayerIds.isNotEmpty) ...[
                if (_loadingPending)
                  const Padding(
                    padding: EdgeInsets.all(ViroSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_pending != null && _pending!.isNotEmpty) ...[
                  _sectionHeader(context, 'En attente', ViroColors.gray600),
                  ..._pending!.map(
                    (p) => MemberListTile(
                      member: pendingAsClubMember(p),
                      club: club,
                      viewerRole: viewerRole,
                      showClubAdminActions: false,
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMemberSection(
    BuildContext context, {
    required String title,
    required List<String> uids,
    required Map<String, ClubMember> membersByUid,
    required String viewerRole,
  }) {
    if (uids.isEmpty) return [];

    final titleColor = title.contains('Coach')
        ? const Color(0xFFEA580C)
        : ViroColors.primary600;

    return [
      _sectionHeader(context, title, titleColor),
      ...uids.map((uid) {
        final member = clubMemberForTeamUid(membersByUid, uid);
        if (member == null) return const SizedBox.shrink();
        return MemberListTile(
          member: member,
          club: widget.club,
          viewerRole: viewerRole,
          showClubAdminActions: false,
        );
      }),
    ];
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: ViroSpacing.sm, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
