import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/equipment_helpers.dart';
import '../../utils/firebase_helpers.dart';

class AdminEquipmentPage extends StatefulWidget {
  final String clubId;
  final String? sport;

  const AdminEquipmentPage({
    super.key,
    required this.clubId,
    this.sport,
  });

  @override
  State<AdminEquipmentPage> createState() => _AdminEquipmentPageState();
}

class _AdminEquipmentPageState extends State<AdminEquipmentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Matériel & équipement"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Inventaire"),
            Tab(text: "Prêts"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InventoryTab(clubId: widget.clubId, sport: widget.sport),
          _LoansTab(clubId: widget.clubId),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddEquipmentDialog(context),
              backgroundColor: ViroColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddEquipmentDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddEquipmentDialog(
        clubId: widget.clubId,
        sport: widget.sport,
        onAdded: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Équipement ajouté.")),
            );
          }
        },
      ),
    );
  }
}

/// Onglet Inventaire : liste matériel, alertes maintenance, FAB ajout.
class _InventoryTab extends StatelessWidget {
  final String clubId;
  final String? sport;

  const _InventoryTab({required this.clubId, this.sport});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipment)
          .orderBy('createdAt', descending: true)
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
        final equipment = docs
            .map((d) => {'id': d.id, ...d.data()})
            .cast<Map<String, dynamic>>()
            .toList();

        final now = DateTime.now();
        final inSevenDays = now.add(const Duration(days: 7));
        final maintenanceAlerts = equipment.where((e) {
          final next = e['nextMaintenance'] as Timestamp?;
          if (next == null) return false;
          final d = next.toDate();
          return d.isBefore(now) || (d.isAfter(now) && d.isBefore(inSevenDays));
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (maintenanceAlerts.isNotEmpty) ...[
                _MaintenanceAlertsSection(items: maintenanceAlerts),
                const SizedBox(height: 20),
              ],
              const Text(
                "Inventaire",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              if (equipment.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        "Aucun équipement. Utilisez le bouton + pour en ajouter.",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              else
                ...equipment.map((e) => _EquipmentCard(
                      clubId: clubId,
                      data: e,
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _MaintenanceAlertsSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _MaintenanceAlertsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ViroColors.warning.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ViroColors.warning),
                const SizedBox(width: 8),
                const Text(
                  "Alertes maintenance",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.take(5).map((e) {
              final next = e['nextMaintenance'] as Timestamp?;
              final dateStr = next != null
                  ? DateFormat('d MMM yyyy', 'fr_FR').format(next.toDate())
                  : '—';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e['name'] ?? 'Sans nom'} — $dateStr',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "+ ${items.length - 5} autre(s)",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> data;

  const _EquipmentCard({required this.clubId, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Sans nom';
    final category = data['category'] as String? ?? '';
    final quantity = data['quantity'] as int? ?? 0;
    final unit = data['unit'] as String? ?? EquipmentHelpers.unitPiece;
    final condition = data['condition'] as String? ?? EquipmentHelpers.conditionBon;
    final availability =
        data['availability'] as String? ?? EquipmentHelpers.availabilityDisponible;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.isNotEmpty) Text('$category • $quantity ${EquipmentHelpers.unitLabel(unit)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _chip(EquipmentHelpers.conditionLabel(condition), condition == EquipmentHelpers.conditionBon ? ViroColors.success : ViroColors.warning),
                const SizedBox(width: 6),
                _chip(EquipmentHelpers.availabilityLabel(availability), availability == EquipmentHelpers.availabilityDisponible ? ViroColors.success : Colors.grey),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showEditEquipmentSheet(context),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  void _showEditEquipmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditEquipmentSheet(clubId: clubId, data: data),
    );
  }
}

/// Formulaire d'ajout avec suggestions par sport.
class _AddEquipmentDialog extends StatefulWidget {
  final String clubId;
  final String? sport;
  final VoidCallback onAdded;

  const _AddEquipmentDialog({
    required this.clubId,
    required this.sport,
    required this.onAdded,
  });

  @override
  State<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<_AddEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  String _unit = EquipmentHelpers.unitPiece;
  String _condition = EquipmentHelpers.conditionBon;
  String _availability = EquipmentHelpers.availabilityDisponible;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applySuggestion(Map<String, dynamic> s) {
    _nameController.text = s['name'] as String? ?? '';
    _categoryController.text = s['category'] as String? ?? '';
    _unit = s['unit'] as String? ?? EquipmentHelpers.unitPiece;
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final qty = quantity < 1 ? 1 : quantity;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .add({
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'quantity': qty,
        'unit': _unit,
        'condition': _condition,
        'availability': _availability,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = EquipmentHelpers.getDefaultEquipmentBySport(widget.sport);
    final sportLabel = widget.sport?.isNotEmpty == true ? widget.sport! : "le club";

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Ajouter du matériel",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Suggestions pour $sportLabel",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      itemBuilder: (_, i) {
                        final s = suggestions[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _applySuggestion(s),
                            child: Chip(
                              label: Text(s['name'] as String? ?? ''),
                              avatar: const Icon(Icons.add, size: 18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Nom",
                      hintText: "ex. Maillots domicile",
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Requis" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: "Catégorie",
                      hintText: "ex. Maillots",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Quantité"),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return "Quantité ≥ 1";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: const InputDecoration(labelText: "Unité"),
                          items: EquipmentHelpers.units
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(EquipmentHelpers.unitLabel(u)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v ?? _unit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _condition,
                    decoration: const InputDecoration(labelText: "État"),
                    items: EquipmentHelpers.conditions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(EquipmentHelpers.conditionLabel(c)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _condition = v ?? _condition),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _availability,
                    decoration:
                        const InputDecoration(labelText: "Disponibilité"),
                    items: EquipmentHelpers.availabilities
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(EquipmentHelpers.availabilityLabel(a)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _availability = v ?? _availability),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: "Notes (optionnel)",
                      hintText: "…",
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text("Annuler"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Ajouter"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet pour modifier état / disponibilité d'un équipement.
class _EditEquipmentSheet extends StatefulWidget {
  final String clubId;
  final Map<String, dynamic> data;

  const _EditEquipmentSheet({required this.clubId, required this.data});

  @override
  State<_EditEquipmentSheet> createState() => _EditEquipmentSheetState();
}

class _EditEquipmentSheetState extends State<_EditEquipmentSheet> {
  late String _condition;
  late String _availability;
  late TextEditingController _notesController;
  DateTime? _lastMaintenance;
  DateTime? _nextMaintenance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _condition = widget.data['condition'] as String? ?? EquipmentHelpers.conditionBon;
    _availability = widget.data['availability'] as String? ?? EquipmentHelpers.availabilityDisponible;
    _notesController = TextEditingController(
      text: widget.data['notes'] as String? ?? '',
    );
    final last = widget.data['lastMaintenance'] as Timestamp?;
    final next = widget.data['nextMaintenance'] as Timestamp?;
    _lastMaintenance = last?.toDate();
    _nextMaintenance = next?.toDate();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .doc(widget.data['id'] as String)
          .update({
        'condition': _condition,
        'availability': _availability,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'lastMaintenance': _lastMaintenance != null
            ? Timestamp.fromDate(_lastMaintenance!)
            : null,
        'nextMaintenance': _nextMaintenance != null
            ? Timestamp.fromDate(_nextMaintenance!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Équipement mis à jour.")),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.data['name'] as String? ?? 'Équipement',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _condition,
            decoration: const InputDecoration(labelText: "État"),
            items: EquipmentHelpers.conditions
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(EquipmentHelpers.conditionLabel(c)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _condition = v ?? _condition),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _availability,
            decoration: const InputDecoration(labelText: "Disponibilité"),
            items: EquipmentHelpers.availabilities
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(EquipmentHelpers.availabilityLabel(a)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _availability = v ?? _availability),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: "Notes"),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text("Dernière maintenance"),
            subtitle: Text(_lastMaintenance != null
                ? DateFormat('d MMM yyyy', 'fr_FR').format(_lastMaintenance!)
                : "Non renseignée"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _lastMaintenance ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _lastMaintenance = d);
              },
            ),
          ),
          ListTile(
            title: const Text("Prochaine maintenance"),
            subtitle: Text(_nextMaintenance != null
                ? DateFormat('d MMM yyyy', 'fr_FR').format(_nextMaintenance!)
                : "Non renseignée"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _nextMaintenance ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _nextMaintenance = d);
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Enregistrer"),
          ),
          if (_availability == EquipmentHelpers.availabilityDisponible) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : _delete,
              child: Text(
                "Supprimer",
                style: TextStyle(color: ViroColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (_availability != EquipmentHelpers.availabilityDisponible) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer l'équipement ?"),
        content: const Text(
          "Cette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ViroColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .doc(widget.data['id'] as String)
          .delete();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Équipement supprimé.")),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Onglet Prêts : liste active, retours, perte / pénalité, création prêt.
class _LoansTab extends StatelessWidget {
  final String clubId;

  const _LoansTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
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
        final active = allLoans
            .where((l) => l['status'] == 'active')
            .toList()
          ..sort((a, b) {
            final ta = a['lentAt'] as Timestamp? ?? Timestamp.now();
            final tb = b['lentAt'] as Timestamp? ?? Timestamp.now();
            return tb.compareTo(ta);
          });
        final history = allLoans
            .where((l) =>
                l['status'] == 'returned' || l['status'] == 'lost')
            .toList()
          ..sort((a, b) {
            final ra = a['returnedAt'] as Timestamp? ?? a['lentAt'] as Timestamp? ?? Timestamp.now();
            final rb = b['returnedAt'] as Timestamp? ?? b['lentAt'] as Timestamp? ?? Timestamp.now();
            return rb.compareTo(ra);
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Prêts en cours",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showCreateLoanDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Prêter"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (active.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            "Aucun prêt en cours.",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showCreateLoanDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Créer un prêt"),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...active.map((l) => _LoanCard(
                      clubId: clubId,
                      data: l,
                    )),
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
    );
  }

  void _showCreateLoanDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateLoanDialog(
        clubId: clubId,
        onCreated: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Prêt enregistré.")),
            );
          }
        },
      ),
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
            Text('Du $lentStr → ${isLost ? "Perdu" : "Retour $returnedStr"}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

class _LoanCard extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> data;

  const _LoanCard({required this.clubId, required this.data});

  @override
  Widget build(BuildContext context) {
    final borrowerName = data['borrowerName'] as String? ?? 'Inconnu';
    final equipmentName = data['equipmentName'] as String? ?? '—';
    final quantity = data['quantity'] as int? ?? 1;
    final lentAt = data['lentAt'] as Timestamp?;
    final dueAt = data['dueAt'] as Timestamp?;
    final lentStr = lentAt != null
        ? DateFormat('d MMM', 'fr_FR').format(lentAt.toDate())
        : '—';
    final dueStr =
        dueAt != null ? DateFormat('d MMM', 'fr_FR').format(dueAt.toDate()) : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    equipmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text("$quantity prêté(s)", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 4),
            Text("Emprunté par $borrowerName"),
            Text("Du $lentStr → retour prévu $dueStr",
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _markReturned(context),
                  child: const Text("Retour"),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _markLost(context),
                  child: Text(
                    "Marquer perdu",
                    style: TextStyle(color: ViroColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markReturned(BuildContext context) async {
    try {
      final equipmentId = data['equipmentId'] as String?;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final loanRef = FirebaseFirestore.instance
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.equipmentLoans)
            .doc(data['id'] as String);
        tx.update(loanRef, {
          'status': 'returned',
          'returnedAt': FieldValue.serverTimestamp(),
        });
        if (equipmentId != null) {
          final eqRef = FirebaseFirestore.instance
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .collection(FirebaseCollections.equipment)
              .doc(equipmentId);
          final eqSnap = await tx.get(eqRef);
          if (eqSnap.exists) {
            tx.update(eqRef, {
              'availability': EquipmentHelpers.availabilityDisponible,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Retour enregistré.")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  Future<void> _markLost(BuildContext context) async {
    final penaltyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Marquer comme perdu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pénalité (optionnel, en €) :"),
            const SizedBox(height: 8),
            TextField(
              controller: penaltyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "0",
                suffixText: "€",
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
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
    if (result != true) return;

    final penalty = double.tryParse(penaltyController.text.trim()) ?? 0.0;
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .doc(data['id'] as String)
          .update({
        'status': 'lost',
        'penaltyAmount': penalty > 0 ? penalty : null,
        'penaltyPaid': false,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prêt marqué comme perdu.")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }
}

/// Dialog pour créer un prêt : équipement, emprunteur, quantité, date de retour.
class _CreateLoanDialog extends StatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CreateLoanDialog({
    required this.clubId,
    required this.onCreated,
  });

  @override
  State<_CreateLoanDialog> createState() => _CreateLoanDialogState();
}

class _CreateLoanDialogState extends State<_CreateLoanDialog> {
  String? _selectedEquipmentId;
  String? _selectedBorrowerId;
  String _selectedBorrowerName = '';
  final _quantityController = TextEditingController(text: '1');
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEquipmentId == null || _selectedBorrowerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez un équipement et un emprunteur.")),
      );
      return;
    }
    final qty = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantité invalide.")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final eqSnap = await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .doc(_selectedEquipmentId)
          .get();
      if (!eqSnap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Équipement introuvable.")),
        );
        setState(() => _saving = false);
        return;
      }
      final eq = eqSnap.data()!;
      final equipmentName = eq['name'] as String? ?? '—';

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final loanRef = FirebaseFirestore.instance
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.equipmentLoans)
            .doc();
        tx.set(loanRef, {
          'equipmentId': _selectedEquipmentId,
          'equipmentName': equipmentName,
          'quantity': qty,
          'borrowerId': _selectedBorrowerId,
          'borrowerName': _selectedBorrowerName,
          'lentAt': FieldValue.serverTimestamp(),
          'dueAt': Timestamp.fromDate(_dueDate),
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        final eqRef = FirebaseFirestore.instance
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.equipment)
            .doc(_selectedEquipmentId);
        tx.update(eqRef, {
          'availability': EquipmentHelpers.availabilityPrete,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Nouveau prêt",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirebaseCollections.clubs)
                      .doc(widget.clubId)
                      .collection(FirebaseCollections.equipment)
                      .where('availability', isEqualTo: EquipmentHelpers.availabilityDisponible)
                      .snapshots(),
                  builder: (context, eqSnap) {
                    final eqDocs = eqSnap.data?.docs ?? [];
                    final items = eqDocs.map((d) {
                      final data = d.data();
                      return {
                        'id': d.id,
                        'name': data['name'] as String? ?? '—',
                        'quantity': data['quantity'] as int? ?? 1,
                        'unit': data['unit'] as String? ?? EquipmentHelpers.unitPiece,
                      };
                    }).toList();
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Aucun équipement disponible.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedEquipmentId,
                      decoration: const InputDecoration(labelText: "Équipement"),
                      items: items
                          .map((e) => DropdownMenuItem(
                                value: e['id'] as String,
                                child: Text(
                                  '${e['name']} (${e['quantity']} ${EquipmentHelpers.unitLabel(e['unit'] as String)})',
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedEquipmentId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, userSnap) {
                    final allDocs = userSnap.data?.docs ?? [];
                    final clubMembers = filterUsersByClub(allDocs, widget.clubId);
                    final members = clubMembers.map((d) {
                      final data = d.data() ?? {};
                      final first = (data['firstName'] as String? ?? '').trim();
                      final last = (data['lastName'] as String? ?? '').trim().toUpperCase();
                      final name = [first, last].where((e) => e.isNotEmpty).join(' ');
                      return {
                        'userId': d.id,
                        'name': name.isEmpty ? 'Membre' : name,
                      };
                    }).toList();
                    if (members.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Aucun membre dans le club.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedBorrowerId,
                      decoration: const InputDecoration(labelText: "Emprunteur"),
                      items: members
                          .map((m) => DropdownMenuItem(
                                value: m['userId'] as String,
                                child: Text(m['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final m = members.firstWhere((x) => x['userId'] == v);
                        setState(() {
                          _selectedBorrowerId = v;
                          _selectedBorrowerName = m['name'] as String;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Quantité"),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text("Retour prévu le"),
                  subtitle: Text(
                    DateFormat('d MMM yyyy', 'fr_FR').format(_dueDate),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text("Annuler"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Enregistrer"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
