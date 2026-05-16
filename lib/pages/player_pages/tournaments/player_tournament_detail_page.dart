import 'package:flutter/material.dart';

import '../../../models/tournament/tournament_match.dart';
import '../../../models/tournament/tournament_model.dart';
import '../../../models/tournament/tournament_team.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../widget/tournament/match_card.dart';
import '../../admin_coach_pages/tournaments/tournament_bracket_page.dart';
import '../../admin_coach_pages/tournaments/tournament_standings_page.dart';

class PlayerTournamentDetailPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final String userId;

  const PlayerTournamentDetailPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ViroColors.background,
        body: StreamBuilder<TournamentModel?>(
          stream: TournamentService.instance
              .watchTournament(clubId, tournamentId),
          builder: (context, snap) {
            final name = snap.data?.name ?? 'Tournoi';
            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  title: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  centerTitle: false,
                  bottom: const TabBar(
                    labelColor: ViroColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: ViroColors.primary,
                    tabs: [
                      Tab(text: 'Mon équipe'),
                      Tab(text: 'Tableau'),
                      Tab(text: 'Classement'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _MyTeamTab(
                    clubId: clubId,
                    tournamentId: tournamentId,
                    userId: userId,
                  ),
                  TournamentBracketPage(
                    clubId: clubId,
                    tournamentId: tournamentId,
                    isAdmin: false,
                  ),
                  TournamentStandingsPage(
                    clubId: clubId,
                    tournamentId: tournamentId,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MyTeamTab extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final String userId;

  const _MyTeamTab({
    required this.clubId,
    required this.tournamentId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentTeam>>(
      stream:
          TournamentService.instance.watchTeams(clubId, tournamentId),
      builder: (context, teamsSnap) {
        return StreamBuilder<List<TournamentMatch>>(
          stream: TournamentService.instance
              .watchMatches(clubId, tournamentId),
          builder: (context, matchesSnap) {
            if (teamsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final teams = teamsSnap.data ?? [];
            final matches = matchesSnap.data ?? [];
            final teamsById = {for (final t in teams) t.id: t};

            final myTeam = teams
                .where((t) => t.playerIds.contains(userId))
                .toList();

            if (myTeam.isEmpty) {
              return _buildNoTeam();
            }

            final team = myTeam.first;
            final myMatches = matches
                .where((m) =>
                    m.teamAId == team.id || m.teamBId == team.id)
                .toList()
              ..sort((a, b) =>
                  _statusOrder(a.status).compareTo(_statusOrder(b.status)));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _buildTeamCard(team),
                const SizedBox(height: 20),
                const Text(
                  'Mes matchs',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (myMatches.isEmpty)
                  const Text('Aucun match planifié.',
                      style: TextStyle(color: Colors.grey))
                else
                  ...myMatches.map((m) => MatchCard(
                        match: m,
                        teamA: m.teamAId != null
                            ? teamsById[m.teamAId]
                            : null,
                        teamB: m.teamBId != null
                            ? teamsById[m.teamBId]
                            : null,
                        isAdmin: false,
                      )),
              ],
            );
          },
        );
      },
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

  Widget _buildNoTeam() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Vous n\'êtes pas inscrit\ndans ce tournoi',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(TournamentTeam team) {
    Color teamColor;
    try {
      final hex = team.colorHex.replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = ViroColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: teamColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: teamColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: teamColor,
                ),
              ),
              Text(
                '${team.playerIds.length} joueur(s)',
                style: TextStyle(fontSize: 12, color: teamColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
