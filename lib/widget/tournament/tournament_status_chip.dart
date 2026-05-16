import 'package:flutter/material.dart';

import '../../models/tournament/tournament_model.dart';
import '../../theme/viro_theme.dart';

/// Chip de statut partagé entre la liste et la page détail des tournois.
class TournamentStatusChip extends StatelessWidget {
  final TournamentStatus status;

  const TournamentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    final label = _label(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static Color _color(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.active:
        return ViroColors.success;
      case TournamentStatus.draft:
        return ViroColors.warning;
      case TournamentStatus.completed:
        return Colors.blueGrey;
      case TournamentStatus.archived:
        return Colors.grey;
    }
  }

  static String _label(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.active:
        return 'En cours';
      case TournamentStatus.draft:
        return 'Brouillon';
      case TournamentStatus.completed:
        return 'Terminé';
      case TournamentStatus.archived:
        return 'Archivé';
    }
  }
}
