import 'package:flutter/material.dart';

import '../../../../models/tournament/tournament_model.dart';
import '../../../../theme/viro_theme.dart';

class Step3Structure extends StatelessWidget {
  final TournamentStructure structure;
  final int nbGroups;
  final int nbQualifiedPerGroup;
  final bool hasIntermediate;
  final int nbIntermediateGroups;
  final int nbQualifiedFromIntermediate;
  final bool hasConsolation;

  final ValueChanged<TournamentStructure> onStructureChanged;
  final ValueChanged<int> onNbGroupsChanged;
  final ValueChanged<int> onNbQualifiedPerGroupChanged;
  final ValueChanged<bool> onHasIntermediateChanged;
  final ValueChanged<int> onNbIntermediateGroupsChanged;
  final ValueChanged<int> onNbQualifiedFromIntermediateChanged;
  final ValueChanged<bool> onHasConsolationChanged;

  const Step3Structure({
    super.key,
    required this.structure,
    required this.nbGroups,
    required this.nbQualifiedPerGroup,
    required this.hasIntermediate,
    required this.nbIntermediateGroups,
    required this.nbQualifiedFromIntermediate,
    required this.hasConsolation,
    required this.onStructureChanged,
    required this.onNbGroupsChanged,
    required this.onNbQualifiedPerGroupChanged,
    required this.onHasIntermediateChanged,
    required this.onNbIntermediateGroupsChanged,
    required this.onNbQualifiedFromIntermediateChanged,
    required this.onHasConsolationChanged,
  });

  bool get _hasGroups =>
      structure == TournamentStructure.poulesVersTournoi ||
      structure == TournamentStructure.poulesInterVersTournoi ||
      structure == TournamentStructure.championnatSeul;

  bool get _hasKnockout =>
      structure == TournamentStructure.tournoiSeul ||
      structure == TournamentStructure.poulesVersTournoi ||
      structure == TournamentStructure.poulesInterVersTournoi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Format global',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 10),
        ..._structureOptions.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StructureTile(
              label: opt.$1,
              description: opt.$2,
              icon: opt.$3,
              selected: structure == opt.$4,
              onTap: () => onStructureChanged(opt.$4),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Config poules
        if (_hasGroups && structure != TournamentStructure.championnatSeul) ...[
          _sectionTitle('Configuration des poules'),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Nombre de poules',
            value: nbGroups,
            min: 1,
            max: 16,
            onChanged: onNbGroupsChanged,
          ),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Qualifiés par poule',
            value: nbQualifiedPerGroup,
            min: 1,
            max: 8,
            onChanged: onNbQualifiedPerGroupChanged,
          ),
          const SizedBox(height: 20),
        ],

        // Phase intermédiaire
        if (structure == TournamentStructure.poulesInterVersTournoi) ...[
          _sectionTitle('Phase intermédiaire'),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Nombre de nouvelles poules',
            value: nbIntermediateGroups,
            min: 1,
            max: 16,
            onChanged: onNbIntermediateGroupsChanged,
          ),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Qualifiés par poule (inter)',
            value: nbQualifiedFromIntermediate,
            min: 1,
            max: 8,
            onChanged: onNbQualifiedFromIntermediateChanged,
          ),
          const SizedBox(height: 20),
        ],

        // Bracket consolante
        if (_hasKnockout) ...[
          _sectionTitle('Options'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bracket consolante'),
            subtitle: const Text(
              'Les éliminés jouent un bracket parallèle pour le classement complet',
              style: TextStyle(fontSize: 12),
            ),
            value: hasConsolation,
            activeThumbColor: ViroColors.primary,
            onChanged: onHasConsolationChanged,
          ),
        ],
      ],
    );
  }

  static const _structureOptions = [
    (
      'Championnat seul',
      'Tous contre tous — classement final par points',
      Icons.leaderboard_outlined,
      TournamentStructure.championnatSeul,
    ),
    (
      'Tournoi seul',
      'Bracket éliminatoire direct',
      Icons.account_tree_outlined,
      TournamentStructure.tournoiSeul,
    ),
    (
      'Poules → Tournoi final',
      'Phase de groupes puis bracket éliminatoire',
      Icons.filter_list,
      TournamentStructure.poulesVersTournoi,
    ),
    (
      'Poules → Phase inter → Tournoi final',
      'Deux phases de groupes puis bracket',
      Icons.filter_alt_outlined,
      TournamentStructure.poulesInterVersTournoi,
    ),
  ];

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.grey,
            letterSpacing: 0.3),
      );
}

class _StructureTile extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StructureTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? primary : Colors.grey[400], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected ? primary : Colors.black87)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14))),
        IconButton.outlined(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove, size: 16),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add, size: 16),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
