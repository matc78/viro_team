import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/fee_tier.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';
import 'package:viro_team_v2/features/fees/providers/fee_providers.dart';
import 'package:viro_team_v2/features/fees/utils/fee_iban_validator.dart';
import 'package:viro_team_v2/features/fees/widgets/fee_bulk_action_sheet.dart';
import 'package:viro_team_v2/features/fees/widgets/fee_tier_editor.dart';
import 'package:viro_team_v2/features/fees/widgets/member_fee_list_tile.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

/// Membres du club sans fiche `member_fees` pour la saison en cours.
int pendingFeeInitCount({
  required List<ClubMember> members,
  required List<ClubMember> pendingAsMembers,
  required Set<String> existingMemberIds,
}) {
  var n = 0;
  for (final m in [...members, ...pendingAsMembers]) {
    if (!existingMemberIds.contains(m.memberId)) n++;
  }
  return n;
}

class AdminFeesScreen extends ConsumerStatefulWidget {
  const AdminFeesScreen({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends ConsumerState<AdminFeesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _configTabKey = GlobalKey<_ConfigTabState>();
  bool _handlingTabGuard = false;
  String? _tierFilter;
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabControllerChanged);
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Tap sur [TabBar] : Flutter appelle `animateTo` avant tout `onTap`, donc on
  /// intercepte via [TabController.indexIsChanging] + [previousIndex].
  Future<void> _onTabControllerChanged() async {
    if (_handlingTabGuard) return;

    final leavingConfig =
        _tabs.previousIndex == 0 && _tabs.index != 0;
    if (!leavingConfig) return;

    if (_tabs.indexIsChanging) {
      await _guardLeaveConfigTab(_tabs.index);
      return;
    }

    // Balayage [TabBarView] : pas de indexIsChanging pendant le drag.
    await _guardLeaveConfigTab(_tabs.index);
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text(
          'Des changements n\'ont pas été sauvegardés. '
          'Que souhaitez-vous faire ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer l\'édition'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Avant de quitter l'onglet Configuration (ou l'écran).
  Future<bool> _confirmLeaveConfigIfNeeded() async {
    final config = _configTabKey.currentState;
    if (config == null || !config.hasUnsavedChanges) return true;

    final discard = await _showUnsavedChangesDialog();
    if (!discard) return false;
    config.discardChanges();
    return true;
  }

  /// Bloque la sortie de Configuration tant que l'utilisateur n'a pas choisi.
  Future<void> _guardLeaveConfigTab(int targetIndex) async {
    if (targetIndex == 0) return;

    final config = _configTabKey.currentState;
    if (config == null || !config.hasUnsavedChanges) return;

    _handlingTabGuard = true;
    if (_tabs.index != 0) {
      _tabs.index = 0;
    }

    final discard = await _showUnsavedChangesDialog();
    if (!mounted) {
      _handlingTabGuard = false;
      return;
    }

    if (discard) {
      config.discardChanges();
      _tabs.animateTo(targetIndex);
      await Future<void>.delayed(_tabAnimationDuration);
    } else if (_tabs.index != 0) {
      _tabs.index = 0;
    }

    _handlingTabGuard = false;
  }

  Duration get _tabAnimationDuration => _tabs.animationDuration;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(clubMemberProvider(widget.clubId)).value;
    if (member != null && member.role != MemberRoles.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.replace(AppRoutes.clubMyFeePath(widget.clubId));
      });
      return const ViroScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _confirmLeaveConfigIfNeeded();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ViroScaffold(
        appBar: ViroAppBar(
          title: const Text('Cotisations'),
          actions: [
            if (_selectionMode)
              TextButton(
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
                child: const Text('Annuler'),
              ),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: ViroColors.scaffoldHighlight,
              child: TabBar(
                controller: _tabs,
                labelColor: ViroColors.primary800,
                tabs: const [
                  Tab(text: 'Configuration'),
                  Tab(text: 'Suivi'),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
        controller: _tabs,
        children: [
          _ConfigTab(
            key: _configTabKey,
            clubId: widget.clubId,
            saving: _saving,
            onSaving: (v) => setState(() => _saving = v),
          ),
          _TrackingTab(
            clubId: widget.clubId,
            tierFilter: _tierFilter,
            onTierFilterChanged: (v) => setState(() => _tierFilter = v),
            searchCtrl: _searchCtrl,
            search: _search,
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onToggleSelection: () => setState(() {
              _selectionMode = !_selectionMode;
              if (!_selectionMode) _selectedIds.clear();
            }),
            onSelect: (id, selected) => setState(() {
              if (selected) {
                _selectedIds.add(id);
              } else {
                _selectedIds.remove(id);
              }
            }),
            onOpenBulk: _openBulkActions,
          ),
            ],
          ),
          ),
        ],
      ),
        floatingActionButton: _selectionMode && _selectedIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _openBulkActions,
                icon: ViroIcon(ViroIcons.edit, color: ViroColors.white),
                label: Text('${_selectedIds.length} sélectionné(s)'),
              )
            : null,
      ),
    );
  }

  void _openBulkActions() {
    final season = ref.read(activeSeasonProvider(widget.clubId)).value;
    if (season == null) return;
    FeeBulkActionSheet.show(
      context,
      selectedCount: _selectedIds.length,
      tiers: season.tiers,
      onMarkPaid: () => _bulkStatus(MemberFeeStatus.paye, season.id),
      onMarkExempt: () => _bulkStatus(MemberFeeStatus.exonere, season.id),
      onMarkUnpaid: () => _bulkStatus(MemberFeeStatus.aPayer, season.id),
      onAssignTier: (tierId) => _bulkTier(tierId, season.id),
    );
  }

  Future<void> _bulkStatus(MemberFeeStatus status, String seasonId) async {
    try {
      await ref.read(feeServiceProvider).bulkSetStatus(
            clubId: widget.clubId,
            seasonId: seasonId,
            memberIds: _selectedIds.toList(),
            status: status,
          );
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      if (mounted) ViroSnackBar.show(context, 'Mise à jour effectuée');
    } catch (e) {
      if (mounted) ViroSnackBar.show(context, 'Erreur : $e');
    }
  }

  Future<void> _bulkTier(String tierId, String seasonId) async {
    try {
      await ref.read(feeServiceProvider).bulkSetTier(
            clubId: widget.clubId,
            seasonId: seasonId,
            memberIds: _selectedIds.toList(),
            tierId: tierId,
          );
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      if (mounted) ViroSnackBar.show(context, 'Catégories assignées');
    } catch (e) {
      if (mounted) ViroSnackBar.show(context, 'Erreur : $e');
    }
  }
}

/// Instantané du formulaire configuration pour détecter les modifications.
class _ConfigFormSnapshot {
  const _ConfigFormSnapshot({
    required this.seasonLabel,
    required this.paymentInstructions,
    required this.iban,
    required this.paymentMethods,
    required this.paymentDeadlineAt,
    required this.tiers,
  });

  final String seasonLabel;
  final String paymentInstructions;
  final String? iban;
  final List<String> paymentMethods;
  final DateTime? paymentDeadlineAt;
  final List<FeeTier> tiers;

  factory _ConfigFormSnapshot.fromForm({
    required String seasonLabel,
    required String paymentInstructions,
    required String? iban,
    required List<String> paymentMethods,
    required DateTime? paymentDeadlineAt,
    required List<FeeTier> tiers,
  }) {
    return _ConfigFormSnapshot(
      seasonLabel: seasonLabel,
      paymentInstructions: paymentInstructions,
      iban: iban == null || iban.trim().isEmpty
          ? null
          : normalizeIban(iban.trim()),
      paymentMethods: List<String>.from(paymentMethods)..sort(),
      paymentDeadlineAt: paymentDeadlineAt,
      tiers: tiers
          .map((t) => FeeTier(tierId: t.tierId, label: t.label.trim(), amountCents: t.amountCents))
          .toList(),
    );
  }

  bool equals(_ConfigFormSnapshot other) {
    if (seasonLabel != other.seasonLabel) return false;
    if (paymentInstructions != other.paymentInstructions) return false;
    if (iban != other.iban) return false;
    if (paymentDeadlineAt?.year != other.paymentDeadlineAt?.year ||
        paymentDeadlineAt?.month != other.paymentDeadlineAt?.month ||
        paymentDeadlineAt?.day != other.paymentDeadlineAt?.day) {
      return false;
    }
    final methodsA = paymentMethods.toSet();
    final methodsB = other.paymentMethods.toSet();
    if (methodsA.length != methodsB.length) return false;
    for (final m in methodsA) {
      if (!methodsB.contains(m)) return false;
    }
    if (tiers.length != other.tiers.length) return false;
    for (var i = 0; i < tiers.length; i++) {
      final a = tiers[i];
      final b = other.tiers[i];
      if (a.tierId != b.tierId ||
          a.label != b.label ||
          a.amountCents != b.amountCents) {
        return false;
      }
    }
    return true;
  }
}

class _ConfigTab extends ConsumerStatefulWidget {
  const _ConfigTab({
    super.key,
    required this.clubId,
    required this.saving,
    required this.onSaving,
  });

  final String clubId;
  final bool saving;
  final ValueChanged<bool> onSaving;

  @override
  ConsumerState<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends ConsumerState<_ConfigTab> {
  final _seasonLabelCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  List<FeeTier> _tiers = [];
  List<String> _paymentMethods = [];
  DateTime? _deadline;
  bool _initialized = false;
  bool _listenersAttached = false;
  _ConfigFormSnapshot? _savedSnapshot;

  bool get hasUnsavedChanges {
    final snap = _savedSnapshot;
    if (snap == null) return false;
    return !snap.equals(_currentSnapshot());
  }

  _ConfigFormSnapshot _currentSnapshot() => _ConfigFormSnapshot.fromForm(
        seasonLabel: _seasonLabelCtrl.text.trim(),
        paymentInstructions: _instructionsCtrl.text.trim(),
        iban: _ibanCtrl.text.trim().isEmpty ? null : _ibanCtrl.text,
        paymentMethods: _paymentMethods,
        paymentDeadlineAt: _deadline,
        tiers: _tiers,
      );

  void _markDirty() {
    if (mounted) setState(() {});
  }

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;
    _seasonLabelCtrl.addListener(_markDirty);
    _instructionsCtrl.addListener(_markDirty);
    _ibanCtrl.addListener(_markDirty);
  }

  @override
  void dispose() {
    _seasonLabelCtrl.dispose();
    _instructionsCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _loadFromSeason(FeeSeason season) {
    if (_initialized) return;
    _initialized = true;
    _seasonLabelCtrl.text = season.seasonLabel;
    _instructionsCtrl.text = season.paymentInstructions;
    _ibanCtrl.text = season.iban ?? '';
    _tiers = List.from(season.tiers);
    _paymentMethods = List.from(season.paymentMethods);
    _deadline = season.paymentDeadlineAt;
    _attachListeners();
    _savedSnapshot = _currentSnapshot();
  }

  void discardChanges() {
    setState(() {
      _initialized = false;
      _savedSnapshot = null;
    });
  }

  void _commitSnapshot() {
    _savedSnapshot = _currentSnapshot();
    _markDirty();
  }

  Future<void> _createSeason() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    widget.onSaving(true);
    try {
      final season = FeeSeason(
        id: '',
        seasonLabel: '2025-2026',
        isActive: true,
        tiers: [
          FeeTier(
            tierId: 'tier_default',
            label: 'Standard',
            amountCents: 0,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );
      await ref.read(feeServiceProvider).createSeason(
            clubId: widget.clubId,
            season: season,
          );
      if (mounted) ViroSnackBar.show(context, 'Saison créée');
      setState(() => _initialized = false);
    } catch (e) {
      if (mounted) ViroSnackBar.show(context, 'Erreur : $e');
    } finally {
      widget.onSaving(false);
    }
  }

  Future<bool> _onDeleteTier(FeeTier tier) async {
    final season = ref.read(activeSeasonProvider(widget.clubId)).value;
    if (season == null) return true;
    final count = await ref.read(feeServiceProvider).countMemberFeesWithTier(
          clubId: widget.clubId,
          seasonId: season.id,
          tierId: tier.tierId,
        );
    if (count > 0 && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer cette catégorie ?'),
          content: Text(
            'Ce palier est assigné à $count membre${count > 1 ? 's' : ''}. '
            'Confirmer la suppression ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
      return confirm == true;
    }
    return true;
  }

  Future<void> _save(FeeSeason season) async {
    if (_tiers.isEmpty) {
      ViroSnackBar.show(context, 'Ajoutez au moins une catégorie tarifaire');
      return;
    }
    for (final t in _tiers) {
      if (t.label.trim().isEmpty || t.amountCents <= 0) {
        ViroSnackBar.show(context, 'Chaque catégorie doit avoir un libellé et un montant > 0');
        return;
      }
    }
    if (!isValidIbanFormat(_ibanCtrl.text)) {
      ViroSnackBar.show(context, 'Format IBAN invalide');
      return;
    }

    widget.onSaving(true);
    try {
      final updated = FeeSeason(
        id: season.id,
        seasonLabel: _seasonLabelCtrl.text.trim(),
        isActive: season.isActive,
        paymentInstructions: _instructionsCtrl.text.trim(),
        paymentMethods: _paymentMethods,
        iban: _ibanCtrl.text.trim().isEmpty ? null : normalizeIban(_ibanCtrl.text),
        tiers: _tiers,
        paymentDeadlineAt: _deadline,
        createdAt: season.createdAt,
        updatedAt: season.updatedAt,
        createdBy: season.createdBy,
      );
      await ref.read(feeServiceProvider).updateSeason(
            clubId: widget.clubId,
            season: updated,
          );
      if (mounted) {
        _commitSnapshot();
        ViroSnackBar.show(context, 'Enregistré');
      }
    } catch (e) {
      if (mounted) ViroSnackBar.show(context, 'Erreur : $e');
    } finally {
      widget.onSaving(false);
    }
  }

  Future<void> _closeSeason(FeeSeason season) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer la saison ?'),
        content: const Text(
          'Les joueurs ne verront plus cette saison. Les données restent accessibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(feeServiceProvider).closeSeason(
          clubId: widget.clubId,
          seasonId: season.id,
        );
    if (mounted) ViroSnackBar.show(context, 'Saison clôturée');
    setState(() => _initialized = false);
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(activeSeasonProvider(widget.clubId));

    return seasonAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (season) {
        if (season == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ViroSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Aucune saison de cotisation active',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: ViroSpacing.lg),
                  ViroPrimaryButton(
                    label: 'Créer la saison',
                    onPressed: widget.saving ? null : _createSeason,
                  ),
                ],
              ),
            ),
          );
        }

        _loadFromSeason(season);

        return ListView(
          padding: const EdgeInsets.all(ViroSpacing.screenHorizontal),
          children: [
            TextField(
              controller: _seasonLabelCtrl,
              decoration: const InputDecoration(labelText: 'Libellé saison'),
            ),
            const SizedBox(height: ViroSpacing.md),
            Text(
              'Grille tarifaire',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: ViroSpacing.sm),
            FeeTierEditor(
              tiers: _tiers,
              onChanged: (t) => setState(() => _tiers = t),
              onDeleteTier: _onDeleteTier,
            ),
            const SizedBox(height: ViroSpacing.md),
            TextField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Consignes de paiement',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: ViroSpacing.md),
            TextField(
              controller: _ibanCtrl,
              decoration: const InputDecoration(labelText: 'IBAN (optionnel)'),
            ),
            const SizedBox(height: ViroSpacing.md),
            Text(
              'Moyens de paiement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: ViroSpacing.sm,
              children: FeePaymentMethods.all.map((method) {
                final selected = _paymentMethods.contains(method);
                return FilterChip(
                  label: Text(
                    FeePaymentMethods.label(method),
                    style: TextStyle(
                      color: selected
                          ? ViroColors.white
                          : ViroColors.primary800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: ViroColors.primary600,
                  backgroundColor: ViroColors.gray50,
                  side: BorderSide(
                    color: selected
                        ? ViroColors.primary600
                        : ViroColors.gray200,
                  ),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _paymentMethods = [..._paymentMethods, method];
                      } else {
                        _paymentMethods =
                            _paymentMethods.where((m) => m != method).toList();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: ViroSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date limite'),
              subtitle: _deadline == null
                  ? const Text('Non définie')
                  : Text(DateFormat.yMMMMd('fr_FR').format(_deadline!)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deadline != null)
                    IconButton(
                      icon: ViroIcon(ViroIcons.close, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                  IconButton(
                    icon: ViroIcon(ViroIcons.calendar),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: ViroSpacing.lg),
            if (hasUnsavedChanges)
              ViroPrimaryButton(
                label: widget.saving ? 'Enregistrement…' : 'Sauvegarder',
                onPressed: widget.saving ? null : () => _save(season),
              ),
            if (hasUnsavedChanges) const SizedBox(height: ViroSpacing.sm),
            OutlinedButton(
              onPressed: () => _closeSeason(season),
              child: const Text('Clôturer la saison'),
            ),
          ],
        );
      },
    );
  }
}

class _TrackingFeeLists {
  const _TrackingFeeLists({
    required this.unpaid,
    required this.paid,
    required this.exempt,
  });

  final List<MemberFee> unpaid;
  final List<MemberFee> paid;
  final List<MemberFee> exempt;
}

class _TrackingTab extends ConsumerWidget {
  const _TrackingTab({
    required this.clubId,
    required this.tierFilter,
    required this.onTierFilterChanged,
    required this.searchCtrl,
    required this.search,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSelect,
    required this.onOpenBulk,
  });

  final String clubId;
  final String? tierFilter;
  final ValueChanged<String?> onTierFilterChanged;
  final TextEditingController searchCtrl;
  final String search;
  final bool selectionMode;
  final Set<String> selectedIds;
  final VoidCallback onToggleSelection;
  final void Function(String id, bool selected) onSelect;
  final VoidCallback onOpenBulk;

  List<MemberFee> _applySearchAndTier(List<MemberFee> fees) {
    return fees.where((f) {
      if (tierFilter != null && f.tierId != tierFilter) return false;
      if (search.isNotEmpty &&
          !f.memberDisplayName.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _sortByName(List<MemberFee> list) {
    list.sort(
      (a, b) => a.memberDisplayName
          .toLowerCase()
          .compareTo(b.memberDisplayName.toLowerCase()),
    );
  }

  _TrackingFeeLists _splitFees(List<MemberFee> fees, FeeSeason season) {
    final filtered = _applySearchAndTier(fees);
    final unpaid = <MemberFee>[];
    final paid = <MemberFee>[];
    final exempt = <MemberFee>[];

    for (final f in filtered) {
      switch (f.displayStatus(season.paymentDeadlineAt)) {
        case MemberFeeDisplayStatus.paye:
          paid.add(f);
        case MemberFeeDisplayStatus.exonere:
          exempt.add(f);
        case MemberFeeDisplayStatus.aPayer:
        case MemberFeeDisplayStatus.enRetard:
          unpaid.add(f);
      }
    }

    _sortByName(unpaid);
    _sortByName(paid);
    _sortByName(exempt);
    return _TrackingFeeLists(unpaid: unpaid, paid: paid, exempt: exempt);
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ViroSpacing.screenHorizontal,
        ViroSpacing.md,
        ViroSpacing.screenHorizontal,
        ViroSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: ViroColors.primary800,
            ),
      ),
    );
  }

  Widget _feeTile(
    BuildContext context,
    WidgetRef ref,
    MemberFee fee,
    FeeSeason season,
  ) {
    final selected = selectedIds.contains(fee.memberId);
    return MemberFeeListTile(
      fee: fee,
      season: season,
      selected: selected,
      selectionMode: selectionMode,
      onTap: () {
        if (selectionMode) {
          onSelect(fee.memberId, !selected);
        } else {
          _showMemberMenu(context, ref, fee, season);
        }
      },
      onLongPress: () {
        if (!selectionMode) onToggleSelection();
        onSelect(fee.memberId, true);
      },
      onMenu: () => _showMemberMenu(context, ref, fee, season),
    );
  }

  Future<void> _initialize(BuildContext context, WidgetRef ref) async {
    final season = ref.read(activeSeasonProvider(clubId)).value;
    if (season == null) return;

    final members = ref.read(clubMembersProvider(clubId)).value ?? [];
    final pending = ref.read(pendingTeamMembersProvider(clubId)).value ?? [];
    final pendingAsMembers =
        pending.map((p) => pendingAsClubMember(p)).toList();
    final teams = ref.read(clubTeamsProvider(clubId)).value ?? [];
    final existing = ref.read(allMemberFeesProvider(clubId)).value ?? [];
    final existingIds = existing.map((f) => f.memberId).toSet();

    final count = pendingFeeInitCount(
      members: members,
      pendingAsMembers: pendingAsMembers,
      existingMemberIds: existingIds,
    );
    if (count <= 0) {
      if (context.mounted) {
        ViroSnackBar.show(context, 'Tous les membres ont déjà une fiche.');
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter au suivi ?'),
        content: Text(
          'Créer $count fiche${count > 1 ? 's' : ''} de cotisation '
          'pour les membres pas encore listés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final created = await ref.read(feeServiceProvider).initializeMemberFees(
            clubId: clubId,
            seasonId: season.id,
            members: members,
            teams: teams,
            pendingAsMembers: pendingAsMembers,
            existingMemberIds: existingIds,
            tiers: season.tiers,
          );
      if (context.mounted) {
        ViroSnackBar.show(context, '$created fiche${created > 1 ? 's' : ''} créée${created > 1 ? 's' : ''}');
      }
    } catch (e) {
      if (context.mounted) ViroSnackBar.show(context, 'Erreur : $e');
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final season = ref.read(activeSeasonProvider(clubId)).value;
    if (season == null) return;
    final fees = ref.read(allMemberFeesProvider(clubId)).value ?? [];
    final csv = await ref.read(feeServiceProvider).exportCsv(
          clubId: clubId,
          seasonId: season.id,
          season: season,
          fees: fees,
        );
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ViroSnackBar.show(context, 'CSV copié dans le presse-papiers');
    }
  }

  void _showMemberMenu(
    BuildContext context,
    WidgetRef ref,
    MemberFee fee,
    FeeSeason season,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(fee.memberDisplayName),
                subtitle:
                    Text(fee.displayStatus(season.paymentDeadlineAt).label),
              ),
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Marquer payé'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(feeServiceProvider).setMemberFeeStatus(
                      clubId: clubId,
                      seasonId: season.id,
                      memberId: fee.memberId,
                      status: MemberFeeStatus.paye,
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Marquer à payer'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(feeServiceProvider).setMemberFeeStatus(
                      clubId: clubId,
                      seasonId: season.id,
                      memberId: fee.memberId,
                      status: MemberFeeStatus.aPayer,
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Marquer exonéré'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(feeServiceProvider).setMemberFeeStatus(
                      clubId: clubId,
                      seasonId: season.id,
                      memberId: fee.memberId,
                      status: MemberFeeStatus.exonere,
                    );
              },
            ),
            if (season.tiers.isNotEmpty) ...[
              const Divider(),
              for (final tier in season.tiers)
                ListTile(
                  title: Text('Catégorie : ${tier.label}'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(feeServiceProvider).setMemberFeeTier(
                          clubId: clubId,
                          seasonId: season.id,
                          memberId: fee.memberId,
                          tierId: tier.tierId,
                        );
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('Note admin'),
              onTap: () async {
                Navigator.pop(ctx);
                await Future<void>.delayed(Duration.zero);
                if (!context.mounted) return;
                final saved = await showDialog<String?>(
                  context: context,
                  builder: (dCtx) => _MemberFeeNoteDialog(
                    initialText: fee.notesAdmin ?? '',
                  ),
                );
                if (!context.mounted || saved == null) return;
                await ref.read(feeServiceProvider).setMemberFeeNote(
                      clubId: clubId,
                      seasonId: season.id,
                      memberId: fee.memberId,
                      note: saved,
                    );
                if (context.mounted) {
                  ViroSnackBar.show(context, 'Note enregistrée');
                }
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(activeSeasonProvider(clubId));
    final feesAsync = ref.watch(allMemberFeesProvider(clubId));
    final stats = ref.watch(feeStatsProvider(clubId));
    final members = ref.watch(clubMembersProvider(clubId)).value ?? [];
    final pendingAsMembers = (ref.watch(pendingTeamMembersProvider(clubId)).value ??
            [])
        .map(pendingAsClubMember)
        .toList();

    return seasonAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (season) {
        if (season == null) {
          return const Center(
            child: Text('Créez d\'abord une saison dans l\'onglet Configuration'),
          );
        }

        return feesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (allFees) {
            final lists = _splitFees(allFees, season);
            final existingIds = allFees.map((f) => f.memberId).toSet();
            final pendingCount = pendingFeeInitCount(
              members: members,
              pendingAsMembers: pendingAsMembers,
              existingMemberIds: existingIds,
            );
            final hasAnyList = lists.unpaid.isNotEmpty ||
                lists.paid.isNotEmpty ||
                lists.exempt.isNotEmpty;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(ViroSpacing.screenHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${stats.paid} / ${stats.total} ont payé '
                        '(${stats.total > 0 ? (stats.paidPercent * 100).round() : 0} %) · '
                        '${stats.exempt} exonéré${stats.exempt > 1 ? 's' : ''} · '
                        '${stats.awaiting} en attente',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ViroColors.gray600,
                            ),
                      ),
                      const SizedBox(height: ViroSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Rechercher…',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.select_all),
                            tooltip: 'Sélection multiple',
                            onPressed: onToggleSelection,
                          ),
                          IconButton(
                            icon: ViroIcon(ViroIcons.copy),
                            tooltip: 'Exporter CSV',
                            onPressed: () => _exportCsv(context, ref),
                          ),
                        ],
                      ),
                      if (season.tiers.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DropdownButton<String?>(
                            value: tierFilter,
                            hint: const Text('Filtrer par catégorie'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Toutes les catégories'),
                              ),
                              for (final t in season.tiers)
                                DropdownMenuItem(
                                  value: t.tierId,
                                  child: Text(t.label),
                                ),
                            ],
                            onChanged: onTierFilterChanged,
                          ),
                        ),
                      if (pendingCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: ViroSpacing.sm),
                          child: OutlinedButton(
                            onPressed: () => _initialize(context, ref),
                            child: Text(
                              'Ajouter $pendingCount membre'
                              '${pendingCount > 1 ? 's' : ''}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: !hasAnyList
                      ? const Center(child: Text('Aucun membre à afficher'))
                      : ListView(
                          children: [
                            if (lists.unpaid.isNotEmpty) ...[
                              _sectionTitle(
                                context,
                                'En attente (${lists.unpaid.length})',
                              ),
                              for (final fee in lists.unpaid)
                                _feeTile(context, ref, fee, season),
                            ],
                            if (lists.paid.isNotEmpty) ...[
                              _sectionTitle(
                                context,
                                'Payés (${lists.paid.length})',
                              ),
                              for (final fee in lists.paid)
                                _feeTile(context, ref, fee, season),
                            ],
                            if (lists.exempt.isNotEmpty) ...[
                              _sectionTitle(
                                context,
                                'Exonérés (${lists.exempt.length})',
                              ),
                              for (final fee in lists.exempt)
                                _feeTile(context, ref, fee, season),
                            ],
                            const SizedBox(height: ViroSpacing.lg),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Dialogue note admin — le [TextEditingController] vit dans le State du dialogue.
class _MemberFeeNoteDialog extends StatefulWidget {
  const _MemberFeeNoteDialog({required this.initialText});

  final String initialText;

  @override
  State<_MemberFeeNoteDialog> createState() => _MemberFeeNoteDialogState();
}

class _MemberFeeNoteDialogState extends State<_MemberFeeNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Note admin'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Note privée'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
