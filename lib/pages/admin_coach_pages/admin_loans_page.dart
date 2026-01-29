import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';

class AdminLoansPage extends StatefulWidget {
  final String clubId;

  const AdminLoansPage({super.key, required this.clubId});

  @override
  State<AdminLoansPage> createState() => _AdminLoansPageState();
}

class _AdminLoansPageState extends State<AdminLoansPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Prêts"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Catalogue"),
            Tab(text: "Prêt"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _LoanCatalogSection(clubId: widget.clubId),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirebaseCollections.clubs)
                .doc(widget.clubId)
                .collection(FirebaseCollections.equipmentLoans)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    "Erreur : ${snap.error}",
                    style: const TextStyle(color: ViroColors.error),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              final allLoans = docs
                  .map((d) => {'id': d.id, ...d.data()})
                  .cast<Map<String, dynamic>>()
                  .toList();
              final history =
                  allLoans
                      .where(
                        (l) =>
                            l['status'] == 'returned' || l['status'] == 'lost',
                      )
                      .toList()
                    ..sort((a, b) {
                      final ra =
                          a['returnedAt'] as Timestamp? ??
                          a['lentAt'] as Timestamp? ??
                          Timestamp.now();
                      final rb =
                          b['returnedAt'] as Timestamp? ??
                          b['lentAt'] as Timestamp? ??
                          Timestamp.now();
                      return rb.compareTo(ra);
                    });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoansSummaryCard(
                      clubId: widget.clubId,
                      allLoans: allLoans,
                    ),
                    const SizedBox(height: 24),
                    _ActiveLoansSection(
                      clubId: widget.clubId,
                      allLoans: allLoans,
                    ),
                    const SizedBox(height: 24),
                    _OverdueLoansSection(
                      clubId: widget.clubId,
                      allLoans: allLoans,
                    ),
                    const SizedBox(height: 24),
                    _UpcomingLoansSection(clubId: widget.clubId),
                    const SizedBox(height: 24),
                    _LoanRequestsSection(clubId: widget.clubId),
                    const SizedBox(height: 24),
                    const Text(
                      "Historique d'utilisation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "Aucun historique.",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ...history.take(30).map((l) => _LoanHistoryTile(data: l)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Widget récapitulatif en haut de l'onglet Prêt : objets en prêt, prêts en cours, à venir, retards, demandes.
class _LoansSummaryCard extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;

  const _LoansSummaryCard({required this.clubId, required this.allLoans});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      final lentAt = loan['lentAt'] as Timestamp?;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (lentAt == null || dueAt == null) return false;
      final lentDate = lentAt.toDate();
      final dueDate = dueAt.toDate();
      final lentDay = DateTime(lentDate.year, lentDate.month, lentDate.day);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return !lentDay.isAfter(today) && !dueDay.isBefore(today);
    }).toList();

    final overdueLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (dueAt == null) return false;
      final dueDate = dueAt.toDate();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return dueDay.isBefore(today);
    }).toList();

    String objectsInLoanText() {
      if (activeLoans.isEmpty) return 'Aucun prêt en cours';
      final parts = <String>[];
      for (final loan in activeLoans) {
        final name = loan['equipmentName'] as String? ?? 'Équipement';
        final qty = loan['quantity'] as int? ?? 1;
        parts.add('$name (x$qty)');
      }
      return '${activeLoans.length} prêt(s) en cours : ${parts.join(', ')}';
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .snapshots(),
      builder: (context, requestsSnap) {
        int pendingCount = 0;
        int upcomingCount = 0;
        if (requestsSnap.hasData) {
          final docs = requestsSnap.data?.docs ?? [];
          for (final doc in docs) {
            final data = doc.data();
            final status = data['status'] as String? ?? '';
            if (status == 'pending') {
              pendingCount++;
            } else if (status == 'accepted') {
              final requestedPickupDate =
                  data['requestedPickupDate'] as Timestamp?;
              if (requestedPickupDate != null) {
                final pickupDate = requestedPickupDate.toDate();
                final pickupDay = DateTime(
                  pickupDate.year,
                  pickupDate.month,
                  pickupDate.day,
                );
                if (pickupDay.isAfter(today)) upcomingCount++;
              }
            }
          }
        }

        return Card(
          color: ViroColors.primary.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize, color: ViroColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      "Résumé",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _summaryRow("Objets en prêt", objectsInLoanText(), null),
                const SizedBox(height: 6),
                _summaryRow(
                  "Prêts en cours",
                  "${activeLoans.length}",
                  ViroColors.success,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Prêts à venir",
                  "$upcomingCount",
                  ViroColors.primary,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Retard en cours",
                  "${overdueLoans.length}",
                  overdueLoans.isEmpty ? null : ViroColors.error,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Demandes de prêt",
                  "$pendingCount",
                  pendingCount > 0 ? ViroColors.warning : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }
}

/// Section de gestion du catalogue de prêts
class _LoanCatalogSection extends StatelessWidget {
  final String clubId;

  const _LoanCatalogSection({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .snapshots(),
      builder: (context, catalogSnap) {
        final catalogItems = catalogSnap.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPaymentMethodsDialog(context),
                    icon: const Icon(Icons.payment, size: 15),
                    label: Text(
                      "Moyens de paiement",
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLoanAllowedDaysDialog(context),
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text(
                      "Jours récup./retour",
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: ViroColors.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2, color: ViroColors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              "Catalogue de prêts",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showManageCatalogDialog(context),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text("Gérer"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (catalogItems.isEmpty)
                      Text(
                        "Aucun équipement dans le catalogue. Cliquez sur 'Gérer' pour ajouter des équipements.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      )
                    else
                      ...catalogItems.map((doc) {
                        final data = doc.data();
                        final equipmentId = doc.id;
                        return _CatalogItemCard(
                          clubId: clubId,
                          equipmentId: equipmentId,
                          data: data,
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showManageCatalogDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ManageCatalogDialog(clubId: clubId),
    );
  }

  void _showPaymentMethodsDialog(BuildContext context) {
    FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .get()
        .then((docSnap) {
          final current =
              docSnap.data()?['paymentMethods'] as List<dynamic>? ?? [];
          final selectedMethods = Set<String>.from(
            current.map((e) => e.toString()),
          );
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text("Moyens de paiement acceptés"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sélectionnez les moyens de paiement acceptés pour les prêts :",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text("Carte bancaire"),
                        value: selectedMethods.contains('carte'),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedMethods.add('carte');
                            } else {
                              selectedMethods.remove('carte');
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("Chèque"),
                        value: selectedMethods.contains('cheque'),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedMethods.add('cheque');
                            } else {
                              selectedMethods.remove('cheque');
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("Espèces"),
                        value: selectedMethods.contains('especes'),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedMethods.add('especes');
                            } else {
                              selectedMethods.remove('especes');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Annuler"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection(FirebaseCollections.clubs)
                            .doc(clubId)
                            .update({
                              'paymentMethods': selectedMethods.toList(),
                            });
                        if (context.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Moyens de paiement mis à jour avec succès !",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur : $e")),
                          );
                        }
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

  void _showLoanAllowedDaysDialog(BuildContext context) {
    FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .get()
        .then((docSnap) {
          final data = docSnap.data() ?? {};
          final clubAddress = data['address'] as String? ?? '';
          final current = data['loanAllowedWeekdays'] as List<dynamic>? ?? [];
          final loanScheduleRaw =
              data['loanSchedule'] as Map<String, dynamic>? ?? {};
          final selectedDays = Set<int>.from(
            current
                .map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0)
                .where((e) => e >= 1 && e <= 7),
          );
          if (selectedDays.isEmpty && current.isEmpty) {
            for (int i = 1; i <= 7; i++) {
              selectedDays.add(i);
            }
          }
          // Par jour : startHour, startMinute, endHour, endMinute, place (défaut 8h-20h, adresse club)
          final Map<
            int,
            ({
              int startHour,
              int startMinute,
              int endHour,
              int endMinute,
              String place,
            })
          >
          schedule = {};
          for (int d = 1; d <= 7; d++) {
            final key = d.toString();
            final raw = loanScheduleRaw[key] as Map<String, dynamic>?;
            if (raw != null) {
              schedule[d] = (
                startHour: raw['startHour'] as int? ?? 8,
                startMinute: raw['startMinute'] as int? ?? 0,
                endHour: raw['endHour'] as int? ?? 20,
                endMinute: raw['endMinute'] as int? ?? 0,
                place: raw['place'] as String? ?? clubAddress,
              );
            } else {
              schedule[d] = (
                startHour: 8,
                startMinute: 0,
                endHour: 20,
                endMinute: 0,
                place: clubAddress,
              );
            }
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Jours de récupération/retour mis à jour avec succès !",
                      ),
                    ),
                  );
                }
              },
            ),
          );
        });
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
}

/// Dialog pour configurer les jours, horaires et lieux de récup./retour
class _LoanAllowedDaysDialog extends StatefulWidget {
  final String clubId;
  final Set<int> selectedDays;
  final Map<
    int,
    ({int startHour, int startMinute, int endHour, int endMinute, String place})
  >
  schedule;
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

  static const _weekdays = [
    (1, 'Lundi'),
    (2, 'Mardi'),
    (3, 'Mercredi'),
    (4, 'Jeudi'),
    (5, 'Vendredi'),
    (6, 'Samedi'),
    (7, 'Dimanche'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDays = Set<int>.from(widget.selectedDays);
    _schedule = {};
    for (int d = 1; d <= 7; d++) {
      final s = widget.schedule[d]!;
      _schedule[d] = _DaySchedule(
        startHour: s.startHour,
        startMinute: s.startMinute,
        endHour: s.endHour,
        endMinute: s.endMinute,
        place: s.place,
      );
      _placeControllers[d] = TextEditingController(text: s.place);
    }
  }

  @override
  void dispose() {
    for (final c in _placeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final d in _selectedDays) {
        final s = _schedule[d]!;
        final placeText = _placeControllers[d]?.text.trim() ?? s.place;
        scheduleMap[d.toString()] = {
          'startHour': s.startHour,
          'startMinute': s.startMinute,
          'endHour': s.endHour,
          'endMinute': s.endMinute,
          'place': placeText.isEmpty ? widget.defaultPlace : placeText,
        };
      }
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .update({
            'loanAllowedWeekdays': _selectedDays.toList()..sort(),
            'loanSchedule': scheduleMap,
          });
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Jours pour récupérer ou rendre le prêt"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sélectionnez les jours et définissez les horaires et le lieu (par défaut 8h-20h, adresse du club).",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ..._weekdays.map((e) {
              final dayNum = e.$1;
              final label = e.$2;
              final isSelected = _selectedDays.contains(dayNum);
              final s = _schedule[dayNum]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: Text(label),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedDays.add(dayNum);
                        } else {
                          _selectedDays.remove(dayNum);
                        }
                      });
                    },
                  ),
                  if (isSelected) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("De ", style: TextStyle(fontSize: 13)),
                              _hourDropdown(
                                value: s.startHour,
                                onChanged: (v) =>
                                    setState(() => s.startHour = v ?? 8),
                              ),
                              const Text(" h ", style: TextStyle(fontSize: 13)),
                              _minuteDropdown(
                                value: s.startMinute,
                                onChanged: (v) =>
                                    setState(() => s.startMinute = v ?? 0),
                              ),
                              const Text(" à ", style: TextStyle(fontSize: 13)),
                              _hourDropdown(
                                value: s.endHour,
                                onChanged: (v) =>
                                    setState(() => s.endHour = v ?? 20),
                              ),
                              const Text(" h ", style: TextStyle(fontSize: 13)),
                              _minuteDropdown(
                                value: s.endMinute,
                                onChanged: (v) =>
                                    setState(() => s.endMinute = v ?? 0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            decoration: InputDecoration(
                              labelText: "Lieu",
                              hintText: widget.defaultPlace.isEmpty
                                  ? "Lieu de récup./retour"
                                  : "Par défaut : adresse du club",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            controller: _placeControllers[dayNum],
                            onChanged: (v) => s.place = v,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("Enregistrer")),
      ],
    );
  }

  Widget _hourDropdown({
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButton<int>(
      value: value.clamp(0, 23),
      isDense: true,
      items: List.generate(
        24,
        (i) => DropdownMenuItem(value: i, child: Text('$i')),
      ),
      onChanged: onChanged,
    );
  }

  Widget _minuteDropdown({
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    const minutes = [0, 15, 30, 45];
    final v = minutes.contains(value) ? value : 0;
    return DropdownButton<int>(
      value: v,
      isDense: true,
      items: minutes
          .map(
            (m) => DropdownMenuItem(
              value: m,
              child: Text(m.toString().padLeft(2, '0')),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
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
      stream: FirebaseFirestore.instance
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
        final quantityTotal =
            equipmentData['quantityTotal'] as int? ??
            equipmentData['quantity'] as int? ??
            0;

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
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max: $maxQuantity unité(s)'),
                if (price != null)
                  Text(
                    'Prix: ${price.toStringAsFixed(2)} €/${priceUnitLabel(priceUnit)}',
                  ),
                if (maxLoanDuration != null)
                  Text(
                    'Durée max: ${formatMaxLoanDuration(maxLoanDuration, priceUnit)}',
                  ),
                Text(
                  'Stock: $quantityTotal',
                  style: TextStyle(
                    color: quantityTotal > 0
                        ? ViroColors.success
                        : ViroColors.error,
                    fontWeight: FontWeight.w500,
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
      await FirebaseFirestore.instance
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
                  const Text(
                    "Gérer le catalogue de prêts",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  stream: FirebaseFirestore.instance
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
                      stream: FirebaseFirestore.instance
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
                            final quantityTotal =
                                data['quantityTotal'] as int? ??
                                data['quantity'] as int? ??
                                0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  'Stock: $quantityTotal',
                                  style: TextStyle(
                                    color: quantityTotal > 0
                                        ? ViroColors.success
                                        : Colors.grey,
                                  ),
                                ),
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
    final catalogDoc = await FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.equipmentCatalog)
        .doc(equipmentId)
        .get();

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
    final initialPrice = catalogPrice ?? equipmentLoanPrice;
    _priceController = TextEditingController(
      text: initialPrice?.toString() ?? '',
    );
    _priceUnit = widget.existingCatalogData?['priceUnit'] as String? ?? 'jour';
    final maxLoanDurationDays =
        widget.existingCatalogData?['maxLoanDurationDays'] as int?;
    String? initialDurationText;
    if (maxLoanDurationDays != null) {
      switch (_priceUnit) {
        case 'jour':
          initialDurationText = maxLoanDurationDays.toString();
          break;
        case 'semaine':
          initialDurationText = (maxLoanDurationDays / 7).round().toString();
          break;
        case 'mois':
          initialDurationText = (maxLoanDurationDays / 30).round().toString();
          break;
      }
    }
    _maxLoanDurationController = TextEditingController(
      text: initialDurationText ?? '',
    );
  }

  int? _convertDurationToDays(int? value) {
    if (value == null) return null;
    switch (_priceUnit) {
      case 'jour':
        return value;
      case 'semaine':
        return value * 7;
      case 'mois':
        return value * 30;
      default:
        return value;
    }
  }

  String _getDurationUnitLabel() {
    switch (_priceUnit) {
      case 'jour':
        return 'jours';
      case 'semaine':
        return 'semaines';
      case 'mois':
        return 'mois';
      default:
        return 'jours';
    }
  }

  @override
  void dispose() {
    _maxQuantityController.dispose();
    _priceController.dispose();
    _maxLoanDurationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final maxQty = int.tryParse(_maxQuantityController.text.trim());
    final price = _priceController.text.trim().isEmpty
        ? null
        : double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    final maxLoanDurationValue = _maxLoanDurationController.text.trim().isEmpty
        ? null
        : int.tryParse(_maxLoanDurationController.text.trim());
    final maxLoanDurationDays = _convertDurationToDays(maxLoanDurationValue);

    if (maxQty == null || maxQty < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le nombre maximum doit être au moins 1."),
          ),
        );
      }
      return;
    }

    if (maxLoanDurationValue != null && maxLoanDurationValue < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "La durée de prêt maximum doit être au moins 1 ${_getDurationUnitLabel().replaceAll('s', '')}.",
            ),
          ),
        );
      }
      return;
    }

    final quantityTotal =
        widget.equipmentData['quantityTotal'] as int? ??
        widget.equipmentData['quantity'] as int? ??
        0;

    if (maxQty > quantityTotal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Le nombre maximum ne peut pas dépasser $quantityTotal disponible(s).",
            ),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .doc(widget.equipmentId)
          .set({
            'equipmentId': widget.equipmentId,
            'maxQuantity': maxQty,
            'price': price,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantityTotal =
        widget.equipmentData['quantityTotal'] as int? ??
        widget.equipmentData['quantity'] as int? ??
        0;

    return AlertDialog(
      title: Text(
        widget.existingCatalogData == null
            ? "Ajouter au catalogue"
            : "Modifier le catalogue",
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.equipmentData['name'] as String? ?? 'Équipement',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxQuantityController,
              keyboardType: TextInputType.number,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: "Nombre maximum de prêt",
                hintText: "ex. 5",
                helperText: "Maximum: $quantityTotal disponible(s)",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: "Prix du prêt à l'unité (€)",
                hintText: "ex. 2.50",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priceUnit,
              decoration: const InputDecoration(
                labelText: "Unité de temps",
                helperText: "Prix par jour, semaine ou mois",
              ),
              items: const [
                DropdownMenuItem(value: 'jour', child: Text('Par jour')),
                DropdownMenuItem(value: 'semaine', child: Text('Par semaine')),
                DropdownMenuItem(value: 'mois', child: Text('Par mois')),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null && v != _priceUnit) {
                        final currentValue = int.tryParse(
                          _maxLoanDurationController.text.trim(),
                        );
                        if (currentValue != null) {
                          int? days;
                          switch (_priceUnit) {
                            case 'jour':
                              days = currentValue;
                              break;
                            case 'semaine':
                              days = currentValue * 7;
                              break;
                            case 'mois':
                              days = currentValue * 30;
                              break;
                          }
                          if (days != null) {
                            int? newValue;
                            switch (v) {
                              case 'jour':
                                newValue = days;
                                break;
                              case 'semaine':
                                newValue = (days / 7).round();
                                break;
                              case 'mois':
                                newValue = (days / 30).round();
                                break;
                            }
                            if (newValue != null && newValue > 0) {
                              _maxLoanDurationController.text = newValue
                                  .toString();
                            } else {
                              _maxLoanDurationController.clear();
                            }
                          }
                        }
                        setState(() => _priceUnit = v);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxLoanDurationController,
              keyboardType: TextInputType.number,
              enabled: !_saving,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: "Durée de prêt maximum (${_getDurationUnitLabel()})",
                hintText:
                    "ex. ${_priceUnit == 'jour'
                        ? '7'
                        : _priceUnit == 'semaine'
                        ? '2'
                        : '1'} (optionnel)",
              ),
            ),
          ],
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.existingCatalogData == null ? "Ajouter" : "Modifier",
                ),
        ),
      ],
    );
  }
}

/// Tuile read-only pour l'historique des prêts (retournés / perdus).
class _LoanHistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LoanHistoryTile({required this.data});

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
    final isLost = status == 'lost';
    final penalty = data['penaltyAmount'] as num?;
    final penaltyPaid = data['penaltyPaid'] as bool? ?? false;

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
              'Du $lentStr → ${isLost ? "Perdu" : "Retour $returnedStr"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (loanUnitPrice != null)
              Text(
                'Prix: ${loanUnitPrice.toStringAsFixed(2)} €/unité${quantity > 1 ? ' (Total: ${(loanUnitPrice * quantity).toStringAsFixed(2)} €)' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            if (isLost && penalty != null && penalty > 0)
              Text(
                'Pénalité ${penalty.toStringAsFixed(0)} €${penaltyPaid ? " (réglée)" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: penaltyPaid ? ViroColors.success : ViroColors.error,
                ),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            isLost ? "Perdu" : "Retourné",
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: isLost
              ? ViroColors.error.withOpacity(0.15)
              : ViroColors.success.withOpacity(0.15),
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
      stream: FirebaseFirestore.instance
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
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Erreur : ${snapshot.error}",
                style: const TextStyle(color: ViroColors.error),
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
          color: ViroColors.warning.withOpacity(0.1),
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

/// Section des prêts en retard (dueAt < aujourd'hui)
class _OverdueLoansSection extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;

  const _OverdueLoansSection({required this.clubId, required this.allLoans});

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
      color: ViroColors.error.withOpacity(0.1),
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
                      color: ViroColors.error.withOpacity(0.5),
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Joueur: $borrowerName",
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
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

/// Section des prêts en cours (lentAt <= aujourd'hui <= dueAt)
class _ActiveLoansSection extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;

  const _ActiveLoansSection({required this.clubId, required this.allLoans});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
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
      color: ViroColors.success.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: ViroColors.success),
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
                    backgroundColor: ViroColors.success,
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
                final dueAt = loan['dueAt'] as Timestamp?;
                final lentAt = loan['lentAt'] as Timestamp?;

                final dueDate = dueAt?.toDate();
                final isDueToday =
                    dueDate != null &&
                    DateTime(dueDate.year, dueDate.month, dueDate.day) == today;

                return Padding(
                  key: ValueKey(loan['id']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDueToday
                            ? ViroColors.warning.withOpacity(0.5)
                            : ViroColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: ViroColors.success,
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
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Joueur: $borrowerName",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
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

  const _UpcomingLoansSection({required this.clubId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
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
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
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
                  final requestedPickupDate =
                      data['requestedPickupDate'] as Timestamp?;
                  final duration = data['duration'] as int? ?? 0;
                  final durationUnit =
                      data['durationUnit'] as String? ?? 'jour';

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
                          color: ViroColors.primary.withOpacity(0.3),
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
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Joueur: $borrowerName",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
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
                      Text(
                        "Demandé par $playerName",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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

      final requestDoc = await FirebaseFirestore.instance
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

      await FirebaseFirestore.instance
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
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
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
            content: Text("Demande acceptée et prêt créé avec succès !"),
            backgroundColor: ViroColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
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
      await FirebaseFirestore.instance
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
            content: Text("Erreur : $e"),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }
}
