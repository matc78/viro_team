import 'package:flutter/material.dart';

import '../../models/tournament/tournament_match.dart';
import '../../models/tournament/tournament_team.dart';
import '../../theme/viro_theme.dart';

/// Affiche un bracket éliminatoire sous forme de colonnes par round.
/// Les matchs sont triés par round décroissant (premier tour à gauche).
class BracketWidget extends StatelessWidget {
  final List<TournamentMatch> matches;
  final Map<String, TournamentTeam> teamsById;
  final bool isAdmin;
  final void Function(TournamentMatch)? onMatchTap;

  const BracketWidget({
    super.key,
    required this.matches,
    required this.teamsById,
    this.isAdmin = false,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Bracket non disponible.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Grouper par round
    final Map<int, List<TournamentMatch>> byRound = {};
    for (final m in matches) {
      final r = m.round ?? 0;
      byRound.putIfAbsent(r, () => []).add(m);
    }

    // Trier les rounds : plus grand round = premier tour (à gauche)
    final sortedRounds = byRound.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedRounds.map((round) {
          final roundMatches = byRound[round]!
            ..sort((a, b) => (a.bracketSlot ?? 0)
                .compareTo(b.bracketSlot ?? 0));
          return _RoundColumn(
            round: round,
            matches: roundMatches,
            teamsById: teamsById,
            isAdmin: isAdmin,
            onMatchTap: onMatchTap,
          );
        }).toList(),
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  final int round;
  final List<TournamentMatch> matches;
  final Map<String, TournamentTeam> teamsById;
  final bool isAdmin;
  final void Function(TournamentMatch)? onMatchTap;

  const _RoundColumn({
    required this.round,
    required this.matches,
    required this.teamsById,
    required this.isAdmin,
    required this.onMatchTap,
  });

  String _roundLabel(int round) {
    switch (round) {
      case 0:
        return 'Finale';
      case 1:
        return 'Demi-finales';
      case 2:
        return 'Quarts de finale';
      case 3:
        return 'Huitièmes de finale';
      default:
        return 'Tour ${round + 1}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label du round
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: ViroColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roundLabel(round),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: ViroColors.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...matches.map((m) => _BracketMatchCard(
                match: m,
                teamA: m.teamAId != null ? teamsById[m.teamAId] : null,
                teamB: m.teamBId != null ? teamsById[m.teamBId] : null,
                isAdmin: isAdmin,
                onTap: onMatchTap != null ? () => onMatchTap!(m) : null,
              )),
        ],
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final TournamentTeam? teamA;
  final TournamentTeam? teamB;
  final bool isAdmin;
  final VoidCallback? onTap;

  const _BracketMatchCard({
    required this.match,
    this.teamA,
    this.teamB,
    required this.isAdmin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBye = match.teamAId == null || match.teamBId == null;
    final isCompleted = match.status == MatchStatus.completed;
    final isPlaceholder = match.teamAId == null && match.teamBId == null;

    return GestureDetector(
      onTap: (isAdmin && !isBye && !isPlaceholder) ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isPlaceholder ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaceholder
                ? Colors.grey[200]!
                : isCompleted
                    ? Colors.grey[300]!
                    : ViroColors.borderColor,
          ),
        ),
        child: Column(
          children: [
            _SlotRow(
              team: teamA,
              score: isCompleted || match.status == MatchStatus.inProgress
                  ? match.scoreA
                  : null,
              isWinner: isCompleted && match.winnerId == match.teamAId,
              isBye: match.teamBId == null && match.teamAId != null,
            ),
            Divider(height: 1, color: Colors.grey[200]),
            _SlotRow(
              team: teamB,
              score: isCompleted || match.status == MatchStatus.inProgress
                  ? match.scoreB
                  : null,
              isWinner: isCompleted && match.winnerId == match.teamBId,
              isBye: match.teamAId == null && match.teamBId != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final TournamentTeam? team;
  final int? score;
  final bool isWinner;
  final bool isBye;

  const _SlotRow({
    required this.team,
    required this.score,
    required this.isWinner,
    required this.isBye,
  });

  @override
  Widget build(BuildContext context) {
    Color teamColor;
    try {
      final hex = (team?.colorHex ?? '#CCCCCC').replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isWinner
            ? ViroColors.primary.withValues(alpha: 0.05)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: team != null ? teamColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              isBye
                  ? 'BYE'
                  : (team?.name ?? '—'),
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isWinner ? FontWeight.w700 : FontWeight.w500,
                color: team == null
                    ? Colors.grey[400]
                    : isWinner
                        ? ViroColors.primary
                        : Colors.black87,
                fontStyle:
                    isBye ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score != null)
            Text(
              '$score',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isWinner ? ViroColors.primary : Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}
