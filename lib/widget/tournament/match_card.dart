import 'package:flutter/material.dart';

import '../../models/tournament/tournament_match.dart';
import '../../models/tournament/tournament_team.dart';
import '../../theme/viro_theme.dart';

class MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final TournamentTeam? teamA;
  final TournamentTeam? teamB;
  final bool isAdmin;
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.match,
    this.teamA,
    this.teamB,
    this.isAdmin = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBye = match.teamAId == null || match.teamBId == null;
    final isCompleted = match.status == MatchStatus.completed;
    final isInProgress = match.status == MatchStatus.inProgress;
    final showScoreEntry = isAdmin && !isBye && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInProgress
              ? ViroColors.primary.withValues(alpha: 0.4)
              : ViroColors.borderColor,
          width: isInProgress ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: (isAdmin && !isBye) ? onTap : null,
        child: Column(
          children: [
            // Contenu principal
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Équipe A
                  Expanded(
                    child: _TeamSide(
                      team: teamA,
                      score: isCompleted || isInProgress
                          ? match.scoreA
                          : null,
                      isWinner:
                          isCompleted && match.winnerId == match.teamAId,
                      align: CrossAxisAlignment.start,
                    ),
                  ),

                  // Score / Séparateur
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildCenter(isCompleted, isInProgress, isBye),
                  ),

                  // Équipe B
                  Expanded(
                    child: _TeamSide(
                      team: teamB,
                      score: isCompleted || isInProgress
                          ? match.scoreB
                          : null,
                      isWinner:
                          isCompleted && match.winnerId == match.teamBId,
                      align: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ),

            // Bandeau "Saisir score" pour admin
            if (showScoreEntry)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isInProgress
                      ? ViroColors.primary.withValues(alpha: 0.08)
                      : ViroColors.secondary.withValues(alpha: 0.6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: ViroColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isInProgress ? 'Mettre à jour le score' : 'Saisir le score',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ViroColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(bool completed, bool inProgress, bool bye) {
    if (bye) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('BYE',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w600)),
      );
    }
    if (completed) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${match.scoreA} - ${match.scoreB}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1),
        ),
      );
    }
    if (inProgress) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ViroColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${match.scoreA} - ${match.scoreB}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ViroColors.primary,
              letterSpacing: 1),
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('vs',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  final TournamentTeam? team;
  final int? score;
  final bool isWinner;
  final CrossAxisAlignment align;

  const _TeamSide({
    required this.team,
    required this.score,
    required this.isWinner,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    Color teamColor;
    try {
      final hex = (team?.colorHex ?? '#888888').replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = Colors.grey;
    }

    final name = team?.name ?? 'À définir';

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: align == CrossAxisAlignment.start
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (isWinner && align == CrossAxisAlignment.end)
              const Icon(Icons.star_rounded,
                  size: 13, color: ViroColors.warning),
            if (align == CrossAxisAlignment.start)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                ),
              ),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isWinner ? ViroColors.text : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (align == CrossAxisAlignment.end)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                ),
              ),
            if (isWinner && align == CrossAxisAlignment.start)
              const Icon(Icons.star_rounded,
                  size: 13, color: ViroColors.warning),
          ],
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isWinner ? ViroColors.primary : Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
