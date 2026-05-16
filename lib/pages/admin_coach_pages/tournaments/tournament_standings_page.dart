import 'package:flutter/material.dart';

import '../../../models/tournament/tournament_team.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';

class TournamentStandingsPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;

  const TournamentStandingsPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
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
        final standings = TournamentService.instance
            .computeFinalStandingsSync(data.matches, data.teams);
        final teamsById = {for (final t in data.teams) t.id: t};

        if (standings.isEmpty) {
          return _buildEmpty();
        }
        return _buildContent(standings, teamsById);
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
            child: const Icon(Icons.emoji_events_outlined,
                size: 32, color: ViroColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Classement non disponible',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Le classement final s\'affichera\naprès la fin du tournoi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<TournamentStanding> standings,
    Map<String, TournamentTeam> teamsById,
  ) {
    final top3 = standings.where((s) => s.rank <= 3).toList();
    final rest = standings.where((s) => s.rank > 3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        if (top3.length >= 2) _buildPodium(top3, teamsById),
        const SizedBox(height: 24),

        if (rest.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'CLASSEMENT COMPLET',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.grey,
                    letterSpacing: 1.2),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ...standings.map((s) => _buildRow(s, teamsById[s.teamId])),
        ] else ...[
          ...standings.map((s) => _buildRow(s, teamsById[s.teamId])),
        ],
      ],
    );
  }

  Widget _buildPodium(
    List<TournamentStanding> top3,
    Map<String, TournamentTeam> teamsById,
  ) {
    final first =
        top3.firstWhere((s) => s.rank == 1, orElse: () => top3.first);
    final second = top3.where((s) => s.rank == 2).toList();
    final third = top3.where((s) => s.rank == 3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ViroColors.primary.withValues(alpha: 0.08),
            ViroColors.secondary.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: ViroColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Text(
            '🏆 Podium',
            style:
                TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second.isNotEmpty)
                _PodiumSlot(
                  rank: 2,
                  teamName:
                      teamsById[second.first.teamId]?.name ??
                          second.first.teamId,
                  medal: '🥈',
                  height: 70,
                  color: Colors.grey[400]!,
                ),
              _PodiumSlot(
                rank: 1,
                teamName:
                    teamsById[first.teamId]?.name ?? first.teamId,
                medal: '🥇',
                height: 90,
                color: const Color(0xFFFFD700),
              ),
              if (third.isNotEmpty)
                _PodiumSlot(
                  rank: 3,
                  teamName:
                      teamsById[third.first.teamId]?.name ??
                          third.first.teamId,
                  medal: '🥉',
                  height: 55,
                  color: const Color(0xFFCD7F32),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(TournamentStanding s, TournamentTeam? team) {
    final name = team?.name ?? s.teamId;
    Color teamColor;
    try {
      final hex = (team?.colorHex ?? '#888888').replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = Colors.grey;
    }

    final medalEmoji = s.rank == 1
        ? '🥇'
        : s.rank == 2
            ? '🥈'
            : s.rank == 3
                ? '🥉'
                : null;

    // Couleur de fond pour le top 3
    final Color? rowBg = s.rank == 1
        ? const Color(0xFFFFD700).withValues(alpha: 0.07)
        : s.rank == 2
            ? Colors.grey.withValues(alpha: 0.07)
            : s.rank == 3
                ? const Color(0xFFCD7F32).withValues(alpha: 0.07)
                : null;

    final Color borderColor = s.rank == 1
        ? const Color(0xFFFFD700).withValues(alpha: 0.4)
        : s.rank == 2
            ? Colors.grey.withValues(alpha: 0.3)
            : s.rank == 3
                ? const Color(0xFFCD7F32).withValues(alpha: 0.3)
                : ViroColors.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rowBg ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medalEmoji != null
                ? Text(medalEmoji,
                    style: const TextStyle(fontSize: 18))
                : Text(
                    '${s.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: teamColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: s.rank <= 3
                    ? FontWeight.w700
                    : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (s.points > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ViroColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s.points} pts',
                style: const TextStyle(
                  fontSize: 12,
                  color: ViroColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final int rank;
  final String teamName;
  final String medal;
  final double height;
  final Color color;

  const _PodiumSlot({
    required this.rank,
    required this.teamName,
    required this.medal,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            teamName,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
          ),
        ),
      ],
    );
  }
}
