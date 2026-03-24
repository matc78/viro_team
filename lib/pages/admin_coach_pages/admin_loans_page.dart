import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/slide_to_confirm.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';

class AdminLoansPage extends StatefulWidget {
  final String clubId;

  /// Onglet à afficher à l'ouverture : 0 = Catalogue, 1 = Prêt
  final int initialTabIndex;

  const AdminLoansPage({
    super.key,
    required this.clubId,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminLoansPage> createState() => _AdminLoansPageState();
}

/// True si l'utilisateur est admin (ou admin_fondateur) du club, false pour coach.
bool _isAdminForClub(Map<String, dynamic>? userData, String clubId) {
  if (userData == null) return false;
  final role = getUserRoleInClub(userData, clubId);
  if (role == 'admin_fondateur' || role == 'admin') return true;
  return false;
}

class _AdminLoansPageState extends State<AdminLoansPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _editMode = false;
  // Filtre onglet Prêts: 'demandes' | 'actifs' | 'retard' | 'historique'
  String _pretsFilter = 'actifs';

  @override
  void initState() {
    super.initState();
    final index = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: ViroColors.background,
        appBar: AppBar(title: const Text("Prêts"), centerTitle: true),
        body: const Center(child: Text("Non connecté")),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final isAdmin = _isAdminForClub(userData, widget.clubId);
        final showCancelButtons = _editMode && isAdmin;

        if (userSnap.hasData && userData != null && !isAdmin) {
          return Scaffold(
            backgroundColor: ViroColors.background,
            appBar: AppBar(title: const Text("Prêts"), centerTitle: true),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text("Accès réservé aux administrateurs",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      "La gestion du catalogue et des prêts n'est pas disponible pour les coaches.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(
            title: const Text("Prêts"),
            centerTitle: true,
            actions: [
              if (isAdmin)
                ListenableBuilder(
                  listenable: _tabController,
                  builder: (context, _) => _tabController.index == 0
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.tune_outlined),
                          tooltip: "Paramètres du catalogue",
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'paiement',
                              child: Row(children: [
                                Icon(Icons.payment_outlined, size: 18),
                                SizedBox(width: 10),
                                Text("Moyens de paiement"),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'recup',
                              child: Row(children: [
                                Icon(Icons.calendar_today_outlined, size: 18),
                                SizedBox(width: 10),
                                Text("Récup. / Retour"),
                              ]),
                            ),
                          ],
                          onSelected: (v) {
                            if (v == 'paiement') {
                              _LoanCatalogSection.showPaymentMethodsDialog(context, widget.clubId);
                            } else {
                              _LoanCatalogSection.showLoanAllowedDaysDialog(context, widget.clubId);
                            }
                          },
                        )
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: appFirestore
                              .collection(FirebaseCollections.clubs)
                              .doc(widget.clubId)
                              .collection(FirebaseCollections.equipmentLoans)
                              .where('status', isEqualTo: 'active')
                              .snapshots(),
                          builder: (context, loanSnap) {
                            final hasModifiable = (loanSnap.data?.docs.isNotEmpty) ?? false;
                            if (!hasModifiable) return const SizedBox.shrink();
                            return IconButton(
                              icon: Icon(
                                _editMode ? Icons.edit_off : Icons.edit,
                                color: _editMode ? ViroColors.primary : null,
                              ),
                              onPressed: () => setState(() => _editMode = !_editMode),
                              tooltip: 'Édition',
                            );
                          },
                        ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Catalogue"),
                Tab(text: "Prêts"),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── CATALOGUE ──────────────────────────────────────────────────
              _LoanCatalogSection(clubId: widget.clubId),

              // ── PRÊTS ──────────────────────────────────────────────────────
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: appFirestore
                    .collection(FirebaseCollections.clubs)
                    .doc(widget.clubId)
                    .collection(FirebaseCollections.equipmentLoans)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: ViroLoader(size: 60));
                  }
                  if (snap.hasError) {
                    return FirebaseErrorHandler.buildErrorWidget(context, snap.error);
                  }

                  final docs = snap.data?.docs ?? [];
                  final allLoans = docs
                      .map((d) => {'id': d.id, ...d.data()})
                      .cast<Map<String, dynamic>>()
                      .toList();

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  final overdueLoans = allLoans.where((l) {
                    if (l['status'] != 'active') return false;
                    final due = (l['dueAt'] as Timestamp?)?.toDate();
                    if (due == null) return false;
                    return DateTime(due.year, due.month, due.day).isBefore(today);
                  }).toList()..sort((a, b) {
                    final da = (a['dueAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final db = (b['dueAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return da.compareTo(db);
                  });

                  final activeLoans = allLoans.where((l) {
                    if (l['status'] != 'active') return false;
                    if (!_isPickupConfirmed(l)) return false;
                    final lent = (l['lentAt'] as Timestamp?)?.toDate();
                    final due = (l['dueAt'] as Timestamp?)?.toDate();
                    if (lent == null || due == null) return false;
                    final lentDay = DateTime(lent.year, lent.month, lent.day);
                    final dueDay = DateTime(due.year, due.month, due.day);
                    return !lentDay.isAfter(today) && !dueDay.isBefore(today);
                  }).toList();

                  final history = allLoans.where((l) =>
                    l['status'] == 'returned' ||
                    l['status'] == 'lost' ||
                    l['status'] == 'cancelled',
                  ).toList()..sort((a, b) {
                    final ra = a['returnedAt'] as Timestamp? ?? a['lentAt'] as Timestamp? ?? Timestamp.now();
                    final rb = b['returnedAt'] as Timestamp? ?? b['lentAt'] as Timestamp? ?? Timestamp.now();
                    return rb.compareTo(ra);
                  });

                  return _LoansPretTab(
                    clubId: widget.clubId,
                    allLoans: allLoans,
                    activeLoans: activeLoans,
                    overdueLoans: overdueLoans,
                    history: history,
                    showCancelButtons: showCancelButtons,
                    filter: _pretsFilter,
                    onFilterChanged: (f) => setState(() => _pretsFilter = f),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Section catalogue de prêts (onglet Catalogue)
class _LoanCatalogSection extends StatelessWidget {
  final String clubId;

  const _LoanCatalogSection({required this.clubId});

  // ── Static helpers appelés depuis l'AppBar ──────────────────────────────────

  static void showPaymentMethodsDialog(BuildContext context, String clubId) {
    appFirestore.collection(FirebaseCollections.clubs).doc(clubId).get().then((docSnap) {
      final current = docSnap.data()?['paymentMethods'] as List<dynamic>? ?? [];
      final selectedMethods = Set<String>.from(current.map((e) => e.toString()));
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text("Moyens de paiement"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in [
                  ('carte', Icons.credit_card_outlined, 'Carte bancaire'),
                  ('cheque', Icons.article_outlined, 'Chèque'),
                  ('especes', Icons.payments_outlined, 'Espèces'),
                ])
                  CheckboxListTile(
                    secondary: Icon(entry.$2),
                    title: Text(entry.$3),
                    value: selectedMethods.contains(entry.$1),
                    onChanged: (v) => setS(() {
                      if (v == true) { selectedMethods.add(entry.$1); } else { selectedMethods.remove(entry.$1); }
                    }),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await appFirestore.collection(FirebaseCollections.clubs).doc(clubId).update({'paymentMethods': selectedMethods.toList()});
                    if (ctx.mounted) { Navigator.of(dialogContext).pop(); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Moyens de paiement mis à jour."))); }
                  } catch (e) {
                    if (ctx.mounted) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e)))); }
                  }
                },
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        ),
      );
    });
  }

  static void showLoanAllowedDaysDialog(BuildContext context, String clubId) {
    appFirestore.collection(FirebaseCollections.clubs).doc(clubId).get().then((docSnap) {
      final data = docSnap.data() ?? {};
      final clubAddress = data['address'] as String? ?? '';
      final current = data['loanAllowedWeekdays'] as List<dynamic>? ?? [];
      final loanScheduleRaw = data['loanSchedule'] as Map<String, dynamic>? ?? {};
      final selectedDays = Set<int>.from(
        current.map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7),
      );
      if (selectedDays.isEmpty && current.isEmpty) { for (int i = 1; i <= 7; i++) { selectedDays.add(i); } }
      final Map<int, ({int startHour, int startMinute, int endHour, int endMinute, String place})> schedule = {};
      for (int d = 1; d <= 7; d++) {
        final raw = loanScheduleRaw[d.toString()] as Map<String, dynamic>?;
        schedule[d] = raw != null
            ? (startHour: raw['startHour'] as int? ?? 8, startMinute: raw['startMinute'] as int? ?? 0, endHour: raw['endHour'] as int? ?? 20, endMinute: raw['endMinute'] as int? ?? 0, place: raw['place'] as String? ?? clubAddress)
            : (startHour: 8, startMinute: 0, endHour: 20, endMinute: 0, place: clubAddress);
      }
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => _LoanAllowedDaysDialog(
          clubId: clubId,
          selectedDays: selectedDays,
          schedule: schedule,
          defaultPlace: clubAddress,
          onSave: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jours de récupération/retour mis à jour."))); }
          },
        ),
      );
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .snapshots(),
      builder: (context, catalogSnap) {
        final catalogItems = catalogSnap.data?.docs ?? [];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      catalogItems.isEmpty ? "Catalogue vide" : "${catalogItems.length} équipement${catalogItems.length > 1 ? 's' : ''}",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(context: context, builder: (_) => _ManageCatalogDialog(clubId: clubId)),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text("Gérer"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (catalogItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text("Aucun équipement dans le catalogue",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => showDialog<void>(context: context, builder: (_) => _ManageCatalogDialog(clubId: clubId)),
                          child: const Text("Ajouter depuis l'inventaire"),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final doc = catalogItems[i];
                      return _CatalogItemCard(clubId: clubId, equipmentId: doc.id, data: doc.data());
                    },
                    childCount: catalogItems.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

// ── Onglet Prêts avec filter chips ─────────────────────────────────────────────

class _LoansPretTab extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;
  final List<Map<String, dynamic>> activeLoans;
  final List<Map<String, dynamic>> overdueLoans;
  final List<Map<String, dynamic>> history;
  final bool showCancelButtons;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _LoansPretTab({
    required this.clubId,
    required this.allLoans,
    required this.activeLoans,
    required this.overdueLoans,
    required this.history,
    required this.showCancelButtons,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter chips ──────────────────────────────────────────────────────
        _LoansFilterBar(
          clubId: clubId,
          allLoans: allLoans,
          overdueCount: overdueLoans.length,
          historyCount: history.length,
          filter: filter,
          onFilterChanged: onFilterChanged,
        ),
        const Divider(height: 1),

        // ── Contenu filtré ────────────────────────────────────────────────────
        Expanded(
          child: _buildFilteredContent(context),
        ),
      ],
    );
  }

  Widget _buildFilteredContent(BuildContext context) {
    switch (filter) {
      case 'demandes':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _LoanRequestsSection(clubId: clubId),
              const SizedBox(height: 16),
              _LoanChangeRequestsSection(clubId: clubId),
            ],
          ),
        );
      case 'actifs':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _PickupToConfirmSection(clubId: clubId, allLoans: allLoans, showCancelButtons: showCancelButtons),
              const SizedBox(height: 8),
              _ActiveLoansSection(clubId: clubId, allLoans: allLoans, showCancelButtons: showCancelButtons),
              _UpcomingLoansSection(clubId: clubId, showCancelButtons: showCancelButtons),
            ],
          ),
        );
      case 'retard':
        if (overdueLoans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("Aucun retard", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _OverdueLoansSection(clubId: clubId, allLoans: allLoans, showCancelButtons: showCancelButtons),
        );
      case 'historique':
        if (history.isEmpty) {
          return Center(
            child: Text("Aucun historique", style: TextStyle(color: Colors.grey.shade500)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.take(50).length,
          itemBuilder: (_, i) => _LoanHistoryTile(data: history[i], clubId: clubId),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _LoansFilterBar extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;
  final int overdueCount;
  final int historyCount;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _LoansFilterBar({
    required this.clubId,
    required this.allLoans,
    required this.overdueCount,
    required this.historyCount,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, reqSnap) {
        final pendingRequests = reqSnap.data?.docs.length ?? 0;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final activeCount = allLoans.where((l) {
          if (l['status'] != 'active') return false;
          final lent = (l['lentAt'] as Timestamp?)?.toDate();
          final due = (l['dueAt'] as Timestamp?)?.toDate();
          if (lent == null || due == null) return false;
          final lentDay = DateTime(lent.year, lent.month, lent.day);
          final dueDay = DateTime(due.year, due.month, due.day);
          return !lentDay.isAfter(today) && !dueDay.isBefore(today);
        }).length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _FilterChip(
                label: "Demandes",
                count: pendingRequests,
                active: filter == 'demandes',
                urgency: pendingRequests > 0,
                onTap: () => onFilterChanged('demandes'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: "Actifs",
                count: activeCount,
                active: filter == 'actifs',
                onTap: () => onFilterChanged('actifs'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: "En retard",
                count: overdueCount,
                active: filter == 'retard',
                urgency: overdueCount > 0,
                onTap: () => onFilterChanged('retard'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: "Historique",
                count: historyCount,
                active: filter == 'historique',
                onTap: () => onFilterChanged('historique'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final bool urgency;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.urgency = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgency && !active ? ViroColors.error : ViroColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ViroColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? ViroColors.primary : (urgency ? ViroColors.error : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : (urgency ? color : Colors.grey.shade700),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withAlpha(50) : color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Données horaires et lieu pour un jour (récup./retour prêt)
class _DaySchedule {
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;
  String place;

  _DaySchedule({
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 20,
    this.endMinute = 0,
    this.place = '',
  });

  _DaySchedule copyWith({
    int? startHour, int? startMinute,
    int? endHour,   int? endMinute,
    String? place,
  }) => _DaySchedule(
    startHour: startHour ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour: endHour ?? this.endHour,
    endMinute: endMinute ?? this.endMinute,
    place: place ?? this.place,
  );
}

/// Dialog pour configurer les jours, horaires et lieux de récup./retour
class _LoanAllowedDaysDialog extends StatefulWidget {
  final String clubId;
  final Set<int> selectedDays;
  final Map<int, ({int startHour, int startMinute, int endHour, int endMinute, String place})> schedule;
  final String defaultPlace;
  final VoidCallback onSave;

  const _LoanAllowedDaysDialog({
    required this.clubId,
    required this.selectedDays,
    required this.schedule,
    required this.defaultPlace,
    required this.onSave,
  });

  @override
  State<_LoanAllowedDaysDialog> createState() => _LoanAllowedDaysDialogState();
}

class _LoanAllowedDaysDialogState extends State<_LoanAllowedDaysDialog> {
  late Set<int> _selectedDays;
  late Map<int, _DaySchedule> _schedule;
  final Map<int, TextEditingController> _placeControllers = {};
  bool _saving = false;

  static const _weekdays = [
    (1, 'Lun'), (2, 'Mar'), (3, 'Mer'),
    (4, 'Jeu'), (5, 'Ven'), (6, 'Sam'), (7, 'Dim'),
  ];
  static const _weekdaysFull = [
    (1, 'Lundi'), (2, 'Mardi'), (3, 'Mercredi'),
    (4, 'Jeudi'), (5, 'Vendredi'), (6, 'Samedi'), (7, 'Dimanche'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDays = Set<int>.from(widget.selectedDays);
    _schedule = {};
    for (int d = 1; d <= 7; d++) {
      final s = widget.schedule[d]!;
      _schedule[d] = _DaySchedule(
        startHour: s.startHour, startMinute: s.startMinute,
        endHour: s.endHour, endMinute: s.endMinute, place: s.place,
      );
      _placeControllers[d] = TextEditingController(text: s.place);
    }
  }

  @override
  void dispose() {
    for (final c in _placeControllers.values) { c.dispose(); }
    super.dispose();
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int dayNum, bool isStart) async {
    final s = _schedule[dayNum]!;
    final initial = TimeOfDay(
      hour: isStart ? s.startHour : s.endHour,
      minute: isStart ? s.startMinute : s.endMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _schedule[dayNum] = s.copyWith(startHour: picked.hour, startMinute: picked.minute);
      } else {
        _schedule[dayNum] = s.copyWith(endHour: picked.hour, endMinute: picked.minute);
      }
    });
  }

  void _copyToAll(int sourceDayNum) {
    final source = _schedule[sourceDayNum]!;
    final sourcePlace = _placeControllers[sourceDayNum]?.text ?? source.place;
    setState(() {
      for (final d in _selectedDays) {
        if (d == sourceDayNum) continue;
        _schedule[d] = source.copyWith(place: sourcePlace);
        _placeControllers[d]?.text = sourcePlace;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final d in _selectedDays) {
        final s = _schedule[d]!;
        final placeText = _placeControllers[d]?.text.trim() ?? s.place;
        scheduleMap[d.toString()] = {
          'startHour': s.startHour, 'startMinute': s.startMinute,
          'endHour': s.endHour, 'endMinute': s.endMinute,
          'place': placeText.isEmpty ? widget.defaultPlace : placeText,
        };
      }
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .update({
            'loanAllowedWeekdays': _selectedDays.toList()..sort(),
            'loanSchedule': scheduleMap,
          });
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelected = _selectedDays.toList()..sort();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Récupération / Retour",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Définissez les jours et horaires auxquels les joueurs peuvent récupérer ou rendre le matériel.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 16),

          // Sélecteur de jours (chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekdays.map((e) {
                final dayNum = e.$1;
                final label = e.$2;
                final selected = _selectedDays.contains(dayNum);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedDays.remove(dayNum);
                    } else {
                      _selectedDays.add(dayNum);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? ViroColors.primary : Colors.grey.shade100,
                      border: Border.all(
                        color: selected ? ViroColors.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          // Liste des jours sélectionnés
          Flexible(
            child: sortedSelected.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Aucun jour sélectionné",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: sortedSelected.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final dayNum = sortedSelected[i];
                      final dayLabel = _weekdaysFull.firstWhere((e) => e.$1 == dayNum).$2;
                      final s = _schedule[dayNum]!;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayLabel,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const Spacer(),
                                if (sortedSelected.length > 1)
                                  TextButton.icon(
                                    onPressed: () => _copyToAll(dayNum),
                                    icon: const Icon(Icons.copy_all_outlined, size: 14),
                                    label: const Text("Copier sur tous", style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Plage horaire
                            Row(
                              children: [
                                const Icon(Icons.schedule_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                _TimeChip(
                                  label: _fmt(s.startHour, s.startMinute),
                                  onTap: () => _pickTime(dayNum, true),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('→', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                ),
                                _TimeChip(
                                  label: _fmt(s.endHour, s.endMinute),
                                  onTap: () => _pickTime(dayNum, false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Lieu
                            TextField(
                              controller: _placeControllers[dayNum],
                              onChanged: (v) => _schedule[dayNum] = s.copyWith(place: v),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: widget.defaultPlace.isEmpty
                                    ? "Lieu de récup./retour"
                                    : widget.defaultPlace,
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Actions
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text("Annuler"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ViroColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Enregistrer"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ViroColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ViroColors.primary.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ViroColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 12, color: ViroColors.primary.withAlpha(180)),
          ],
        ),
      ),
    );
  }
}

void _showImageFullScreen(BuildContext context, String imageUrl) {
  final size = MediaQuery.sizeOf(context);
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width - 48,
                  maxHeight: size.height * 0.8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.close, color: Colors.black87),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Carte d'un équipement dans le catalogue
class _CatalogItemCard extends StatelessWidget {
  final String clubId;
  final String equipmentId;
  final Map<String, dynamic> data;

  const _CatalogItemCard({
    required this.clubId,
    required this.equipmentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipment)
          .doc(equipmentId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final equipmentData = snap.data!.data() ?? {};
        final name = equipmentData['name'] as String? ?? 'Équipement inconnu';
        final maxQuantity = data['maxQuantity'] as int? ?? 1;
        final price = data['price'] as num?;
        final priceUnit = data['priceUnit'] as String? ?? 'jour';
        final maxLoanDuration = data['maxLoanDurationDays'] as int?;
        final imageUrl = equipmentData['imageUrl'] as String?;

        String priceUnitLabel(String unit) {
          switch (unit) {
            case 'jour':
              return 'jour';
            case 'semaine':
              return 'semaine';
            case 'mois':
              return 'mois';
            default:
              return unit;
          }
        }

        String? formatMaxLoanDuration(int? days, String unit) {
          if (days == null) return null;
          switch (unit) {
            case 'jour':
              return '$days jour(s)';
            case 'semaine':
              final weeks = (days / 7).round();
              return '$weeks semaine(s)';
            case 'mois':
              final months = (days / 30).round();
              return '$months mois';
            default:
              return '$days jour(s)';
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: imageUrl != null && imageUrl.isNotEmpty
                ? GestureDetector(
                    onTap: () => _showImageFullScreen(context, imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            title: Text(
              name,
              style: const TextStyle(
                color: ViroColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      const TextSpan(
                        text: 'Max: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '$maxQuantity unité(s)'),
                    ],
                  ),
                ),
                if (price != null)
                  Text.rich(
                    TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: 'Prix: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              '${price.toStringAsFixed(2)} €/${priceUnitLabel(priceUnit)}',
                        ),
                      ],
                    ),
                  ),
                if (maxLoanDuration != null)
                  Text.rich(
                    TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: 'Durée max: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              formatMaxLoanDuration(
                                maxLoanDuration,
                                priceUnit,
                              ) ??
                              '',
                        ),
                      ],
                    ),
                  ),
                if (data['caution'] != null)
                  Text.rich(
                    TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: 'Caution: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              '${(data['caution'] as num).toStringAsFixed(2)} €',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: ViroColors.error),
              onPressed: () => _deleteCatalogItem(context),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteCatalogItem(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer du catalogue"),
        content: const Text(
          "Êtes-vous sûr de vouloir retirer cet équipement du catalogue ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: ViroColors.error),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .doc(equipmentId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Équipement retiré du catalogue.")),
        );
      }
    }
  }
}

/// Dialog pour gérer le catalogue (ajouter/modifier des équipements)
class _ManageCatalogDialog extends StatefulWidget {
  final String clubId;

  const _ManageCatalogDialog({required this.clubId});

  @override
  State<_ManageCatalogDialog> createState() => _ManageCatalogDialogState();
}

class _ManageCatalogDialogState extends State<_ManageCatalogDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Gérer le catalogue de prêts",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: appFirestore
                      .collection(FirebaseCollections.clubs)
                      .doc(widget.clubId)
                      .collection(FirebaseCollections.equipment)
                      .snapshots(),
                  builder: (context, equipmentSnap) {
                    final allEquipment = equipmentSnap.data?.docs ?? [];
                    if (allEquipment.isEmpty) {
                      return const Center(
                        child: Text("Aucun équipement disponible."),
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: appFirestore
                          .collection(FirebaseCollections.clubs)
                          .doc(widget.clubId)
                          .collection(FirebaseCollections.equipmentCatalog)
                          .snapshots(),
                      builder: (context, catalogSnap) {
                        final catalogIds = (catalogSnap.data?.docs ?? [])
                            .map((d) => d.id)
                            .toSet();

                        return ListView(
                          children: allEquipment.map((doc) {
                            final data = doc.data();
                            final id = doc.id;
                            final name = data['name'] as String? ?? 'Sans nom';
                            final isInCatalog = catalogIds.contains(id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(name),
                                trailing: isInCatalog
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: ViroColors.primary,
                                        ),
                                        onPressed: () =>
                                            _editCatalogItem(context, id, data),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: ViroColors.primary,
                                        ),
                                        onPressed: () =>
                                            _addToCatalog(context, id, data),
                                      ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToCatalog(
    BuildContext context,
    String equipmentId,
    Map<String, dynamic> equipmentData,
  ) async {
    await _showCatalogItemDialog(context, equipmentId, equipmentData, null);
  }

  Future<void> _editCatalogItem(
    BuildContext context,
    String equipmentId,
    Map<String, dynamic> equipmentData,
  ) async {
    final catalogDoc = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.equipmentCatalog)
        .doc(equipmentId)
        .get();

    if (!context.mounted) return;
    final catalogData = catalogDoc.data();
    await _showCatalogItemDialog(
      context,
      equipmentId,
      equipmentData,
      catalogData,
    );
  }

  Future<void> _showCatalogItemDialog(
    BuildContext context,
    String equipmentId,
    Map<String, dynamic> equipmentData,
    Map<String, dynamic>? existingCatalogData,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CatalogItemDialog(
        clubId: widget.clubId,
        equipmentId: equipmentId,
        equipmentData: equipmentData,
        existingCatalogData: existingCatalogData,
      ),
    );
  }
}

/// Dialog pour ajouter/modifier un équipement dans le catalogue
class _CatalogItemDialog extends StatefulWidget {
  final String clubId;
  final String equipmentId;
  final Map<String, dynamic> equipmentData;
  final Map<String, dynamic>? existingCatalogData;

  const _CatalogItemDialog({
    required this.clubId,
    required this.equipmentId,
    required this.equipmentData,
    this.existingCatalogData,
  });

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  late TextEditingController _maxQuantityController;
  late TextEditingController _priceController;
  late TextEditingController _cautionController;
  late TextEditingController _maxLoanDurationController;
  String _priceUnit = 'jour';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _maxQuantityController = TextEditingController(
      text: widget.existingCatalogData?['maxQuantity']?.toString() ?? '1',
    );
    final catalogPrice = widget.existingCatalogData?['price'] as num?;
    final equipmentLoanPrice = widget.equipmentData['loanUnitPrice'] as num?;
    _priceController = TextEditingController(
      text: (catalogPrice ?? equipmentLoanPrice)?.toString() ?? '',
    );
    final catalogCaution = widget.existingCatalogData?['caution'] as num?;
    final equipmentCaution = widget.equipmentData['caution'] as num?;
    _cautionController = TextEditingController(
      text: (catalogCaution ?? equipmentCaution)?.toString() ?? '',
    );
    _priceUnit = widget.existingCatalogData?['priceUnit'] as String? ?? 'jour';
    final maxLoanDurationDays =
        widget.existingCatalogData?['maxLoanDurationDays'] as int?;
    _maxLoanDurationController = TextEditingController(
      text: maxLoanDurationDays != null ? _daysToUnit(maxLoanDurationDays, _priceUnit).toString() : '',
    );
  }

  @override
  void dispose() {
    _maxQuantityController.dispose();
    _priceController.dispose();
    _cautionController.dispose();
    _maxLoanDurationController.dispose();
    super.dispose();
  }

  static int _daysToUnit(int days, String unit) {
    switch (unit) {
      case 'semaine': return (days / 7).round();
      case 'mois': return (days / 30).round();
      default: return days;
    }
  }

  static int _unitToDays(int value, String unit) {
    switch (unit) {
      case 'semaine': return value * 7;
      case 'mois': return value * 30;
      default: return value;
    }
  }

  void _changeUnit(String newUnit) {
    if (newUnit == _priceUnit) return;
    final currentValue = int.tryParse(_maxLoanDurationController.text.trim());
    if (currentValue != null && currentValue > 0) {
      final days = _unitToDays(currentValue, _priceUnit);
      final converted = _daysToUnit(days, newUnit);
      _maxLoanDurationController.text = converted > 0 ? converted.toString() : '';
    }
    setState(() => _priceUnit = newUnit);
  }

  String get _unitShort {
    switch (_priceUnit) {
      case 'semaine': return 'sem.';
      case 'mois': return 'mois';
      default: return 'jour';
    }
  }

  String get _unitPlural {
    switch (_priceUnit) {
      case 'semaine': return 'semaines';
      case 'mois': return 'mois';
      default: return 'jours';
    }
  }

  Future<void> _save() async {
    final maxQty = int.tryParse(_maxQuantityController.text.trim());
    final price = _priceController.text.trim().isEmpty
        ? null
        : double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    final caution = _cautionController.text.trim().isEmpty
        ? null
        : double.tryParse(_cautionController.text.trim().replaceAll(',', '.'));
    final durationValue = _maxLoanDurationController.text.trim().isEmpty
        ? null
        : int.tryParse(_maxLoanDurationController.text.trim());
    final maxLoanDurationDays = durationValue != null ? _unitToDays(durationValue, _priceUnit) : null;

    final quantityTotal =
        widget.equipmentData['quantityTotal'] as int? ??
        widget.equipmentData['quantity'] as int? ??
        0;

    if (maxQty == null || maxQty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La quantité doit être au moins 1.")),
      );
      return;
    }
    if (maxQty > quantityTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Maximum disponible : $quantityTotal.")),
      );
      return;
    }
    if (durationValue != null && durationValue < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La durée doit être au moins 1.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .doc(widget.equipmentId)
          .set({
            'equipmentId': widget.equipmentId,
            'maxQuantity': maxQty,
            'price': price,
            'caution': caution,
            'priceUnit': _priceUnit,
            'maxLoanDurationDays': maxLoanDurationDays,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingCatalogData == null
                  ? "Équipement ajouté au catalogue."
                  : "Catalogue mis à jour.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantityTotal =
        widget.equipmentData['quantityTotal'] as int? ??
        widget.equipmentData['quantity'] as int? ??
        0;
    final imageUrl = widget.equipmentData['imageUrl'] as String?;
    final name = widget.equipmentData['name'] as String? ?? 'Équipement';

    return AlertDialog(
      title: Text(
        widget.existingCatalogData == null ? "Ajouter au catalogue" : "Modifier",
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête équipement
              Row(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(),
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2_outlined, size: 22, color: Colors.grey.shade400),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '$quantityTotal en stock',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quantité proposable
              TextField(
                controller: _maxQuantityController,
                keyboardType: TextInputType.number,
                enabled: !_saving,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "Quantité disponible au prêt",
                  hintText: "ex. 3",
                  helperText: "Max. $quantityTotal",
                  suffixText: "/ $quantityTotal",
                ),
              ),
              const SizedBox(height: 20),

              // Prix + unité de temps (inline)
              Text(
                "Tarification",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),

              // Sélecteur d'unité (SegmentedButton)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'jour',    label: Text('/ jour')),
                  ButtonSegment(value: 'semaine', label: Text('/ semaine')),
                  ButtonSegment(value: 'mois',    label: Text('/ mois')),
                ],
                selected: {_priceUnit},
                onSelectionChanged: _saving ? null : (s) => _changeUnit(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: "Prix",
                        hintText: "ex. 2.50",
                        suffixText: "€/$_unitShort",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cautionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: "Caution",
                        hintText: "ex. 50",
                        suffixText: "€",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Durée max (hérite de l'unité du prix)
              Text(
                "Durée maximale",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maxLoanDurationController,
                keyboardType: TextInputType.number,
                enabled: !_saving,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: "Illimitée si vide",
                  suffixText: _unitPlural,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existingCatalogData == null ? "Ajouter" : "Modifier"),
        ),
      ],
    );
  }
}

/// Tuile read-only pour l'historique des prêts (retournés / annulés).
class _LoanHistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String clubId;

  const _LoanHistoryTile({required this.data, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final borrowerName = data['borrowerName'] as String? ?? 'Inconnu';
    final equipmentName = data['equipmentName'] as String? ?? '—';
    final quantity = data['quantity'] as int? ?? 1;
    final loanUnitPrice = data['loanUnitPrice'] as num?;
    final status = data['status'] as String? ?? '';
    final lentAt = data['lentAt'] as Timestamp?;
    final returnedAt = data['returnedAt'] as Timestamp?;
    final lentStr = lentAt != null
        ? DateFormat('d MMM yyyy', 'fr_FR').format(lentAt.toDate())
        : '—';
    final returnedStr = returnedAt != null
        ? DateFormat('d MMM yyyy', 'fr_FR').format(returnedAt.toDate())
        : '—';
    final loanId = data['id'] as String?;
    final isCancelled = status == 'cancelled';
    final isReturned = status == 'returned';
    final statusLabel = isCancelled
        ? "Annulé le $returnedStr"
        : "Retour $returnedStr";
    final canUndoReturn = isReturned && loanId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          equipmentName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$borrowerName • $quantity prêté(s)'),
            Text(
              'Du $lentStr → $statusLabel',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (loanUnitPrice != null)
              Text(
                'Prix: ${loanUnitPrice.toStringAsFixed(2)} €/unité${quantity > 1 ? ' (Total: ${(loanUnitPrice * quantity).toStringAsFixed(2)} €)' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
          ],
        ),
        trailing: Tooltip(
          message: canUndoReturn ? "Annuler le retour" : "",
          child: InkWell(
            onTap: canUndoReturn
                ? () => _undoLoanReturn(context, clubId, loanId)
                : null,
            borderRadius: BorderRadius.circular(24),
            child: Chip(
              label: Text(
                isCancelled ? "Annulé" : "Retourné",
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: isCancelled
                  ? ViroColors.warning.withValues(alpha: 0.15)
                  : ViroColors.success.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section de gestion des demandes de prêt
class _LoanRequestsSection extends StatelessWidget {
  final String clubId;

  const _LoanRequestsSection({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: ViroLoader(size: 60)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FirebaseErrorHandler.buildErrorWidget(
                context,
                snapshot.error,
              ),
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        final sortedRequests = requests.toList()
          ..sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return aCreated.compareTo(bCreated);
          });

        return Card(
          color: ViroColors.warning.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.request_quote, color: ViroColors.warning),
                    const SizedBox(width: 8),
                    const Text(
                      "Demandes de prêt",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (sortedRequests.isNotEmpty)
                      Chip(
                        label: Text(
                          "${sortedRequests.length}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: ViroColors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sortedRequests.isEmpty)
                  Text(
                    "Aucune demande en attente.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  )
                else
                  ...sortedRequests.map((doc) {
                    final requestData = doc.data();
                    return _LoanRequestCard(
                      clubId: clubId,
                      requestId: doc.id,
                      requestData: requestData,
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section des demandes de modification/annulation de prêt
class _LoanChangeRequestsSection extends StatelessWidget {
  final String clubId;

  const _LoanChangeRequestsSection({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanChangeRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: ViroLoader(size: 60)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FirebaseErrorHandler.buildErrorWidget(
                context,
                snapshot.error,
              ),
            ),
          );
        }
        final requests = snapshot.data?.docs ?? [];
        final sortedRequests = requests.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return aCreated.compareTo(bCreated);
          });
        return Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_calendar, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      "Modification / Annulation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (sortedRequests.isNotEmpty)
                      Chip(
                        label: Text(
                          "${sortedRequests.length}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.orange.shade700,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sortedRequests.isEmpty)
                  Text(
                    "Aucune demande en attente.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  )
                else
                  ...sortedRequests.map((doc) {
                    final requestData = doc.data();
                    return _LoanChangeRequestCard(
                      clubId: clubId,
                      requestId: doc.id,
                      requestData: requestData,
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Carte pour une demande de modification/annulation
class _LoanChangeRequestCard extends StatelessWidget {
  final String clubId;
  final String requestId;
  final Map<String, dynamic> requestData;

  const _LoanChangeRequestCard({
    required this.clubId,
    required this.requestId,
    required this.requestData,
  });

  @override
  Widget build(BuildContext context) {
    final type = requestData['type'] as String? ?? '';
    final reason = requestData['reason'] as String? ?? '';
    final loanId = requestData['loanId'] as String?;
    final playerId = requestData['requestedBy'] as String?;
    final playerName = requestData['playerName'] as String? ?? 'Joueur';
    final newDueAt = requestData['newDueAt'] as Timestamp?;
    final newQuantity = requestData['newQuantity'] as int?;
    final newRequestedPickupDate =
        requestData['newRequestedPickupDate'] as Timestamp?;
    final createdAt = requestData['createdAt'] as Timestamp?;
    final typeLabel = type == 'cancellation' ? 'Annulation' : 'Modification';
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: loanId != null
          ? appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(clubId)
                .collection(FirebaseCollections.equipmentLoans)
                .doc(loanId)
                .get()
          : null,
      builder: (context, loanSnap) {
        final loanData = loanSnap.data?.data();
        final equipmentName =
            loanData?['equipmentName'] as String? ?? 'Équipement';
        final quantity = loanData?['quantity'] as int? ?? 1;
        final dueAt = loanData?['dueAt'] as Timestamp?;
        final dueDate = dueAt?.toDate();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "$equipmentName (x$quantity)",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: type == 'cancellation'
                          ? ViroColors.error
                          : ViroColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                UserDisplayTile(
                  userId: playerId,
                  fallback: playerName,
                  compact: true,
                  textStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Retour actuel: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Raison:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
                if (type == 'modification' &&
                    (newDueAt != null ||
                        newQuantity != null ||
                        newRequestedPickupDate != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (newRequestedPickupDate != null)
                        Text(
                          "Nouvelle date récup.: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(newRequestedPickupDate.toDate())}",
                          style: TextStyle(
                            fontSize: 13,
                            color: ViroColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (newDueAt != null)
                        Text(
                          "Nouvelle date retour: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(newDueAt.toDate())}",
                          style: TextStyle(
                            fontSize: 13,
                            color: ViroColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (newQuantity != null)
                        Text(
                          "Nouvelle quantité: $newQuantity",
                          style: TextStyle(
                            fontSize: 13,
                            color: ViroColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Demandé le: ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(createdAt.toDate())}",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _refuseChangeRequest(context, clubId, requestId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ViroColors.error,
                          side: const BorderSide(color: ViroColors.error),
                        ),
                        child: const Text("Refuser"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptChangeRequest(
                          context,
                          clubId,
                          requestId,
                          requestData,
                        ),
                        child: const Text("Accepter"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _acceptChangeRequest(
  BuildContext context,
  String clubId,
  String requestId,
  Map<String, dynamic> requestData,
) async {
  final responseController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Accepter la demande"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Voulez-vous accepter cette demande ? Un message optionnel peut être envoyé au joueur.",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: responseController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Message (optionnel)",
              hintText: "Message pour le joueur",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Accepter"),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    final type = requestData['type'] as String? ?? '';
    final loanId = requestData['loanId'] as String?;
    if (loanId == null) {
      throw Exception("Prêt introuvable");
    }
    final loanRef = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .doc(loanId);
    final changeRequestRef = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoanChangeRequests)
        .doc(requestId);
    if (type == 'cancellation') {
      await loanRef.update({
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
      });
    } else if (type == 'modification') {
      final updates = <String, dynamic>{};
      final newDueAt = requestData['newDueAt'] as Timestamp?;
      final newQuantity = requestData['newQuantity'] as int?;
      final newRequestedPickupDate =
          requestData['newRequestedPickupDate'] as Timestamp?;
      if (newRequestedPickupDate != null) {
        updates['lentAt'] = newRequestedPickupDate;
      }
      if (newDueAt != null) updates['dueAt'] = newDueAt;
      if (newQuantity != null) updates['quantity'] = newQuantity;
      if (updates.isNotEmpty) {
        await loanRef.update(updates);
      }
    }
    await changeRequestRef.update({
      'status': 'accepted',
      'adminResponse': responseController.text.trim().isNotEmpty
          ? responseController.text.trim()
          : null,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Demande acceptée."),
          backgroundColor: ViroColors.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

Future<void> _refuseChangeRequest(
  BuildContext context,
  String clubId,
  String requestId,
) async {
  final responseController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Refuser la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous refuser cette demande ? Indiquez une raison (recommandé pour le joueur).",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Raison du refus",
                hintText: "Expliquez pourquoi la demande est refusée",
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: responseController.text.trim().isEmpty
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ViroColors.error),
            child: const Text("Refuser"),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoanChangeRequests)
        .doc(requestId)
        .update({
          'status': 'refused',
          'adminResponse': responseController.text.trim().isNotEmpty
              ? responseController.text.trim()
              : null,
          'respondedAt': FieldValue.serverTimestamp(),
          'respondedBy': currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Demande refusée."),
          backgroundColor: ViroColors.error,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Confirme que le matériel a été remis au joueur.
Future<void> _confirmPickup(
  BuildContext context,
  String clubId,
  String loanId,
) async {
  try {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .doc(loanId)
        .update({'pickupConfirmed': true});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Remise confirmée."),
          backgroundColor: ViroColors.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Annule un prêt à tout moment (clôture par l'admin).
Future<void> _cancelLoan(
  BuildContext context,
  String clubId,
  String loanId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Annuler le prêt"),
      content: const Text(
        "Voulez-vous annuler ce prêt ? Le prêt sera clôturé et disparaîtra des listes actives.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Non"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: ViroColors.warning),
          child: const Text("Oui, annuler"),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .doc(loanId)
        .update({
          'status': 'cancelled',
          'returnedAt': FieldValue.serverTimestamp(),
        });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Prêt annulé."),
          backgroundColor: ViroColors.warning,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Annule un prêt à venir (demande acceptée, récupération future).
Future<void> _cancelUpcomingLoan(
  BuildContext context,
  String clubId,
  String requestId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Annuler le prêt à venir"),
      content: const Text(
        "Voulez-vous annuler ce prêt à venir ? La demande sera clôturée et disparaîtra des prochains prêts.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Non"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: ViroColors.warning),
          child: const Text("Oui, annuler"),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final requestDoc = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoanRequests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data();
    final loanId = requestData?['loanId'] as String?;

    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoanRequests)
        .doc(requestId)
        .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    String? loanIdToCancel = loanId;
    if (loanIdToCancel == null || loanIdToCancel.isEmpty) {
      final loanSnap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();
      loanIdToCancel = loanSnap.docs.isNotEmpty ? loanSnap.docs.first.id : null;
    }
    if (loanIdToCancel != null) {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .doc(loanIdToCancel)
          .update({
            'status': 'cancelled',
            'returnedAt': FieldValue.serverTimestamp(),
          });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Prêt à venir annulé."),
          backgroundColor: ViroColors.warning,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Affiche un dialog de confirmation puis marque le prêt comme retourné.
Future<void> _markLoanReturned(
  BuildContext context,
  String clubId,
  String loanId,
) async {
  try {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .doc(loanId)
        .update({
          'status': 'returned',
          'returnedAt': FieldValue.serverTimestamp(),
        });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Prêt marqué comme retourné."),
          backgroundColor: ViroColors.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

Future<void> _undoLoanReturn(
  BuildContext context,
  String clubId,
  String loanId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Annuler le retour"),
      content: const Text("Repasser ce prêt en cours ?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Confirmer"),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .doc(loanId)
        .update({'status': 'active', 'returnedAt': FieldValue.delete()});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Retour annulé, prêt repassé en cours."),
          backgroundColor: ViroColors.warning,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Section des prêts en retard (dueAt < aujourd'hui)
class _OverdueLoansSection extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;
  final bool showCancelButtons;

  const _OverdueLoansSection({
    required this.clubId,
    required this.allLoans,
    this.showCancelButtons = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdueLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (dueAt == null) return false;
      final dueDate = dueAt.toDate();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return dueDay.isBefore(today);
    }).toList();

    if (overdueLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    overdueLoans.sort((a, b) {
      final aDue = (a['dueAt'] as Timestamp?)?.toDate();
      final bDue = (b['dueAt'] as Timestamp?)?.toDate();
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });

    return Card(
      color: ViroColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ViroColors.error),
                const SizedBox(width: 8),
                const Text(
                  "Prêts en retard",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    "${overdueLoans.length}",
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: ViroColors.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...overdueLoans.map((loan) {
              final equipmentName =
                  loan['equipmentName'] as String? ?? 'Équipement';
              final quantity = loan['quantity'] as int? ?? 1;
              final borrowerName = loan['borrowerName'] as String? ?? 'Joueur';
              final borrowerId = loan['borrowerId'] as String?;
              final totalPrice = loan['totalPrice'] as num?;
              final caution = loan['caution'] as num?;
              final dueAt = loan['dueAt'] as Timestamp?;
              final lentAt = loan['lentAt'] as Timestamp?;

              final dueDate = dueAt?.toDate();
              final daysOverdue = dueDate != null
                  ? today
                        .difference(
                          DateTime(dueDate.year, dueDate.month, dueDate.day),
                        )
                        .inDays
                  : null;

              return Padding(
                key: ValueKey(loan['id']),
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ViroColors.error.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: ViroColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$equipmentName (x$quantity)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          if (showCancelButtons)
                            IconButton(
                              onPressed: () => _cancelLoan(
                                context,
                                clubId,
                                loan['id'] as String,
                              ),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: ViroColors.warning,
                              ),
                              tooltip: 'Supprimer',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      UserDisplayTile(
                        userId: borrowerId,
                        fallback: borrowerName,
                        compact: true,
                        textStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (totalPrice != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Prix: ${totalPrice.toStringAsFixed(2)} €",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (caution != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Caution: ${caution.toStringAsFixed(2)} €",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (dueDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Retour prévu: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (daysOverdue != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          daysOverdue == 1
                              ? "En retard de 1 jour"
                              : "En retard de $daysOverdue jours",
                          style: TextStyle(
                            fontSize: 12,
                            color: ViroColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (lentAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Prêté le: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(lentAt.toDate())}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SlideToConfirm(
                        label: "Confirmer retour",
                        color: ViroColors.error,
                        icon: Icons.error_outline,
                        onConfirmed: () => _markLoanReturned(
                          context,
                          clubId,
                          loan['id'] as String,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Rétrocompatibilité : prêts sans champ pickupConfirmed = considérés comme confirmés.
bool _isPickupConfirmed(Map<String, dynamic> loan) {
  final v = loan['pickupConfirmed'];
  if (v == null) return true;
  return v == true;
}

/// Section des prêts en cours (lentAt <= aujourd'hui <= dueAt, remise confirmée).
class _ActiveLoansSection extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;
  final bool showCancelButtons;

  const _ActiveLoansSection({
    required this.clubId,
    required this.allLoans,
    this.showCancelButtons = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      if (!_isPickupConfirmed(loan)) return false;
      final lentAt = loan['lentAt'] as Timestamp?;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (lentAt == null || dueAt == null) return false;

      final lentDate = lentAt.toDate();
      final dueDate = dueAt.toDate();
      final lentDay = DateTime(lentDate.year, lentDate.month, lentDate.day);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

      return !lentDay.isAfter(today) && !dueDay.isBefore(today);
    }).toList();

    activeLoans.sort((a, b) {
      final aDue = (a['dueAt'] as Timestamp?)?.toDate();
      final bDue = (b['dueAt'] as Timestamp?)?.toDate();
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: ViroColors.primary),
                const SizedBox(width: 8),
                const Text(
                  "Prêts en cours",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                if (activeLoans.isNotEmpty)
                  Chip(
                    label: Text(
                      "${activeLoans.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeLoans.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "Aucun prêt en cours.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...activeLoans.map((loan) {
                final equipmentName =
                    loan['equipmentName'] as String? ?? 'Équipement';
                final quantity = loan['quantity'] as int? ?? 1;
                final borrowerName =
                    loan['borrowerName'] as String? ?? 'Joueur';
                final borrowerId = loan['borrowerId'] as String?;
                final totalPrice = loan['totalPrice'] as num?;
                final caution = loan['caution'] as num?;
                final dueAt = loan['dueAt'] as Timestamp?;
                final lentAt = loan['lentAt'] as Timestamp?;

                final dueDate = dueAt?.toDate();
                final isDueToday =
                    dueDate != null &&
                    DateTime(dueDate.year, dueDate.month, dueDate.day) == today;
                final statusColor = isDueToday
                    ? ViroColors.primary
                    : ViroColors.success;
                final statusIcon = isDueToday
                    ? Icons.schedule
                    : Icons.check_circle_outline;

                return Padding(
                  key: ValueKey(loan['id']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$equipmentName (x$quantity)",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                            if (showCancelButtons)
                              IconButton(
                                onPressed: () => _cancelLoan(
                                  context,
                                  clubId,
                                  loan['id'] as String,
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: ViroColors.warning,
                                ),
                                tooltip: 'Supprimer',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        UserDisplayTile(
                          userId: borrowerId,
                          fallback: borrowerName,
                          compact: true,
                          textStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (totalPrice != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Prix: ${totalPrice.toStringAsFixed(2)} €",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (caution != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Caution: ${caution.toStringAsFixed(2)} €",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (dueDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            isDueToday
                                ? "Retour aujourd'hui"
                                : "Retour le: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDueToday
                                  ? ViroColors.warning
                                  : Colors.grey[700],
                              fontWeight: isDueToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                        if (lentAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Prêté le: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(lentAt.toDate())}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SlideToConfirm(
                          label: "Confirmer retour",
                          color: statusColor,
                          icon: statusIcon,
                          onConfirmed: () => _markLoanReturned(
                            context,
                            clubId,
                            loan['id'] as String,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Section des prêts à confirmer remise (jour J et pendant la durée, remise non confirmée).
class _PickupToConfirmSection extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;
  final bool showCancelButtons;

  const _PickupToConfirmSection({
    required this.clubId,
    required this.allLoans,
    this.showCancelButtons = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final toConfirm = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      if (loan['pickupConfirmed'] != false) return false;
      final lentAt = loan['lentAt'] as Timestamp?;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (lentAt == null || dueAt == null) return false;
      final lentDay = DateTime(
        lentAt.toDate().year,
        lentAt.toDate().month,
        lentAt.toDate().day,
      );
      final dueDay = DateTime(
        dueAt.toDate().year,
        dueAt.toDate().month,
        dueAt.toDate().day,
      );
      return !lentDay.isAfter(today) && !dueDay.isBefore(today);
    }).toList();

    toConfirm.sort((a, b) {
      final aDue = (a['dueAt'] as Timestamp?)?.toDate();
      final bDue = (b['dueAt'] as Timestamp?)?.toDate();
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });

    if (toConfirm.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: ViroColors.warning.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, color: ViroColors.warning),
                const SizedBox(width: 8),
                const Text(
                  "À confirmer remise",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    "${toConfirm.length}",
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: ViroColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...toConfirm.map((loan) {
              final equipmentName =
                  loan['equipmentName'] as String? ?? 'Équipement';
              final quantity = loan['quantity'] as int? ?? 1;
              final borrowerName = loan['borrowerName'] as String? ?? 'Joueur';
              final borrowerId = loan['borrowerId'] as String?;
              final lentAt = loan['lentAt'] as Timestamp?;
              final dueAt = loan['dueAt'] as Timestamp?;
              return Padding(
                key: ValueKey(loan['id']),
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ViroColors.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: ViroColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$equipmentName (x$quantity)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          if (showCancelButtons)
                            IconButton(
                              onPressed: () => _cancelLoan(
                                context,
                                clubId,
                                loan['id'] as String,
                              ),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: ViroColors.warning,
                              ),
                              tooltip: 'Supprimer',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      UserDisplayTile(
                        userId: borrowerId,
                        fallback: borrowerName,
                        compact: true,
                        textStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (lentAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Récup prévue: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(lentAt.toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (dueAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Retour: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueAt.toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SlideToConfirm(
                        label: "Confirmer remise",
                        color: ViroColors.warning,
                        icon: Icons.handshake_outlined,
                        onConfirmed: () => _confirmPickup(
                          context,
                          clubId,
                          loan['id'] as String,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Section des prochains prêts (acceptés mais pas encore récupérés)
class _UpcomingLoansSection extends StatelessWidget {
  final String clubId;
  final bool showCancelButtons;

  const _UpcomingLoansSection({
    required this.clubId,
    required this.showCancelButtons,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: ViroLoader(size: 60)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FirebaseErrorHandler.buildErrorWidget(
                context,
                snapshot.error,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;

        final upcomingLoans = requests.where((doc) {
          final data = doc.data();
          final requestedPickupDate = data['requestedPickupDate'] as Timestamp?;
          if (requestedPickupDate == null) return false;
          final pickupDate = requestedPickupDate.toDate();
          final pickupDay = DateTime(
            pickupDate.year,
            pickupDate.month,
            pickupDate.day,
          );
          return pickupDay.isAfter(today);
        }).toList();

        if (upcomingLoans.isEmpty) {
          return const SizedBox.shrink();
        }

        upcomingLoans.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = (aData['requestedPickupDate'] as Timestamp?)?.toDate();
          final bDate = (bData['requestedPickupDate'] as Timestamp?)?.toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: ViroColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      "Prochains prêts",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        "${upcomingLoans.length}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: ViroColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...upcomingLoans.map((doc) {
                  final data = doc.data();
                  final equipmentName =
                      data['equipmentName'] as String? ?? 'Équipement';
                  final quantity = data['quantity'] as int? ?? 1;
                  final borrowerName =
                      data['playerName'] as String? ?? 'Joueur';
                  final playerId = data['playerId'] as String?;
                  final requestedPickupDate =
                      data['requestedPickupDate'] as Timestamp?;
                  final duration = data['duration'] as int? ?? 0;
                  final durationUnit =
                      data['durationUnit'] as String? ?? 'jour';
                  final totalPrice = data['totalPrice'] as num?;
                  final caution = data['caution'] as num?;

                  String durationUnitLabel(String unit) {
                    switch (unit) {
                      case 'jour':
                        return 'jour(s)';
                      case 'semaine':
                        return 'semaine(s)';
                      case 'mois':
                        return 'mois';
                      default:
                        return unit;
                    }
                  }

                  final pickupDate = requestedPickupDate?.toDate();
                  final daysUntilPickup = pickupDate?.difference(today).inDays;

                  return Padding(
                    key: ValueKey(doc.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ViroColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: ViroColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$equipmentName (x$quantity)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                              ),
                              if (showCancelButtons)
                                IconButton(
                                  onPressed: () => _cancelUpcomingLoan(
                                    context,
                                    clubId,
                                    doc.id,
                                  ),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: ViroColors.warning,
                                  ),
                                  tooltip: 'Supprimer',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          UserDisplayTile(
                            userId: playerId,
                            fallback: borrowerName,
                            compact: true,
                            textStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (totalPrice != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Prix: ${totalPrice.toStringAsFixed(2)} €",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (caution != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Caution: ${caution.toStringAsFixed(2)} €",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (pickupDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Récupération: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(pickupDate)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (daysUntilPickup != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              daysUntilPickup == 1
                                  ? "Dans 1 jour"
                                  : "Dans $daysUntilPickup jours",
                              style: TextStyle(
                                fontSize: 12,
                                color: ViroColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            "Durée: $duration ${durationUnitLabel(durationUnit)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Carte pour une demande de prêt
class _LoanRequestCard extends StatelessWidget {
  final String clubId;
  final String requestId;
  final Map<String, dynamic> requestData;

  const _LoanRequestCard({
    required this.clubId,
    required this.requestId,
    required this.requestData,
  });

  @override
  Widget build(BuildContext context) {
    final playerName = requestData['playerName'] as String? ?? 'Joueur inconnu';
    final playerId = requestData['playerId'] as String?;
    final equipmentName =
        requestData['equipmentName'] as String? ?? 'Équipement';
    final quantity = requestData['quantity'] as int? ?? 1;
    final duration = requestData['duration'] as int? ?? 0;
    final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
    final reason = requestData['reason'] as String? ?? '';
    final requestedPickupDate =
        requestData['requestedPickupDate'] as Timestamp?;
    final createdAt = requestData['createdAt'] as Timestamp?;

    String durationUnitLabel(String unit) {
      switch (unit) {
        case 'jour':
          return 'jour(s)';
        case 'semaine':
          return 'semaine(s)';
        case 'mois':
          return 'mois';
        default:
          return unit;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipmentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "Demandé par ",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          UserDisplayTile(
                            userId: playerId,
                            fallback: playerName,
                            compact: true,
                            textStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: const Text(
                    "En attente",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: ViroColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Quantité: $quantity • Durée: $duration ${durationUnitLabel(durationUnit)}",
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (requestData['totalPrice'] != null ||
                requestData['caution'] != null) ...[
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  if (requestData['totalPrice'] != null)
                    Text(
                      "Prix: ${(requestData['totalPrice'] as num).toStringAsFixed(2)} €",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  if (requestData['caution'] != null)
                    Text(
                      "Caution: ${(requestData['caution'] as num).toStringAsFixed(2)} €",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
            if (requestedPickupDate != null) ...[
              const SizedBox(height: 4),
              Text(
                "Récupération souhaitée: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(requestedPickupDate.toDate())}",
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Raison:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                "Demandé le: ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(createdAt.toDate())}",
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _refuseRequest(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ViroColors.error,
                      side: const BorderSide(color: ViroColors.error),
                    ),
                    child: const Text("Refuser"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(context),
                    child: const Text("Accepter"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(BuildContext context) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Accepter la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous accepter cette demande de prêt ?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Message (optionnel)",
                hintText: "Ajoutez un message pour le joueur",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Accepter"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      final requestDoc = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .get();

      final requestData = requestDoc.data();
      if (requestData == null) {
        throw Exception("Demande introuvable");
      }

      final requestedPickupDate =
          requestData['requestedPickupDate'] as Timestamp?;
      final duration = requestData['duration'] as int? ?? 0;
      final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
      final equipmentId = requestData['equipmentId'] as String? ?? '';
      final equipmentName =
          requestData['equipmentName'] as String? ?? 'Équipement';
      final quantity = requestData['quantity'] as int? ?? 1;
      final playerId = requestData['playerId'] as String? ?? '';
      final playerName = requestData['playerName'] as String? ?? 'Joueur';
      final totalPrice = requestData['totalPrice'] as num?;
      final caution = requestData['caution'] as num?;

      if (requestedPickupDate == null) {
        throw Exception("Date de récupération manquante");
      }

      final pickupDate = requestedPickupDate.toDate();
      int durationDays = duration;
      if (durationUnit == 'semaine') {
        durationDays = duration * 7;
      } else if (durationUnit == 'mois') {
        durationDays = duration * 30;
      }
      final returnDate = pickupDate.add(Duration(days: durationDays));

      final loanRef = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .add({
            'equipmentId': equipmentId,
            'equipmentName': equipmentName,
            'quantity': quantity,
            'borrowerId': playerId,
            'borrowerName': playerName,
            'lentAt': requestedPickupDate,
            'dueAt': Timestamp.fromDate(returnDate),
            'status': 'active',
            'pickupConfirmed': false,
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
            if (totalPrice != null) 'totalPrice': totalPrice,
            if (caution != null) 'caution': caution,
          });

      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'accepted',
            'loanId': loanRef.id,
            'adminResponse': responseController.text.trim().isNotEmpty
                ? responseController.text.trim()
                : null,
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande acceptée et prêt créé avec succès !"),
            backgroundColor: ViroColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }

  Future<void> _refuseRequest(BuildContext context) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Refuser la demande"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Voulez-vous refuser cette demande de prêt ?",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: responseController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Raison du refus *",
                  hintText: "Expliquez pourquoi la demande est refusée",
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: responseController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ViroColors.error,
              ),
              child: const Text("Refuser"),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    if (responseController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez indiquer une raison de refus."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'refused',
            'adminResponse': responseController.text.trim(),
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande refusée."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }
}
