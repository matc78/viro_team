import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/club_fee_settings.dart';
import '../../models/fee_season.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/viro_loader.dart';
import 'admin_fee_dashboard_page.dart';
import 'widgets/fee_admin_bottom_nav.dart';

/// Liste des saisons de cotisation du club.
/// Point d'entrée de la fonctionnalité cotisations pour les admins/coachs.
class AdminFeeSeasonListPage extends StatelessWidget {
  final String clubId;

  const AdminFeeSeasonListPage({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(title: const Text('Cotisations'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle saison'),
      ),
      bottomNavigationBar: const FeeAdminBottomNav(currentIndex: 2),
      body: StreamBuilder<List<FeeSeason>>(
        stream: FeeService.instance.watchSeasons(clubId),
        builder: (context, snap) {
          if (!snap.hasData &&
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 48));
          }
          // Tri : active d'abord, puis par date de création desc
          final seasons = List<FeeSeason>.from(snap.data ?? [])
            ..sort((a, b) {
              if (a.isActive && !b.isActive) return -1;
              if (!a.isActive && b.isActive) return 1;
              return b.createdAt.compareTo(a.createdAt);
            });

          if (seasons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.euro_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune saison de cotisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crée ta première saison pour commencer\n'
                      'le suivi des cotisations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer la première saison'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SeasonTile(
              season: seasons[i],
              clubId: clubId,
              allSeasons: seasons,
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CreateSeasonDialog(clubId: clubId),
    );
  }
}

class _SeasonTile extends StatelessWidget {
  final FeeSeason season;
  final String clubId;
  final List<FeeSeason> allSeasons;

  const _SeasonTile({
    required this.season,
    required this.clubId,
    required this.allSeasons,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlinePassed = season.paymentDeadlineAt != null &&
        today.isAfter(DateTime(
          season.paymentDeadlineAt!.year,
          season.paymentDeadlineAt!.month,
          season.paymentDeadlineAt!.day,
        ));

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: season.isActive
            ? BorderSide(color: ViroColors.primary.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminFeeDashboardPage(clubId: clubId, seasonId: season.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Libellé + badge actif
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            season.seasonLabel.isEmpty
                                ? '(sans libellé)'
                                : season.seasonLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: season.isActive
                                  ? ViroColors.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (season.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ViroColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ViroColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Sous-titre : date + nb paliers + deadline
                    Text(
                      _buildSubtitle(deadlinePassed),
                      style: TextStyle(
                        fontSize: 12,
                        color: deadlinePassed ? ViroColors.error : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!season.isActive)
                PopupMenuButton<_SeasonAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _handleAction(context, action),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: _SeasonAction.activate,
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Activer cette saison'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(bool deadlinePassed) {
    final parts = <String>[];
    parts.add('Créée le ${DateFormat.yMMMd('fr_FR').format(season.createdAt)}');
    if (season.tiers.isNotEmpty) {
      parts.add('${season.tiers.length} palier${season.tiers.length > 1 ? 's' : ''}');
    }
    if (season.paymentDeadlineAt != null) {
      final label = deadlinePassed ? 'Échéance dépassée' : 'Échéance';
      parts.add('$label ${DateFormat('d MMM', 'fr_FR').format(season.paymentDeadlineAt!)}');
    }
    return parts.join(' · ');
  }

  Future<void> _handleAction(BuildContext context, _SeasonAction action) async {
    switch (action) {
      case _SeasonAction.activate:
        try {
          await FeeService.instance.setActiveSeason(clubId, season.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '« ${season.seasonLabel} » est maintenant la saison active.',
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) FirebaseErrorHandler.showErrorSnackBar(context, e);
        }
    }
  }
}

enum _SeasonAction { activate }

/// Dialogue de création d'une nouvelle saison.
class _CreateSeasonDialog extends StatefulWidget {
  final String clubId;

  const _CreateSeasonDialog({required this.clubId});

  @override
  State<_CreateSeasonDialog> createState() => _CreateSeasonDialogState();
}

class _CreateSeasonDialogState extends State<_CreateSeasonDialog> {
  final _labelCtrl = TextEditingController();
  String? _sourceSeasonId;
  bool _setActive = true;
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate => _labelCtrl.text.trim().isNotEmpty;

  Future<void> _create(List<FeeSeason> existingSeasons) async {
    if (!_canCreate || _saving) return;
    setState(() => _saving = true);
    try {
      FeeSeason? source;
      if (_sourceSeasonId != null) {
        source = existingSeasons.firstWhere((s) => s.id == _sourceSeasonId);
      }

      final newSeason = FeeSeason(
        id: '',
        seasonLabel: _labelCtrl.text.trim(),
        isActive: _setActive,
        createdAt: DateTime.now(),
        tiers: source != null ? List<FeeTier>.from(source.tiers) : [],
        paymentInstructions: source?.paymentInstructions ?? '',
        paymentDeadlineAt: null,
        currency: source?.currency ?? 'EUR',
      );

      final id = await FeeService.instance.createSeason(widget.clubId, newSeason);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AdminFeeDashboardPage(clubId: widget.clubId, seasonId: id),
        ),
      );
    } catch (e) {
      if (mounted) FirebaseErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FeeSeason>>(
      stream: FeeService.instance.watchSeasons(widget.clubId),
      builder: (context, snap) {
        final seasons = snap.data ?? [];
        final sourceSeason = _sourceSeasonId != null
            ? seasons.firstWhere(
                (s) => s.id == _sourceSeasonId,
                orElse: () => seasons.first,
              )
            : null;

        return AlertDialog(
          title: const Text('Nouvelle saison'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _labelCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Libellé de la saison',
                    hintText: 'ex. 2025-2026',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (seasons.isNotEmpty) ...[
                  const Divider(height: 28),
                  Text(
                    'Dupliquer depuis',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ViroColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _sourceSeasonId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Saison vierge'),
                          ),
                          for (final s in seasons)
                            DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                s.seasonLabel.isEmpty ? '(sans libellé)' : s.seasonLabel,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _sourceSeasonId = v),
                      ),
                    ),
                  ),
                  // Résumé des éléments copiés
                  if (sourceSeason != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ViroColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ce qui sera copié :',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ViroColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (sourceSeason.tiers.isNotEmpty)
                            Text(
                              '• ${sourceSeason.tiers.length} palier${sourceSeason.tiers.length > 1 ? 's' : ''} '
                              '(${sourceSeason.tiers.map((t) => t.label).join(', ')})',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          if (sourceSeason.paymentInstructions.trim().isNotEmpty)
                            Text(
                              '• Instructions de paiement',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          Text(
                            '• La date limite reste à définir',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activer cette saison immédiatement'),
                  subtitle: const Text(
                    'Les joueurs verront cette saison dans « Ma cotisation ».',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _setActive,
                  onChanged: (v) => setState(() => _setActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: (_saving || !_canCreate) ? null : () => _create(seasons),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Créer'),
            ),
          ],
        );
      },
    );
  }
}
