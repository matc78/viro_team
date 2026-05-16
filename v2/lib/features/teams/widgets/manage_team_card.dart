import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/members/widgets/member_list_tile.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/features/teams/utils/team_manage_permissions.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/features/teams/widgets/add_team_member_sheet.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';

class ManageTeamCard extends ConsumerStatefulWidget {
  const ManageTeamCard({
    super.key,
    required this.team,
    required this.club,
    required this.accent,
    required this.permissions,
    required this.viewerRole,
  });

  final ClubTeam team;
  final Club club;
  final Color accent;
  final TeamManagePermissions permissions;
  final String viewerRole;

  @override
  ConsumerState<ManageTeamCard> createState() => _ManageTeamCardState();
}

class _ManageTeamCardState extends ConsumerState<ManageTeamCard> {
  List<PendingTeamMember>? _pending;
  bool _loadingPending = false;
  bool _expanded = false;
  bool _busy = false;

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

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final perms = widget.permissions;
    final canAddPlayer = perms.canAddPlayer(team);
    final canAddCoach = perms.canAddCoach(team);
    final canRemovePlayer = perms.canRemovePlayer(team);
    final canRemoveCoach = perms.canRemoveCoach(team);
    final canRemovePending = perms.canRemovePendingPlayer(team);

    final membersAsync = ref.watch(clubMembersProvider(team.clubId));
    final membersByUid = membersAsync.value != null
        ? indexClubMembersByUid(membersAsync.value!)
        : <String, ClubMember>{};

    return ViroCard(
      margin: const EdgeInsets.only(bottom: ViroSpacing.sm),
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Theme(
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
              title: Text(
                team.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ViroColors.primary800,
                    ),
              ),
              subtitle: Text(
                team.categoryLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ViroColors.gray600,
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
                  _buildRosterSection(
                    title: 'Coachs',
                    titleColor: const Color(0xFFEA580C),
                    canAdd: canAddCoach,
                    onAdd: canAddCoach
                        ? () => _openAddSheet(TeamRosterSlot.coach)
                        : null,
                    children: team.coachIds.map((uid) {
                      final member = clubMemberForTeamUid(membersByUid, uid);
                      if (member == null) return const SizedBox.shrink();
                      return MemberListTile(
                        member: member,
                        club: widget.club,
                        viewerRole: widget.viewerRole,
                        showClubAdminActions: false,
                        onRemove: canRemoveCoach
                            ? () => _removeCoach(uid)
                            : null,
                      );
                    }),
                  ),
                  _buildRosterSection(
                    title: 'Joueurs',
                    titleColor: ViroColors.primary600,
                    canAdd: canAddPlayer,
                    onAdd: canAddPlayer
                        ? () => _openAddSheet(TeamRosterSlot.player)
                        : null,
                    children: team.playerIds.map((uid) {
                      final member = clubMemberForTeamUid(membersByUid, uid);
                      if (member == null) return const SizedBox.shrink();
                      return MemberListTile(
                        member: member,
                        club: widget.club,
                        viewerRole: widget.viewerRole,
                        showClubAdminActions: false,
                        onRemove: canRemovePlayer
                            ? () => _removePlayer(uid)
                            : null,
                      );
                    }),
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
                    else if (_pending != null && _pending!.isNotEmpty)
                      _buildRosterSection(
                        title: 'En attente',
                        titleColor: ViroColors.gray600,
                        canAdd: false,
                        children: _pending!.map(
                          (p) => MemberListTile(
                            member: pendingAsClubMember(p),
                            club: widget.club,
                            viewerRole: widget.viewerRole,
                            showClubAdminActions: false,
                            onRemove: canRemovePending
                                ? () => _removePending(p.id)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.6),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRosterSection({
    required String title,
    required Color titleColor,
    required Iterable<Widget> children,
    bool canAdd = false,
    VoidCallback? onAdd,
  }) {
    final childList = children.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: ViroSpacing.sm, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
              ),
              if (canAdd && onAdd != null)
                TextButton.icon(
                  onPressed: _busy ? null : onAdd,
                  icon: ViroIcon(ViroIcons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
            ],
          ),
        ),
        if (childList.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
            child: Text(
              'Aucun membre',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ViroColors.gray600,
                  ),
            ),
          )
        else
          ...childList,
      ],
    );
  }

  void _openAddSheet(TeamRosterSlot slot) {
    final service = ref.read(teamServiceProvider);
    final team = widget.team;

    showAddTeamMemberSheet(
      context: context,
      ref: ref,
      clubId: team.clubId,
      team: team,
      slot: slot,
      onAdd: (id) => _run(() async {
        if (slot == TeamRosterSlot.coach) {
          await service.addCoachToTeam(
            clubId: team.clubId,
            teamId: team.id,
            uid: id,
          );
          return;
        }

        final pendingIds = ref
                .read(pendingTeamMembersProvider(team.clubId))
                .value
                ?.map((p) => p.id)
                .toSet() ??
            {};
        if (pendingIds.contains(id)) {
          await service.addPendingPlayerToTeam(
            clubId: team.clubId,
            teamId: team.id,
            pendingId: id,
          );
        } else {
          await service.addPlayerToTeam(
            clubId: team.clubId,
            teamId: team.id,
            uid: id,
          );
        }
      }),
    );
  }

  Future<void> _removePlayer(String uid) => _run(() {
        return ref.read(teamServiceProvider).removePlayerFromTeam(
              clubId: widget.team.clubId,
              teamId: widget.team.id,
              uid: uid,
            );
      });

  Future<void> _removeCoach(String uid) => _run(() {
        return ref.read(teamServiceProvider).removeCoachFromTeam(
              clubId: widget.team.clubId,
              teamId: widget.team.id,
              uid: uid,
            );
      });

  Future<void> _removePending(String pendingId) => _run(() {
        return ref.read(teamServiceProvider).removePendingPlayerFromTeam(
              clubId: widget.team.clubId,
              teamId: widget.team.id,
              pendingId: pendingId,
            );
      });
}
