import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/club_fee_settings.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/fee_format.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/viro_loader.dart';
import 'widgets/fee_admin_bottom_nav.dart';

/// Edition de la grille tarifaire et des consignes de paiement.
class AdminFeeSettingsPage extends StatelessWidget {
  final String clubId;
  final String seasonId;

  const AdminFeeSettingsPage({
    super.key,
    required this.clubId,
    required this.seasonId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Parametres cotisation'),
        centerTitle: true,
      ),
      bottomNavigationBar: const FeeAdminBottomNav(currentIndex: 2),
      body: StreamBuilder<ClubFeeSettings?>(
        stream: FeeService.instance.watchFeeSettings(clubId, seasonId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: ViroLoader(size: 48));
          }
          final existing = snap.data;
          final ts = existing?.updatedAt?.millisecondsSinceEpoch ?? 0;
          final dl = existing?.paymentDeadlineAt?.millisecondsSinceEpoch ?? 0;
          return _FeeSettingsEditor(
            key: ValueKey('${clubId}_${seasonId}_${ts}_$dl'),
            clubId: clubId,
            seasonId: seasonId,
            initial: existing,
          );
        },
      ),
    );
  }
}

class _FeeSettingsEditor extends StatefulWidget {
  final String clubId;
  final String seasonId;
  final ClubFeeSettings? initial;

  const _FeeSettingsEditor({
    super.key,
    required this.clubId,
    required this.seasonId,
    required this.initial,
  });

  @override
  State<_FeeSettingsEditor> createState() => _FeeSettingsEditorState();
}

class _FeeSettingsEditorState extends State<_FeeSettingsEditor> {
  late final TextEditingController _seasonCtrl;
  late final TextEditingController _instructionsCtrl;
  late List<_TierRow> _rows;
  DateTime? _paymentDeadline;
  final _rnd = Random();
  bool _saving = false;

  void _notifyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _seasonCtrl = TextEditingController(text: i?.seasonLabel ?? '');
    _instructionsCtrl = TextEditingController(
      text: i?.paymentInstructions ?? '',
    );
    _seasonCtrl.addListener(_notifyChanged);
    _instructionsCtrl.addListener(_notifyChanged);

    final tiersSorted = List<FeeTier>.from(i?.tiers ?? [])
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    _rows = tiersSorted
        .map(
          (t) => _TierRow(
            tierId: t.tierId,
            labelCtrl: TextEditingController(text: t.label),
            euroCtrl: TextEditingController(
              text: (t.amountCents / 100)
                  .toStringAsFixed(2)
                  .replaceAll('.', ','),
            ),
            descCtrl: TextEditingController(text: t.description ?? ''),
          ),
        )
        .toList();
    for (final r in _rows) {
      r.attachTierListeners(_notifyChanged);
    }
    _paymentDeadline = i?.paymentDeadlineAt;
  }

  @override
  void dispose() {
    _seasonCtrl.removeListener(_notifyChanged);
    _instructionsCtrl.removeListener(_notifyChanged);
    for (final r in _rows) {
      r.detachTierListeners();
      r.dispose();
    }
    super.dispose();
  }

  void _addTier() {
    final id =
        'tier_${DateTime.now().millisecondsSinceEpoch}_${_rnd.nextInt(99999)}';
    final row = _TierRow(
      tierId: id,
      labelCtrl: TextEditingController(),
      euroCtrl: TextEditingController(),
      descCtrl: TextEditingController(),
    );
    row.attachTierListeners(_notifyChanged);
    setState(() => _rows.add(row));
  }

  void _sortRowsByLabel() {
    setState(() {
      _rows.sort(
        (a, b) => a.labelCtrl.text.trim().toLowerCase().compareTo(
          b.labelCtrl.text.trim().toLowerCase(),
        ),
      );
    });
  }

  bool get _isSortedByLabel {
    if (_rows.length <= 1) return true;
    for (var i = 0; i < _rows.length - 1; i++) {
      final a = _rows[i].labelCtrl.text.trim().toLowerCase();
      final b = _rows[i + 1].labelCtrl.text.trim().toLowerCase();
      if (a.compareTo(b) > 0) return false;
    }
    return true;
  }

  void _removeAt(int i) {
    setState(() {
      _rows[i].detachTierListeners();
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  ClubFeeSettings _snapshotFromInitial() {
    final i = widget.initial;
    return ClubFeeSettings(
      seasonLabel: i?.seasonLabel ?? '',
      paymentInstructions: i?.paymentInstructions ?? '',
      tiers: List<FeeTier>.from(i?.tiers ?? []),
      currency: i?.currency ?? 'EUR',
      paymentDeadlineAt: i?.paymentDeadlineAt,
    );
  }

  bool _sameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _tiersContentEqual(List<FeeTier> a, List<FeeTier> b) {
    if (a.length != b.length) return false;
    final ma = {for (final t in a) t.tierId: t};
    final mb = {for (final t in b) t.tierId: t};
    if (ma.length != mb.length) return false;
    for (final id in ma.keys) {
      final ta = ma[id]!;
      final tb = mb[id];
      if (tb == null) return false;
      if (ta.label != tb.label ||
          ta.amountCents != tb.amountCents ||
          (ta.description ?? '') != (tb.description ?? '')) {
        return false;
      }
    }
    return true;
  }

  bool get _isDirty {
    final draft = _buildDraft();
    final ref = _snapshotFromInitial();
    if (draft.seasonLabel != ref.seasonLabel) return true;
    if (draft.paymentInstructions != ref.paymentInstructions) return true;
    if (!_sameCalendarDay(draft.paymentDeadlineAt, ref.paymentDeadlineAt)) {
      return true;
    }
    if (!_tiersContentEqual(draft.tiers, ref.tiers)) return true;
    return false;
  }

  ClubFeeSettings _buildDraft() {
    final tiers = <FeeTier>[];
    for (final r in _rows) {
      final cents = parseEurosStringToCents(r.euroCtrl.text);
      if (r.labelCtrl.text.trim().isEmpty) continue;
      tiers.add(
        FeeTier(
          tierId: r.tierId,
          label: r.labelCtrl.text.trim(),
          amountCents: cents ?? 0,
          description: r.descCtrl.text.trim().isEmpty
              ? null
              : r.descCtrl.text.trim(),
        ),
      );
    }
    return ClubFeeSettings(
      seasonLabel: _seasonCtrl.text.trim(),
      paymentInstructions: _instructionsCtrl.text.trim(),
      tiers: tiers,
      currency: widget.initial?.currency ?? 'EUR',
      paymentDeadlineAt: _paymentDeadline,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FeeService.instance.saveFeeSettings(
        widget.clubId,
        widget.seasonId,
        _buildDraft(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enregistre')));
    } catch (e) {
      if (mounted) FirebaseErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineIsExpired = _paymentDeadline != null &&
        DateTime(
          _paymentDeadline!.year,
          _paymentDeadline!.month,
          _paymentDeadline!.day,
        ).isBefore(today);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _seasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Saison (libelle)',
            hintText: 'ex. 2025-2026',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _instructionsCtrl,
          decoration: const InputDecoration(
            labelText: 'Instructions de paiement',
            hintText: 'RIB, ordre du cheque, delais...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 4,
          maxLines: 12,
        ),
        const SizedBox(height: 16),
        Card(
          color: deadlineIsExpired
              ? ViroColors.error.withValues(alpha: 0.06)
              : null,
          child: ListTile(
            title: const Text('Date limite de cotisation'),
            subtitle: _paymentDeadline == null
                ? const Text(
                    "Non definie \u2014 le statut \u00ab en retard \u00bb ne s'applique que manuellement.",
                  )
                : Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: Colors.grey[800],
                        height: 1.35,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'Dernier jour inclus\u00a0: '),
                        TextSpan(
                          text: DateFormat.yMMMMd('fr_FR')
                              .format(_paymentDeadline!),
                          style: const TextStyle(
                            color: ViroColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '.\n'),
                        TextSpan(
                          text:
                              "Apr\u00e8s cette date, les joueurs avec un solde d\u00fb passent en \u00ab\u00a0en retard\u00a0\u00bb.",
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deadlineIsExpired)
                  Tooltip(
                    message: "Echeance depassee",
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: ViroColors.error,
                      size: 20,
                    ),
                  ),
                if (_paymentDeadline != null)
                  IconButton(
                    tooltip: 'Effacer',
                    onPressed: () => setState(() => _paymentDeadline = null),
                    icon: const Icon(Icons.clear),
                  ),
                const Icon(Icons.calendar_month_outlined),
              ],
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _paymentDeadline ?? now,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 5),
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null && mounted) {
                setState(() => _paymentDeadline = picked);
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              _rows.isEmpty
                  ? 'Grille tarifaire'
                  : 'Grille tarifaire (${_rows.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: ViroColors.primary,
              ),
            ),
            const Spacer(),
            if (_rows.length > 1 && !_isSortedByLabel)
              TextButton.icon(
                onPressed: _sortRowsByLabel,
                icon: const Icon(Icons.sort_by_alpha, size: 20),
                label: const Text('Trier par libelle'),
              ),
            TextButton.icon(
              onPressed: _addTier,
              icon: const Icon(Icons.add),
              label: const Text('Palier'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rows[i].labelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Libelle du palier',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeAt(i),
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rows[i].euroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Montant (\u20ac)',
                      hintText: 'ex. 120,00',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_rows[i].euroCtrl.text.trim().isNotEmpty &&
                      parseEurosStringToCents(_rows[i].euroCtrl.text) == 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Montant a 0 \u20ac \u2014 intentionnel ?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rows[i].descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        if (_isDirty || _saving)
          FilledButton(
            onPressed: _saving || !_isDirty ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
      ],
    );
  }
}

class _TierRow {
  final String tierId;
  final TextEditingController labelCtrl;
  final TextEditingController euroCtrl;
  final TextEditingController descCtrl;
  VoidCallback? _listener;

  _TierRow({
    required this.tierId,
    required this.labelCtrl,
    required this.euroCtrl,
    required this.descCtrl,
  });

  void attachTierListeners(VoidCallback cb) {
    detachTierListeners();
    _listener = cb;
    labelCtrl.addListener(cb);
    euroCtrl.addListener(cb);
    descCtrl.addListener(cb);
  }

  void detachTierListeners() {
    if (_listener == null) return;
    labelCtrl.removeListener(_listener!);
    euroCtrl.removeListener(_listener!);
    descCtrl.removeListener(_listener!);
    _listener = null;
  }

  void dispose() {
    labelCtrl.dispose();
    euroCtrl.dispose();
    descCtrl.dispose();
  }
}
