import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/tournament/tournament_model.dart';
import '../../../services/tournament_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../widget/tournament/tournament_status_chip.dart';
import 'create_tournament/create_tournament_wizard.dart';
import 'tournament_detail_page.dart';

enum _QuickFilter { all, active, upcoming, finished }

class TournamentListPage extends StatefulWidget {
  final String clubId;

  const TournamentListPage({super.key, required this.clubId});

  @override
  State<TournamentListPage> createState() => _TournamentListPageState();
}

class _TournamentListPageState extends State<TournamentListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  _QuickFilter _filter = _QuickFilter.active;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_tournament',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateTournamentWizard(clubId: widget.clubId),
          ),
        ),
        backgroundColor: ViroColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Créer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<TournamentModel>>(
        stream: TournamentService.instance.watchTournaments(widget.clubId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildStateBox(
              icon: Icons.hourglass_top_rounded,
              title: 'Chargement des tournois',
              message: 'Patientez quelques secondes.',
            );
          }
          if (snap.hasError) {
            return _buildStateBox(
              icon: Icons.wifi_off_rounded,
              title: 'Impossible de charger',
              message: 'Vérifiez la connexion puis réessayez.',
              actionLabel: 'Réessayer',
              onAction: () => setState(() {}),
            );
          }

          final filtered = _applyFilterAndSort(snap.data ?? []);
          if (filtered.isEmpty) {
            final hasSearch = _searchCtrl.text.trim().isNotEmpty;
            return _buildStateBox(
              icon: hasSearch ? Icons.search_off_rounded : Icons.emoji_events_outlined,
              title: hasSearch ? 'Aucun résultat' : 'Aucun tournoi',
              message: hasSearch
                  ? 'Essayez un autre mot-clé ou un filtre différent.'
                  : 'Créez votre premier tournoi pour démarrer.',
              actionLabel: hasSearch ? 'Effacer la recherche' : 'Créer un tournoi',
              onAction: hasSearch
                  ? () => setState(() => _searchCtrl.clear())
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreateTournamentWizard(clubId: widget.clubId),
                        ),
                      ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _buildSearchAndFilters(),
              const SizedBox(height: 14),
              ...filtered.map(
                (t) => _TournamentCard(tournament: t, clubId: widget.clubId),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Rechercher un tournoi',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() => _searchCtrl.clear()),
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _filterChip('Actifs', _QuickFilter.active),
            _filterChip('À venir', _QuickFilter.upcoming),
            _filterChip('Terminés', _QuickFilter.finished),
            _filterChip('Tous', _QuickFilter.all),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _QuickFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: ViroColors.primary.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected ? ViroColors.primary : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: selected ? ViroColors.primary : Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
    );
  }

  List<TournamentModel> _applyFilterAndSort(List<TournamentModel> input) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();

    final items = input.where((t) {
      final matchesSearch = query.isEmpty || t.name.toLowerCase().contains(query);
      if (!matchesSearch) return false;

      switch (_filter) {
        case _QuickFilter.active:
          return t.status == TournamentStatus.active;
        case _QuickFilter.upcoming:
          return t.status == TournamentStatus.draft || t.startDate.isAfter(now);
        case _QuickFilter.finished:
          return t.status == TournamentStatus.completed || t.status == TournamentStatus.archived;
        case _QuickFilter.all:
          return true;
      }
    }).toList();

    items.sort((a, b) {
      final statusCompare = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (statusCompare != 0) return statusCompare;

      final aFinished = a.status == TournamentStatus.completed || a.status == TournamentStatus.archived;
      if (aFinished) {
        return b.startDate.compareTo(a.startDate);
      }
      return a.startDate.compareTo(b.startDate);
    });

    return items;
  }

  int _statusRank(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.active:
        return 0;
      case TournamentStatus.draft:
        return 1;
      case TournamentStatus.completed:
        return 2;
      case TournamentStatus.archived:
        return 3;
    }
  }

  Widget _buildStateBox({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final String clubId;

  const _TournamentCard({
    required this.tournament,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y', 'fr_FR');
    final dateStr = dateFmt.format(tournament.startDate);
    final endStr = tournament.endDate != null
        ? ' → ${dateFmt.format(tournament.endDate!)}'
        : '';
    final typeLabel = tournament.type == TournamentType.championnat
        ? 'Championnat'
        : 'Tournoi';
    final typeIcon = tournament.type == TournamentType.championnat
        ? Icons.leaderboard_outlined
        : Icons.emoji_events_outlined;
    final structureLabel = _structureLabel(tournament.structure);

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
            builder: (_) => TournamentDetailPage(
              clubId: clubId,
              tournamentId: tournament.id,
              isAdmin: true,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ViroColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: ViroColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ViroColors.primary.withValues(alpha: 0.75),
                          ),
                        ),
                        Text(
                          ' · $structureLabel',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr$endStr',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TournamentStatusChip(status: tournament.status),
            ],
          ),
        ),
      ),
    );
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
