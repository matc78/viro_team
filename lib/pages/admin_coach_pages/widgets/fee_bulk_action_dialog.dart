import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/club_fee_settings.dart';
import '../../../models/member_fee.dart';
import '../../../services/fee_service.dart';
import '../../../theme/viro_theme.dart';
import '../../../utils/fee_format.dart';
import '../../../utils/firebase_error_handler.dart';

/// Dialogue : appliquer un palier et/ou un statut aux joueurs sélectionnés.
/// Retourne `true` si la mise à jour a réussi.
Future<bool?> showFeeBulkActionDialog({
  required BuildContext context,
  required String clubId,
  required String seasonId,
  required ClubFeeSettings? settings,
  required Map<String, MemberFee?> existingByUidForSelected,
  required List<String> selectedUserIds,
}) async {
  if (selectedUserIds.isEmpty) return null;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => _FeeBulkActionDialog(
      clubId: clubId,
      seasonId: seasonId,
      settings: settings,
      existingByUidForSelected: existingByUidForSelected,
      selectedUserIds: selectedUserIds,
    ),
  );
}

class _FeeBulkActionDialog extends StatefulWidget {
  final String clubId;
  final String seasonId;
  final ClubFeeSettings? settings;
  final Map<String, MemberFee?> existingByUidForSelected;
  final List<String> selectedUserIds;

  const _FeeBulkActionDialog({
    required this.clubId,
    required this.seasonId,
    required this.settings,
    required this.existingByUidForSelected,
    required this.selectedUserIds,
  });

  @override
  State<_FeeBulkActionDialog> createState() => _FeeBulkActionDialogState();
}

class _FeeBulkActionDialogState extends State<_FeeBulkActionDialog> {
  String? _tierIdApply;
  MemberFeeStatus? _statusApply;
  final _partialEuroCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _partialEuroCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final hasPalier = _tierIdApply != null;
    final hasStatut = _statusApply != null;
    if (!hasPalier && !hasStatut) return false;
    if (_statusApply == MemberFeeStatus.partiel) {
      final c = parseEurosStringToCents(_partialEuroCtrl.text.trim());
      return c != null;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    setState(() => _saving = true);
    try {
      int? partialCents;
      if (_statusApply == MemberFeeStatus.partiel) {
        partialCents = parseEurosStringToCents(_partialEuroCtrl.text.trim());
        if (partialCents == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Montant payé invalide')),
            );
            setState(() => _saving = false);
          }
          return;
        }
      }

      await FeeService.instance.applyBulkMemberFees(
        clubId: widget.clubId,
        seasonId: widget.seasonId,
        userIds: List<String>.from(widget.selectedUserIds),
        settings: widget.settings,
        existingByUid: Map<String, MemberFee?>.from(
          widget.existingByUidForSelected,
        ),
        applyTierId: _tierIdApply,
        applyStatus: _statusApply,
        partialPaidCents: partialCents,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Mise à jour pour ${widget.selectedUserIds.length} joueur(s).',
          ),
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
    final tiers = widget.settings?.tiers ?? const <FeeTier>[];
    final hasTiers = tiers.isNotEmpty;

    return AlertDialog(
      title: Text(
        'Actions groupées (${widget.selectedUserIds.length} joueur(s))',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choisis au moins un palier ou un statut. Les champs non remplis restent inchanges.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Palier tarifaire',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ViroColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (!hasTiers)
              Text(
                'Aucun palier défini — configure la grille dans les paramètres cotisation.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _tierIdApply,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Ne pas modifier le palier'),
                      ),
                      for (final t in tiers)
                        DropdownMenuItem<String?>(
                          value: t.tierId,
                          child: Text(
                            '${t.label} (${formatEurosFromCents(t.amountCents)})',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _tierIdApply = v),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Statut',
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
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MemberFeeStatus?>(
                  isExpanded: true,
                  value: _statusApply,
                  items: [
                    const DropdownMenuItem<MemberFeeStatus?>(
                      value: null,
                      child: Text('Ne pas modifier le statut'),
                    ),
                    for (final s in MemberFeeStatus.values)
                      DropdownMenuItem<MemberFeeStatus?>(
                        value: s,
                        child: Text(s.label),
                      ),
                  ],
                  onChanged: (v) => setState(() => _statusApply = v),
                ),
              ),
            ),
            if (_statusApply == MemberFeeStatus.partiel) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _partialEuroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Montant déjà payé (€) — identique pour tous',
                  border: OutlineInputBorder(),
                  hintText: 'ex. 50,00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Paye : le montant paye sera aligne sur le du de chaque joueur. '
              'Exonere : palier et montants payes effaces.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (!_canSubmit && (_tierIdApply == null && _statusApply == null)) ...[
              const SizedBox(height: 8),
              Text(
                'Selectionne au moins un palier ou un statut.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving || !_canSubmit ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Appliquer'),
        ),
      ],
    );
  }
}
