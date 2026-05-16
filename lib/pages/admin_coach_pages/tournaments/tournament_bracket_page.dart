import 'package:flutter/material.dart';

import '../../../models/tournament/tournament_match.dart';
import '../../../models/tournament/tournament_phase.dart';
import '../../../models/tournament/tournament_team.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../widget/tournament/bracket_widget.dart';
import '../../../widget/tournament/group_table_widget.dart';
import '../../../widget/tournament/score_entry_dialog.dart';

class TournamentBracketPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final bool isAdmin;

  const TournamentBracketPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TournamentData>(
      stream: TournamentService.instance
          .watchTournamentData(clubId, tournamentId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!;
        final phases = data.phases;
        final matches = data.matches;
        final teams = data.teams;
        final teamsById = {for (final t in teams) t.id: t};

        if (phases.isEmpty) {
          return _buildEmpty();
        }

        return _buildContent(context, phases, matches, teamsById);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ViroColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_tree_outlined,
                size: 32, color: ViroColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tableau non disponible',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Le tableau sera généré\naprès le lancement du tournoi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TournamentPhase> phases,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: phases.map((phase) {
        final phaseMatches =
            matches.where((m) => m.phaseId == phase.id).toList();

        if (phase.type == PhaseType.group) {
          return _buildGroupSection(
              context, phase, phaseMatches, teamsById);
        } else {
          return _buildKnockoutSection(
              context, phase, phaseMatches, teamsById);
        }
      }).toList(),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    TournamentPhase phase,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    final label = phase.index == 0
        ? 'Phase de groupes'
        : 'Phase intermédiaire';

    final standings = phase.computeGroupStandings(matches);
    final nbGroups = phase.nbGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label, Icons.groups_outlined),
        const SizedBox(height: 12),
        ...List.generate(nbGroups, (g) {
          final groupStandings = standings[g] ?? [];
          final groupTeamIds = matches
              .where((m) => m.groupIndex == g && m.phaseId == phase.id)
              .expand((m) => [m.teamAId, m.teamBId])
              .whereType<String>()
              .toSet();
          for (final id in groupTeamIds) {
            if (!groupStandings.any((s) => s.teamId == id)) {
              groupStandings.add(GroupStanding(teamId: id));
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GroupTableWidget(
              standings: groupStandings,
              teamsById: teamsById,
              nbQualified: phase.nbQualifiedPerGroup,
              groupLabel: 'Groupe ${String.fromCharCode(65 + g)}',
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildKnockoutSection(
    BuildContext context,
    TournamentPhase phase,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    final label = phase.type == PhaseType.consolation
        ? 'Bracket consolante'
        : 'Phase finale';
    final icon = phase.type == PhaseType.consolation
        ? Icons.device_hub_outlined
        : Icons.emoji_events_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label, icon),
        const SizedBox(height: 12),
        BracketWidget(
          matches: matches,
          teamsById: teamsById,
          isAdmin: isAdmin,
          onMatchTap: isAdmin
              ? (m) => _showScoreDialog(context, m, teamsById)
              : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ViroColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: ViroColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ViroColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showScoreDialog(
    BuildContext context,
    TournamentMatch match,
    Map<String, TournamentTeam> teamsById,
  ) {
    final allMatches = TournamentService.instance
        .watchTournamentData(clubId, tournamentId)
        .first
        .then((d) => d.matches);
    showDialog<void>(
      context: context,
      builder: (_) => ScoreEntryDialog(
        match: match,
        teamA: match.teamAId != null ? teamsById[match.teamAId] : null,
        teamB: match.teamBId != null ? teamsById[match.teamBId] : null,
        onSave: (sA, sB, completed) =>
            TournamentService.instance.updateMatchScore(
          clubId,
          tournamentId,
          match.id,
          sA,
          sB,
          markCompleted: completed,
        ),
        onSaveAndNext: () async {
          final matches = await allMatches;
          final next = _nextMatch(matches, match.id);
          if (next == null || !context.mounted) return;
          _showScoreDialog(context, next, teamsById);
        },
      ),
    );
  }

  TournamentMatch? _nextMatch(List<TournamentMatch> matches, String currentId) {
    final ordered = List<TournamentMatch>.from(matches)
      ..sort((a, b) {
        final phase = a.phaseIndex.compareTo(b.phaseIndex);
        if (phase != 0) return phase;
        final round = (a.round ?? 999).compareTo(b.round ?? 999);
        if (round != 0) return round;
        return (a.bracketSlot ?? a.groupIndex ?? 0)
            .compareTo(b.bracketSlot ?? b.groupIndex ?? 0);
      });
    final actionable = ordered
        .where((m) =>
            m.teamAId != null &&
            m.teamBId != null &&
            m.status != MatchStatus.completed)
        .toList();
    final index = actionable.indexWhere((m) => m.id == currentId);
    if (index < 0 || index + 1 >= actionable.length) return null;
    return actionable[index + 1];
  }
}
