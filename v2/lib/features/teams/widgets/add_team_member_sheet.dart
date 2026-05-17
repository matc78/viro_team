import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/members/widgets/member_avatar.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

enum TeamRosterSlot { player, coach }

Future<void> showAddTeamMemberSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String clubId,
  required ClubTeam team,
  required TeamRosterSlot slot,
  required Future<void> Function(String id) onAdd,
}) async {
  await ref.read(teamServiceProvider).reconcileStaleRosterIds(clubId);

  if (!context.mounted) return;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => _AddTeamMemberSheet(
        clubId: clubId,
        team: team,
        slot: slot,
        scrollController: scrollController,
        onAdd: onAdd,
      ),
    ),
  );
}

class _AddTeamMemberSheet extends ConsumerWidget {
  const _AddTeamMemberSheet({
    required this.clubId,
    required this.team,
    required this.slot,
    required this.scrollController,
    required this.onAdd,
  });

  final String clubId;
  final ClubTeam team;
  final TeamRosterSlot slot;
  final ScrollController scrollController;
  final Future<void> Function(String id) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(clubMembersProvider(clubId));
    final pendingAsync = ref.watch(pendingTeamMembersProvider(clubId));
    final title = slot == TeamRosterSlot.coach
        ? 'Ajouter un coach'
        : 'Ajouter un joueur';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(ViroSpacing.md),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ViroColors.primary800,
                ),
          ),
        ),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (members) {
              if (slot == TeamRosterSlot.coach) {
                return _buildMemberList(
                  context,
                  members
                      .where(
                        (m) =>
                            m.isActive &&
                            (m.role == MemberRoles.coach ||
                                m.role == MemberRoles.admin) &&
                            m.effectiveUid.isNotEmpty &&
                            !team.isOnCoachRoster(m),
                      )
                      .toList(),
                );
              }

              return pendingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (pending) {
                  final eligible = members
                      .where(_canAddAsPlayer)
                      .toList();
                  final players = eligible
                      .where((m) => m.role == MemberRoles.player)
                      .toList();
                  final staffAsPlayers = eligible
                      .where(
                        (m) =>
                            m.role == MemberRoles.coach ||
                            m.role == MemberRoles.admin,
                      )
                      .toList();
                  final pendingAvailable = pending
                      .where(
                        (p) => _isPendingAvailableToAdd(
                          pending: p,
                          team: team,
                          members: members,
                        ),
                      )
                      .toList();

                  if (players.isEmpty &&
                      staffAsPlayers.isEmpty &&
                      pendingAvailable.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ViroSpacing.xl),
                        child: Text(
                          'Aucun joueur disponible à ajouter.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ViroColors.gray600,
                              ),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ViroSpacing.screenHorizontal,
                    ),
                    children: [
                      if (players.isNotEmpty) ...[
                        _sectionLabel(context, 'Joueurs du club'),
                        ...players.map(
                          (m) => _MemberPickTile(
                            member: m,
                            onTap: () => _add(context, m.effectiveUid),
                          ),
                        ),
                      ],
                      if (staffAsPlayers.isNotEmpty) ...[
                        if (players.isNotEmpty)
                          const SizedBox(height: ViroSpacing.md),
                        _sectionLabel(context, 'Coachs et admins'),
                        ...staffAsPlayers.map(
                          (m) => _MemberPickTile(
                            member: m,
                            onTap: () => _add(context, m.effectiveUid),
                          ),
                        ),
                      ],
                      if (pendingAvailable.isNotEmpty) ...[
                        const SizedBox(height: ViroSpacing.md),
                        _sectionLabel(context, 'En attente de compte'),
                        ...pendingAvailable.map(
                          (p) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ViroColors.primary100,
                              child: Icon(
                                Icons.person_outline,
                                color: ViroColors.primary600,
                              ),
                            ),
                            title: Text(
                              p.fullName.isEmpty ? '—' : p.fullName,
                            ),
                            trailing: ViroIcon(
                              ViroIcons.add,
                              color: ViroColors.primary600,
                            ),
                            onTap: () => _add(context, p.id),
                          ),
                        ),
                      ],
                      const SizedBox(height: ViroSpacing.xl),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberList(BuildContext context, List<ClubMember> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.xl),
          child: Text(
            'Aucun coach disponible à ajouter.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ViroColors.gray600,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.screenHorizontal,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final m = items[index];
        return _MemberPickTile(
          member: m,
          onTap: () => _add(context, m.effectiveUid),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ViroColors.gray600,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Future<void> _add(BuildContext context, String id) async {
    Navigator.pop(context);
    await onAdd(id);
  }

  bool _canAddAsPlayer(ClubMember m) =>
      m.isActive &&
      m.effectiveUid.isNotEmpty &&
      !team.isOnPlayerRoster(m) &&
      (m.role == MemberRoles.player ||
          m.role == MemberRoles.coach ||
          m.role == MemberRoles.admin);

  static bool _isPendingAvailableToAdd({
    required PendingTeamMember pending,
    required ClubTeam team,
    required List<ClubMember> members,
  }) {
    if (team.isPendingOnRoster(pending.id)) return false;
    if (team.playerIds.contains(pending.id)) return false;

    final email = pending.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final linkedOnRoster = members.any(
        (m) =>
            m.hasLinkedAccount &&
            (m.email?.trim().toLowerCase() == email) &&
            team.isOnPlayerRoster(m),
      );
      if (linkedOnRoster) return false;
    }
    return true;
  }
}

class _MemberPickTile extends StatelessWidget {
  const _MemberPickTile({
    required this.member,
    required this.onTap,
  });

  final ClubMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: MemberAvatar(member: member, size: 40),
      title: Text(
        member.fullName.isEmpty ? 'Membre' : member.fullName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: ViroIcon(ViroIcons.add, color: ViroColors.primary600),
      onTap: onTap,
    );
  }
}
