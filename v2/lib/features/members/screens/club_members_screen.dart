import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/members/widgets/add_member_sheet.dart';
import 'package:viro_team_v2/features/members/widgets/change_role_sheet.dart';
import 'package:viro_team_v2/features/members/widgets/member_list_tile.dart';
import 'package:viro_team_v2/features/members/widgets/parents_section.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_floating_icon_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubMembersScreen extends ConsumerStatefulWidget {
  const ClubMembersScreen({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends ConsumerState<ClubMembersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canAdd {
    final member = ref.read(clubMemberProvider(widget.clubId)).value;
    if (member == null) return false;
    return member.role == MemberRoles.admin ||
        member.role == MemberRoles.coach;
  }

  bool get _isAdmin {
    final member = ref.read(clubMemberProvider(widget.clubId)).value;
    return member?.role == MemberRoles.admin;
  }

  List<ClubMember> _filterMembers(List<ClubMember> members) {
    return members.where((m) {
      if (_roleFilter != null && m.role != _roleFilter) return false;
      if (_search.isEmpty) return true;
      return m.fullName.toLowerCase().contains(_search.toLowerCase());
    }).toList();
  }

  Widget _roleFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? ViroColors.white : ViroColors.primary800,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: ViroColors.primary600,
      backgroundColor: ViroColors.gray50,
      side: BorderSide(
        color: selected ? ViroColors.primary600 : ViroColors.gray200,
      ),
    );
  }

  Future<void> _addMember() async {
    final form = await showAddMemberSheet(context);
    if (form == null || !mounted) return;

    final club = await ref.read(clubForMembersProvider(widget.clubId).future);
    final auth = ref.read(authStateProvider).value;
    if (club == null || auth == null) return;

    try {
      await ref.read(memberServiceProvider).addMemberWithInvitation(
            clubId: widget.clubId,
            firstName: form.firstName,
            lastName: form.lastName,
            role: form.role,
            sentByUid: auth.uid,
            club: club,
          );

      if (!mounted) return;

      ViroSnackBar.show(context, '${form.firstName} ajouté(e)');
    } catch (e) {
      if (!mounted) return;
      ViroSnackBar.show(context, 'Erreur : $e');
    }
  }

  Future<void> _changeRole(ClubMember member) async {
    final newRole = await showChangeRoleSheet(context, member: member);
    if (newRole == null || newRole == member.role) return;

    try {
      await ref.read(memberServiceProvider).updateMemberRole(
            clubId: widget.clubId,
            memberId: member.memberId,
            newRole: newRole,
          );
    } catch (e) {
      if (!mounted) return;
      ViroSnackBar.show(context, 'Erreur : $e');
    }
  }

  Future<void> _removeMember(ClubMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: Text(
          '${member.fullName} sera retiré(e) du club.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(memberServiceProvider).removeMember(
            clubId: widget.clubId,
            memberId: member.memberId,
          );
    } catch (e) {
      if (!mounted) return;
      ViroSnackBar.show(context, 'Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubId;
    final membersAsync = ref.watch(clubMembersProvider(clubId));
    final clubAsync = ref.watch(clubForMembersProvider(clubId));

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Gérer les membres'),
      ),
      floatingActionButton: _canAdd
          ? ViroFloatingActionButton(
              icon: ViroIcons.add,
              onPressed: _addMember,
            )
          : null,
      body: clubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (club) {
          if (club == null) {
            return const Center(child: Text('Club introuvable'));
          }

          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (members) {
              final viewerRole =
                  ref.watch(clubMemberProvider(clubId)).value?.role ??
                      MemberRoles.player;
              final filtered = _filterMembers(members);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ViroSpacing.screenHorizontal,
                        ViroSpacing.md,
                        ViroSpacing.screenHorizontal,
                        ViroSpacing.sm,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un membre…',
                          prefixIcon: ViroIcon(ViroIcons.search),
                        ),
                        onChanged: (v) => setState(() => _search = v.trim()),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ViroSpacing.screenHorizontal,
                      ),
                      child: Row(
                        children: [
                          _roleFilterChip(
                            label: 'Tous',
                            selected: _roleFilter == null,
                            onSelected: (_) =>
                                setState(() => _roleFilter = null),
                          ),
                          const SizedBox(width: ViroSpacing.xs),
                          _roleFilterChip(
                            label: 'Joueurs',
                            selected: _roleFilter == MemberRoles.player,
                            onSelected: (_) => setState(
                              () => _roleFilter = MemberRoles.player,
                            ),
                          ),
                          const SizedBox(width: ViroSpacing.xs),
                          _roleFilterChip(
                            label: 'Coachs',
                            selected: _roleFilter == MemberRoles.coach,
                            onSelected: (_) => setState(
                              () => _roleFilter = MemberRoles.coach,
                            ),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(width: ViroSpacing.xs),
                            _roleFilterChip(
                              label: 'Admins',
                              selected: _roleFilter == MemberRoles.admin,
                              onSelected: (_) => setState(
                                () => _roleFilter = MemberRoles.admin,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _search.isNotEmpty
                              ? 'Aucun membre trouvé'
                              : 'Aucun membre pour le moment',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: ViroColors.gray600),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        ViroSpacing.screenHorizontal,
                        ViroSpacing.sm,
                        ViroSpacing.screenHorizontal,
                        ViroSpacing.md,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final member = filtered[index];
                            return MemberListTile(
                              member: member,
                              club: club,
                              viewerRole: viewerRole,
                              onChangeRole: _isAdmin
                                  ? () => _changeRole(member)
                                  : null,
                              onRemove: _isAdmin
                                  ? () => _removeMember(member)
                                  : null,
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: ParentsSection(clubId: clubId),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: ViroSpacing.xl),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
