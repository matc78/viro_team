import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/features/teams/utils/team_manage_permissions.dart';
import 'package:viro_team_v2/features/teams/widgets/create_team_dialog.dart';
import 'package:viro_team_v2/features/teams/widgets/manage_team_card.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_floating_icon_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ManageTeamsScreen extends ConsumerWidget {
  const ManageTeamsScreen({super.key, required this.clubId});

  final String clubId;

  Future<void> _createTeam(BuildContext context, WidgetRef ref, String sport) async {
    final result = await showCreateTeamDialog(context: context, sport: sport);
    if (result == null || !context.mounted) return;

    try {
      await ref.read(teamServiceProvider).createTeam(
            clubId: clubId,
            name: result.name,
            category: result.category,
          );
      if (context.mounted) {
        ViroSnackBar.show(context, 'Équipe créée');
      }
    } catch (e) {
      if (context.mounted) {
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(clubTeamsProvider(clubId));
    final clubAsync = ref.watch(clubProvider(clubId));
    final memberAsync = ref.watch(clubMemberProvider(clubId));
    final authUid = ref.watch(authStateProvider).value?.uid;

    final viewerRole = memberAsync.value?.role ?? MemberRoles.player;
    final permissions = TeamManagePermissions(
      viewerRole: viewerRole,
      currentUid: authUid,
    );

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Gérer les équipes'),
      ),
      floatingActionButton: permissions.canCreateTeam()
          ? clubAsync.maybeWhen(
              data: (club) {
                if (club == null) return null;
                return ViroFloatingActionButton(
                  icon: ViroIcons.add,
                  onPressed: () => _createTeam(context, ref, club.sport),
                );
              },
              orElse: () => null,
            )
          : null,
      body: clubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (club) {
          if (club == null) {
            return const Center(child: Text('Club introuvable'));
          }

          final accent = clubAccentColor(
            brandColorHex: club.brandColorHex,
            clubId: club.id,
          );

          return teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (teams) {
              if (teams.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ViroSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Aucune équipe pour ce club.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: ViroColors.gray600,
                                  ),
                        ),
                        if (permissions.canCreateTeam()) ...[
                          const SizedBox(height: ViroSpacing.lg),
                          FilledButton.icon(
                            onPressed: () =>
                                _createTeam(context, ref, club.sport),
                            icon: ViroIcon(ViroIcons.add),
                            label: const Text('Créer une équipe'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  ViroSpacing.screenHorizontal,
                  ViroSpacing.md,
                  ViroSpacing.screenHorizontal,
                  ViroSpacing.xl,
                ),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  return ManageTeamCard(
                    team: teams[index],
                    club: club,
                    accent: accent,
                    permissions: permissions,
                    viewerRole: viewerRole,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
