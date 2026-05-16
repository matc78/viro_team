import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../constants/firebase_collections.dart';
import '../../../../models/tournament/tournament_model.dart';
import '../../../../utils/firestore_instance.dart';

class Step2MatchFormat extends StatelessWidget {
  final String clubId;
  final int playersPerTeam;
  final VictoryFormat victoryFormat;
  final int timeDuration;
  final int pointsTarget;
  final int setsCount;

  final ValueChanged<int> onPlayersPerTeamChanged;
  final ValueChanged<VictoryFormat> onVictoryFormatChanged;
  final ValueChanged<int> onTimeDurationChanged;
  final ValueChanged<int> onPointsTargetChanged;
  final ValueChanged<int> onSetsCountChanged;

  const Step2MatchFormat({
    super.key,
    required this.clubId,
    required this.playersPerTeam,
    required this.victoryFormat,
    required this.timeDuration,
    required this.pointsTarget,
    required this.setsCount,
    required this.onPlayersPerTeamChanged,
    required this.onVictoryFormatChanged,
    required this.onTimeDurationChanged,
    required this.onPointsTargetChanged,
    required this.onSetsCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .snapshots(),
      builder: (context, snap) {
        final sport = (snap.data?.data()?['sport'] as String?)?.trim();
        final maxPlayers = _maxPlayersForSport(sport);
        final allowed = List<int>.generate(maxPlayers, (i) => i + 1);

        if (!allowed.contains(playersPerTeam)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onPlayersPerTeamChanged(maxPlayers);
          });
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Joueurs par équipe',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: allowed.map((n) {
                final selected = n == playersPerTeam;
                return ChoiceChip(
                  label: Text('${n}v$n'),
                  selected: selected,
                  onSelected: (_) => onPlayersPerTeamChanged(n),
                );
              }).toList(),
            ),
            if (sport != null && sport.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Sport: $sport (max $maxPlayers joueurs/équipe)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Format de victoire',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _FormatTile(
              title: 'Au temps',
              subtitle: 'Ex : 2 × 20 minutes',
              icon: Icons.timer_outlined,
              selected: victoryFormat == VictoryFormat.auTemps,
              onTap: () => onVictoryFormatChanged(VictoryFormat.auTemps),
            ),
            const SizedBox(height: 8),
            _FormatTile(
              title: 'Aux points',
              subtitle: 'Premier à atteindre un score',
              icon: Icons.scoreboard_outlined,
              selected: victoryFormat == VictoryFormat.auxPoints,
              onTap: () => onVictoryFormatChanged(VictoryFormat.auxPoints),
            ),
            const SizedBox(height: 8),
            _FormatTile(
              title: 'Aux sets',
              subtitle: 'Meilleur des N sets',
              icon: Icons.format_list_numbered,
              selected: victoryFormat == VictoryFormat.auxSets,
              onTap: () => onVictoryFormatChanged(VictoryFormat.auxSets),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildFormatParams(context),
            ),
          ],
        );
      },
    );
  }

  int _maxPlayersForSport(String? sport) {
    final s = (sport ?? '').toLowerCase().replaceAll('-', '').trim();
    if (s.contains('volley')) return 6;
    if (s.contains('basket')) return 5;
    if (s.contains('hand')) return 7;
    if (s.contains('futsal')) return 5;
    if (s.contains('foot') || s.contains('soccer')) return 11;
    if (s.contains('rugby')) return 15;
    return 11;
  }

  Widget _buildFormatParams(BuildContext context) {
    switch (victoryFormat) {
      case VictoryFormat.auTemps:
        return _NumberField(
          key: const ValueKey('auTemps'),
          label: 'Durée d\'une période (minutes)',
          value: timeDuration,
          min: 1,
          max: 90,
          onChanged: onTimeDurationChanged,
          hint: 'Ex : 20 pour 2 × 20 min',
        );
      case VictoryFormat.auxPoints:
        return _NumberField(
          key: const ValueKey('auxPoints'),
          label: 'Score cible',
          value: pointsTarget,
          min: 1,
          max: 200,
          onChanged: onPointsTargetChanged,
          hint: 'Ex : 21 pour premier à 21',
        );
      case VictoryFormat.auxSets:
        return _NumberField(
          key: const ValueKey('auxSets'),
          label: 'Nombre de sets',
          value: setsCount,
          min: 1,
          max: 9,
          onChanged: onSetsCountChanged,
          hint: 'Ex : 3 pour meilleur des 3',
        );
    }
  }
}

class _FormatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey[400]!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? color : Colors.black87)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(hint,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 12),
            Text(
              '$value',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
