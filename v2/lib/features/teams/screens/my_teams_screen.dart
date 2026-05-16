import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/features/teams/widgets/team_expansion_card.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class MyTeamsScreen extends ConsumerWidget {
  const MyTeamsScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubProvider(clubId));
    final teamsAsync = ref.watch(myTeamsProvider(clubId));

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mes équipes'),
      ),
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
                    child: Text(
                      'Tu n\'es affecté à aucune équipe pour le moment.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: ViroColors.gray600,
                          ),
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
                  return TeamExpansionCard(
                    team: teams[index],
                    club: club,
                    accent: accent,
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
