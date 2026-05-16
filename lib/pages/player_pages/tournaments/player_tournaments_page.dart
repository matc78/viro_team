import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/tournament/tournament_model.dart';
import '../../../models/tournament/tournament_team.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import 'player_tournament_detail_page.dart';

class PlayerTournamentsPage extends StatelessWidget {
  final String clubId;

  const PlayerTournamentsPage({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tournois & Championnats',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<TournamentModel>>(
        stream: TournamentService.instance.watchTournaments(clubId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final active = all
              .where((t) =>
                  t.status == TournamentStatus.active ||
                  t.status == TournamentStatus.draft)
              .toList();
          final past = all
              .where((t) =>
                  t.status == TournamentStatus.completed ||
                  t.status == TournamentStatus.archived)
              .toList();

          if (all.isEmpty) {
            return _buildEmpty();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('En cours'),
                const SizedBox(height: 8),
                ...active.map((t) => _PlayerTournamentCard(
                      tournament: t,
                      clubId: clubId,
                      userId: userId,
                    )),
                const SizedBox(height: 20),
              ],
              if (past.isNotEmpty) ...[
                _sectionHeader('Passés'),
                const SizedBox(height: 8),
                ...past.map((t) => _PlayerTournamentCard(
                      tournament: t,
                      clubId: clubId,
                      userId: userId,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun tournoi pour l\'instant',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _PlayerTournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final String clubId;
  final String userId;

  const _PlayerTournamentCard({
    required this.tournament,
    required this.clubId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y', 'fr_FR');
    final dateStr = dateFmt.format(tournament.startDate);

    return StreamBuilder<List<TournamentTeam>>(
      stream: TournamentService.instance
          .watchTeams(clubId, tournament.id),
      builder: (context, snap) {
        final teams = snap.data ?? [];
        final myTeam = teams
            .where((t) => t.playerIds.contains(userId))
            .toList();
        final hasTeam = myTeam.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerTournamentDetailPage(
                  clubId: clubId,
                  tournamentId: tournament.id,
                  userId: userId,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ViroColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tournament.type == TournamentType.championnat
                          ? Icons.leaderboard_outlined
                          : Icons.emoji_events_outlined,
                      color: ViroColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateStr,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (hasTeam) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Mon équipe : ${myTeam.first.name}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: ViroColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
