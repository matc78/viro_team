import 'dart:math';

import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/fees/models/fee_tier.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';

class FeeTierEditor extends StatelessWidget {
  const FeeTierEditor({
    super.key,
    required this.tiers,
    required this.onChanged,
    this.onDeleteTier,
  });

  final List<FeeTier> tiers;
  final ValueChanged<List<FeeTier>> onChanged;
  final Future<bool> Function(FeeTier tier)? onDeleteTier;

  void _addTier() {
    onChanged([
      ...tiers,
      FeeTier(
        tierId: 'tier_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
        label: '',
        amountCents: 0,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
            child: _TierRow(
              tier: tiers[i],
              onUpdate: (updated) {
                final next = List<FeeTier>.from(tiers);
                next[i] = updated;
                onChanged(next);
              },
              onDelete: () async {
                if (onDeleteTier != null) {
                  final ok = await onDeleteTier!(tiers[i]);
                  if (!ok) return;
                }
                final next = List<FeeTier>.from(tiers)..removeAt(i);
                onChanged(next);
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: _addTier,
          icon: ViroIcon(ViroIcons.add, size: 18),
          label: const Text('Ajouter une catégorie'),
        ),
      ],
    );
  }
}

class _TierRow extends StatefulWidget {
  const _TierRow({
    required this.tier,
    required this.onUpdate,
    required this.onDelete,
  });

  final FeeTier tier;
  final ValueChanged<FeeTier> onUpdate;
  final Future<void> Function() onDelete;

  @override
  State<_TierRow> createState() => _TierRowState();
}

class _TierRowState extends State<_TierRow> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.tier.label);
    final euros = widget.tier.amountCents / 100;
    _amountCtrl = TextEditingController(
      text: euros > 0 ? euros.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final cents = parseAmountToCents(_amountCtrl.text) ?? 0;
    widget.onUpdate(
      widget.tier.copyWith(
        label: _labelCtrl.text.trim(),
        amountCents: cents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              hintText: 'U14',
            ),
            onChanged: (_) => _emit(),
          ),
        ),
        const SizedBox(width: ViroSpacing.sm),
        Expanded(
          child: TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Montant (€)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _emit(),
          ),
        ),
        IconButton(
          icon: ViroIcon(ViroIcons.trash, color: ViroColors.error),
          onPressed: () => widget.onDelete(),
        ),
      ],
    );
  }
}
