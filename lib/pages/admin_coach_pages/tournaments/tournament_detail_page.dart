import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/tournament/tournament_model.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../widget/tournament/tournament_status_chip.dart';
import 'tournament_bracket_page.dart';
import 'tournament_matches_page.dart';
import 'tournament_standings_page.dart';

class TournamentDetailPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final bool isAdmin;

  const TournamentDetailPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ViroColors.background,
        body: StreamBuilder<TournamentModel?>(
          stream: TournamentService.instance.watchTournament(clubId, tournamentId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _UnifiedState(
                icon: Icons.hourglass_top_rounded,
                title: 'Chargement du tournoi',
                message: 'Patientez quelques secondes.',
              );
            }
            if (snap.hasError) {
              return _UnifiedState(
                icon: Icons.wifi_off_rounded,
                title: 'Erreur de chargement',
                message: 'Vérifiez la connexion puis réessayez.',
                actionLabel: 'Réessayer',
                onAction: () => Navigator.of(context).maybePop(),
              );
            }

            final tournament = snap.data;
            if (tournament == null) {
              return const _UnifiedState(
                icon: Icons.hide_source_outlined,
                title: 'Tournoi introuvable',
                message: 'Il a peut-être été supprimé.',
              );
            }

            return _DetailScaffold(
              clubId: clubId,
              tournamentId: tournamentId,
              tournament: tournament,
              isAdmin: isAdmin,
            );
          },
        ),
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final TournamentModel tournament;
  final bool isAdmin;

  const _DetailScaffold({
    required this.clubId,
    required this.tournamentId,
    required this.tournament,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            title: Text(
              tournament.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: TournamentStatusChip(status: tournament.status),
                ),
              ),
            ],
            bottom: const TabBar(
              labelColor: ViroColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: ViroColors.primary,
              tabs: [
                Tab(text: 'Matchs'),
                Tab(text: 'Tableau'),
                Tab(text: 'Classement'),
              ],
            ),
          ),
          SliverToBoxAdapter(child: _TournamentHeader(tournament: tournament)),
        ],
        body: TabBarView(
          children: [
            TournamentMatchesPage(
              clubId: clubId,
              tournamentId: tournamentId,
              isAdmin: isAdmin,
            ),
            TournamentBracketPage(
              clubId: clubId,
              tournamentId: tournamentId,
              isAdmin: isAdmin,
            ),
            TournamentStandingsPage(
              clubId: clubId,
              tournamentId: tournamentId,
            ),
          ],
        ),
      ),
      bottomNavigationBar: isAdmin
          ? _AdminFixedActionBar(clubId: clubId, tournament: tournament)
          : null,
    );
  }
}

class _TournamentHeader extends StatelessWidget {
  final TournamentModel tournament;

  const _TournamentHeader({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y', 'fr_FR');
    final dateStr = dateFmt.format(tournament.startDate);
    final endStr = tournament.endDate != null ? ' → ${dateFmt.format(tournament.endDate!)}' : '';

    final formatLabel = _formatLabel(
      tournament.victoryFormat,
      tournament.timeDurationMinutes,
      tournament.pointsTarget,
      tournament.setsCount,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _InfoChip(icon: Icons.calendar_today_outlined, label: '$dateStr$endStr'),
          _InfoChip(icon: Icons.group_outlined, label: '${tournament.playersPerTeam}v${tournament.playersPerTeam}'),
          _InfoChip(icon: Icons.sports_score_outlined, label: formatLabel),
          _InfoChip(icon: Icons.account_tree_outlined, label: _structureLabel(tournament.structure)),
        ],
      ),
    );
  }

  String _formatLabel(VictoryFormat fmt, int time, int pts, int sets) {
    switch (fmt) {
      case VictoryFormat.auTemps:
        return '2 × $time min';
      case VictoryFormat.auxPoints:
        return 'Premier à $pts';
      case VictoryFormat.auxSets:
        return 'Meilleur des $sets sets';
    }
  }

  String _structureLabel(TournamentStructure s) {
    switch (s) {
      case TournamentStructure.championnatSeul:
        return 'Championnat';
      case TournamentStructure.tournoiSeul:
        return 'Tournoi direct';
      case TournamentStructure.poulesVersTournoi:
        return 'Poules → Final';
      case TournamentStructure.poulesInterVersTournoi:
        return 'Poules → Inter → Final';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ViroColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class _AdminFixedActionBar extends StatelessWidget {
  final String clubId;
  final TournamentModel tournament;

  const _AdminFixedActionBar({required this.clubId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final status = tournament.status;
    if (status == TournamentStatus.archived) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            if (status == TournamentStatus.active) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirm(
                    context,
                    title: 'Terminer le tournoi',
                    message: 'Marquer ce tournoi comme terminé ?',
                    successMessage: 'Tournoi terminé.',
                    onConfirm: () => TournamentService.instance.updateStatus(
                      clubId,
                      tournament.id,
                      TournamentStatus.completed,
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Terminer'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  DefaultTabController.of(context).animateTo(0);
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(status == TournamentStatus.active ? 'Saisir scores' : 'Voir les matchs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViroColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (status == TournamentStatus.completed) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Archiver',
                onPressed: () => _confirm(
                  context,
                  title: 'Archiver le tournoi',
                  message: 'Ce tournoi sera masqué de la liste principale.',
                  successMessage: 'Tournoi archivé.',
                  onConfirm: () => TournamentService.instance.updateStatus(
                    clubId,
                    tournament.id,
                    TournamentStatus.archived,
                  ),
                ),
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String successMessage,
    required Future<void> Function() onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await onConfirm();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(successMessage),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ViroColors.success,
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Action impossible. Réessayez.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ViroColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

class _UnifiedState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _UnifiedState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: ViroColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: ViroColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
