import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/club_fee_settings.dart';
import '../../models/member_fee.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/fee_format.dart';
import '../../utils/fee_status_ui.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import 'widgets/fee_admin_bottom_nav.dart';

/// Détail / édition cotisation pour un joueur.
class AdminMemberFeeDetailPage extends StatelessWidget {
  final String clubId;
  final String seasonId;
  final String userId;

  const AdminMemberFeeDetailPage({
    super.key,
    required this.clubId,
    required this.seasonId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Cotisation du joueur'),
        centerTitle: true,
      ),
      bottomNavigationBar: const FeeAdminBottomNav(currentIndex: 2),
      body: StreamBuilder<ClubFeeSettings?>(
        stream: FeeService.instance.watchFeeSettings(clubId, seasonId),
        builder: (context, settingsSnap) {
          return StreamBuilder<MemberFee?>(
            stream: FeeService.instance.watchMemberFee(clubId, seasonId, userId),
            builder: (context, feeSnap) {
              if (feeSnap.connectionState == ConnectionState.waiting &&
                  !feeSnap.hasData) {
                return const Center(child: ViroLoader(size: 48));
              }
              final fee = feeSnap.data;
              final settings = settingsSnap.data;
              final versionKey =
                  '${fee?.updatedAt?.millisecondsSinceEpoch ?? 0}_${fee?.amountPaidCents ?? -1}';
              return _MemberFeeDetailForm(
                key: ValueKey(versionKey),
                clubId: clubId,
                seasonId: seasonId,
                userId: userId,
                settings: settings,
                fee: fee,
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberFeeDetailForm extends StatefulWidget {
  final String clubId;
  final String seasonId;
  final String userId;
  final ClubFeeSettings? settings;
  final MemberFee? fee;

  const _MemberFeeDetailForm({
    super.key,
    required this.clubId,
    required this.seasonId,
    required this.userId,
    required this.settings,
    required this.fee,
  });

  @override
  State<_MemberFeeDetailForm> createState() => _MemberFeeDetailFormState();
}

class _MemberFeeDetailFormState extends State<_MemberFeeDetailForm> {
  late MemberFeeStatus _status;
  String? _tierId;
  late bool _useCustomAmount;
  late final TextEditingController _customEuroCtrl;
  late final TextEditingController _paidEuroCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fee = widget.fee;
    _status = fee?.status ?? MemberFeeStatus.nonConfigure;
    _tierId = fee?.tierId;
    _useCustomAmount = fee?.customAmountCents != null;
    _customEuroCtrl = TextEditingController(
      text: fee?.customAmountCents != null
          ? (fee!.customAmountCents! / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ',')
          : '',
    );
    _paidEuroCtrl = TextEditingController(
      text: ((fee?.amountPaidCents ?? 0) / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    _notesCtrl = TextEditingController(text: fee?.notesAdmin ?? '');
  }

  @override
  void dispose() {
    _customEuroCtrl.dispose();
    _paidEuroCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MemberFeeDetailForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settings = widget.settings;
    if (settings != null && _tierId != null) {
      final ok = settings.tiers.any((t) => t.tierId == _tierId);
      if (!ok) setState(() => _tierId = null);
    }
  }

  Future<void> _save() async {
    final paidCents = parseEurosStringToCents(_paidEuroCtrl.text);
    if (paidCents == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Montant payé invalide')));
      return;
    }

    int? customCents;
    if (_useCustomAmount && _status != MemberFeeStatus.exonere) {
      customCents = parseEurosStringToCents(_customEuroCtrl.text);
      if (customCents == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Montant personnalisé invalide')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final fee = MemberFee(
        userId: widget.userId,
        status: _status,
        tierId: _useCustomAmount || _status == MemberFeeStatus.exonere
            ? null
            : _tierId,
        customAmountCents:
            _useCustomAmount && _status != MemberFeeStatus.exonere
            ? customCents
            : null,
        amountPaidCents: paidCents,
        notesAdmin: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      );
      await FeeService.instance.upsertMemberFee(
        clubId: widget.clubId,
        seasonId: widget.seasonId,
        fee: fee,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enregistré')));
    } catch (e) {
      if (mounted) FirebaseErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final preview = MemberFee(
      userId: widget.userId,
      status: _status,
      tierId: _useCustomAmount ? null : _tierId,
      customAmountCents: _useCustomAmount && _status != MemberFeeStatus.exonere
          ? parseEurosStringToCents(_customEuroCtrl.text)
          : null,
      amountPaidCents:
          parseEurosStringToCents(_paidEuroCtrl.text) ??
          widget.fee?.amountPaidCents ??
          0,
      notesAdmin: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );
    final due = preview.amountDueCents(settings);
    final paid = preview.amountPaidCents;
    final rest = preview.remainingCents(settings);
    final displayStatus = preview.effectiveDisplayStatus(settings);

    // Détecte une contradiction statut manuel vs statut calculé
    final hasContradiction = _status != MemberFeeStatus.nonConfigure &&
        _status != MemberFeeStatus.exonere &&
        displayStatus != _status &&
        displayStatus != MemberFeeStatus.nonConfigure;

    final tierItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— Choisir un palier —'),
      ),
      if (settings != null)
        for (final t in settings.tiers)
          DropdownMenuItem<String?>(
            value: t.tierId,
            child: Text('${t.label} (${formatEurosFromCents(t.amountCents)})'),
          ),
    ];

    final isExonere = _status == MemberFeeStatus.exonere;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        UserDisplayTile(userId: widget.userId, navigateOnTap: false),
        const SizedBox(height: 16),

        // Carte récapitulative
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Statut affiché',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    FeeStatusChip(status: displayStatus),
                  ],
                ),
                const Divider(height: 20),
                _SummaryRow(
                  label: 'Montant dû',
                  value: formatEurosFromCents(due),
                  valueColor: Colors.grey[800]!,
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Déjà payé',
                  value: formatEurosFromCents(paid),
                  valueColor: ViroColors.success,
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Reste à payer',
                  value: formatEurosFromCents(rest),
                  valueColor: rest > 0 ? ViroColors.error : ViroColors.success,
                ),
                if (settings?.paymentDeadlineAt != null) ...[
                  const Divider(height: 16),
                  Text(
                    'Date limite : ${DateFormat.yMMMMd('fr_FR').format(settings!.paymentDeadlineAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bandeau de contradiction statut
        if (hasContradiction) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le statut sélectionné (${_status.label}) diffère du statut calculé '
                    '(${displayStatus.label}). Le statut manuel prévaut.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Section Tarif
        _SectionHeader(title: 'Tarif'),
        const SizedBox(height: 12),

        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Statut',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MemberFeeStatus>(
              value: _status,
              isExpanded: true,
              items: MemberFeeStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _status = v;
                  if (v == MemberFeeStatus.exonere) {
                    _useCustomAmount = false;
                  }
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        Opacity(
          opacity: isExonere ? 0.45 : 1.0,
          child: IgnorePointer(
            ignoring: isExonere,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Montant personnalisé (hors grille)'),
                  value: _useCustomAmount,
                  onChanged: (v) => setState(() => _useCustomAmount = v),
                ),
                if (_useCustomAmount) ...[
                  TextField(
                    controller: _customEuroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Montant dû (€)',
                      hintText: 'ex. 50,00',
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
                ] else ...[
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Palier tarifaire',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _tierId,
                        isExpanded: true,
                        items: tierItems,
                        onChanged: (v) => setState(() => _tierId = v),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Section Paiement
        _SectionHeader(title: 'Paiement'),
        const SizedBox(height: 12),

        TextField(
          controller: _paidEuroCtrl,
          decoration: const InputDecoration(
            labelText: 'Déjà payé (€)',
            hintText: 'ex. 50,00',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes internes (staff)',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ViroColors.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: ViroColors.primary.withValues(alpha: 0.2))),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
