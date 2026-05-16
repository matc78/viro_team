import 'package:flutter/material.dart';

import '../../../models/tournament/tournament_match.dart';
import '../../../models/tournament/tournament_phase.dart';
import '../../../models/tournament/tournament_team.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../widget/tournament/match_card.dart';
import '../../../widget/tournament/score_entry_dialog.dart';

class TournamentMatchesPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final bool isAdmin;

  const TournamentMatchesPage({
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

        if (matches.isEmpty) {
          return _buildEmpty();
        }

        return _buildList(context, phases, matches, teamsById);
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
            child: const Icon(Icons.sports_outlined,
                size: 32, color: ViroColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun match généré',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Les matchs apparaîtront ici\naprès la génération du tournoi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<TournamentPhase> phases,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    final List<Widget> sections = [];

    for (final phase in phases) {
      final phaseMatches =
          matches.where((m) => m.phaseId == phase.id).toList();
      if (phaseMatches.isEmpty) continue;
      sections.add(
          _buildPhaseSection(context, phase, phaseMatches, teamsById));
    }

    final orphan = matches
        .where((m) => !phases.any((p) => p.id == m.phaseId))
        .toList();
    if (orphan.isNotEmpty) {
      sections.add(_buildSection('Autres', orphan, teamsById, context));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: sections,
    );
  }

  Widget _buildPhaseSection(
    BuildContext context,
    TournamentPhase phase,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    final label = _phaseLabel(phase);

    if (phase.type == PhaseType.group) {
      final Map<int, List<TournamentMatch>> byGroup = {};
      for (final m in matches) {
        byGroup.putIfAbsent(m.groupIndex ?? 0, () => []).add(m);
      }
      final keys = byGroup.keys.toList()..sort();
      final List<Widget> children = [];
      for (final g in keys) {
        final groupMatches = byGroup[g]!;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Groupe ${String.fromCharCode(65 + g)}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[500]),
            ),
          ),
        );
        for (final m in groupMatches) {
          children.add(_buildMatchCard(context, m, teamsById));
        }
        children.add(const SizedBox(height: 8));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(label),
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 8),
        ],
      );
    }

    return _buildSection(label, matches, teamsById, context);
  }

  Widget _buildSection(
    String label,
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
    BuildContext context,
  ) {
    final ordered = List<TournamentMatch>.from(matches)
      ..sort((a, b) =>
          _statusOrder(a.status).compareTo(_statusOrder(b.status)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(label),
        const SizedBox(height: 10),
        ...ordered.map((m) => _buildMatchCard(context, m, teamsById)),
        const SizedBox(height: 8),
      ],
    );
  }

  int _statusOrder(MatchStatus s) {
    switch (s) {
      case MatchStatus.inProgress:
        return 0;
      case MatchStatus.upcoming:
        return 1;
      case MatchStatus.completed:
        return 2;
    }
  }

  Widget _sectionHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ViroColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.chevron_right,
              size: 16, color: ViroColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
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

  Widget _buildMatchCard(
    BuildContext context,
    TournamentMatch match,
    Map<String, TournamentTeam> teamsById,
  ) {
    return MatchCard(
      match: match,
      teamA: match.teamAId != null ? teamsById[match.teamAId] : null,
      teamB: match.teamBId != null ? teamsById[match.teamBId] : null,
      isAdmin: isAdmin,
      onTap: isAdmin
          ? () => _showScoreDialog(context, match, teamsById)
          : null,
    );
  }

  void _showScoreDialog(
    BuildContext context,
    TournamentMatch match,
    Map<String, TournamentTeam> teamsById,
  ) {
    final allMatches = _orderedForInput(
      TournamentService.instance
          .watchTournamentData(clubId, tournamentId)
          .first
          .then((d) => d.matches),
    );
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

  Future<List<TournamentMatch>> _orderedForInput(
    Future<List<TournamentMatch>> futureMatches,
  ) async {
    final matches = await futureMatches;
    matches.sort((a, b) {
      final phase = a.phaseIndex.compareTo(b.phaseIndex);
      if (phase != 0) return phase;
      final round = (a.round ?? 999).compareTo(b.round ?? 999);
      if (round != 0) return round;
      return (a.bracketSlot ?? a.groupIndex ?? 0)
          .compareTo(b.bracketSlot ?? b.groupIndex ?? 0);
    });
    return matches;
  }

  TournamentMatch? _nextMatch(List<TournamentMatch> matches, String currentId) {
    final actionable = matches
        .where((m) =>
            m.teamAId != null &&
            m.teamBId != null &&
            m.status != MatchStatus.completed)
        .toList();
    final index = actionable.indexWhere((m) => m.id == currentId);
    if (index < 0 || index + 1 >= actionable.length) return null;
    return actionable[index + 1];
  }

  String _phaseLabel(TournamentPhase phase) {
    switch (phase.type) {
      case PhaseType.group:
        return phase.index == 0
            ? 'Phase de groupes'
            : 'Phase intermédiaire';
      case PhaseType.knockout:
        return 'Phase finale';
      case PhaseType.consolation:
        return 'Bracket consolante';
    }
  }
}
