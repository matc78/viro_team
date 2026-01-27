import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/equipment_helpers.dart';
import '../../utils/firebase_helpers.dart';

class AdminEquipmentPage extends StatefulWidget {
  final String clubId;
  final String? sport;

  const AdminEquipmentPage({super.key, required this.clubId, this.sport});

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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Équipement ajouté.")));
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

        // Calculer le prix total de l'équipement du club
        double totalPrice = 0.0;
        for (final e in equipment) {
          final unitPrice = e['unitPrice'] as num?;
          final quantityTotal =
              e['quantityTotal'] as int? ?? e['quantity'] as int? ?? 0;
          if (unitPrice != null && quantityTotal > 0) {
            totalPrice += unitPrice * quantityTotal;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (totalPrice > 0)
                Card(
                  color: ViroColors.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Valeur totale de l'inventaire",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${totalPrice.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ViroColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (totalPrice > 0) const SizedBox(height: 16),
              if (maintenanceAlerts.isNotEmpty) ...[
                _MaintenanceAlertsSection(items: maintenanceAlerts),
                const SizedBox(height: 20),
              ],
              const Text(
                "Inventaire",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                ...equipment.map(
                  (e) => _EquipmentCard(clubId: clubId, data: e),
                ),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    final brand = data['brand'] as String?;
    final model = data['model'] as String?;
    final quantityTotal =
        data['quantityTotal'] as int? ?? data['quantity'] as int? ?? 0;
    final unitPrice = data['unitPrice'] as num?;
    final loanUnitPrice = data['loanUnitPrice'] as num?;
    final condition =
        data['condition'] as String? ?? EquipmentHelpers.conditionBon;
    final availability =
        data['availability'] as String? ??
        EquipmentHelpers.availabilityDisponible;
    final location = data['location'] as String?;
    final responsibleName = data['responsibleUserName'] as String?;
    final assignedTeamName = data['assignedTeamName'] as String?;
    final purchaseDate = data['purchaseDate'] as Timestamp?;
    final lastMaintenance = data['lastMaintenance'] as Timestamp?;
    final nextMaintenance = data['nextMaintenance'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditEquipmentSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (brand != null || model != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (brand != null) brand,
                              if (model != null) model,
                            ].join(' '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditEquipmentSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (category.isNotEmpty)
                Text(
                  EquipmentHelpers.categoryLabel(category),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock: $quantityTotal${unitPrice != null ? ' • Achat: ${unitPrice.toStringAsFixed(2)} €' : ''}${loanUnitPrice != null ? ' • Prêt: ${loanUnitPrice.toStringAsFixed(2)} €' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (responsibleName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                responsibleName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (assignedTeamName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.group,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                assignedTeamName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (purchaseDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Achat: ${DateFormat('d MMM yyyy', 'fr_FR').format(purchaseDate.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (lastMaintenance != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.build,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Dernière maintenance: ${DateFormat('d MMM yyyy', 'fr_FR').format(lastMaintenance.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (nextMaintenance != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Prochaine maintenance: ${DateFormat('d MMM yyyy', 'fr_FR').format(nextMaintenance.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    EquipmentHelpers.conditionLabel(condition),
                    condition == EquipmentHelpers.conditionBon ||
                            condition == EquipmentHelpers.conditionNeuf
                        ? ViroColors.success
                        : ViroColors.warning,
                  ),
                  _chip(
                    EquipmentHelpers.availabilityLabel(availability),
                    availability == EquipmentHelpers.availabilityDisponible
                        ? ViroColors.success
                        : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
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
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _quantityTotalController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  final _invoiceReferenceController = TextEditingController();
  final _estimatedLifespanController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _loanUnitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = EquipmentHelpers.categoryEntrainement;
  String _condition = EquipmentHelpers.conditionBon;
  String _availability = EquipmentHelpers.availabilityDisponible;
  DateTime? _purchaseDate;
  String? _responsibleUserId;
  String? _responsibleUserName;
  String? _assignedTeamId;
  String? _assignedTeamName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _quantityTotalController.dispose();
    _locationController.dispose();
    _invoiceReferenceController.dispose();
    _estimatedLifespanController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applySuggestion(Map<String, dynamic> s) {
    _nameController.text = s['name'] as String? ?? '';
    // Les suggestions utilisent l'ancien format de catégorie, on garde juste le nom
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final quantityTotal =
        int.tryParse(_quantityTotalController.text.trim()) ?? 1;
    final qtyTotal = quantityTotal < 1 ? 1 : quantityTotal;
    final estimatedLifespan = _estimatedLifespanController.text.trim().isEmpty
        ? null
        : int.tryParse(_estimatedLifespanController.text.trim());
    final unitPrice = _unitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(
            _unitPriceController.text.trim().replaceAll(',', '.'),
          );
    final loanUnitPrice = _loanUnitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(
            _loanUnitPriceController.text.trim().replaceAll(',', '.'),
          );

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .add({
            'name': _nameController.text.trim(),
            'category': _category,
            'brand': _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            'model': _modelController.text.trim().isEmpty
                ? null
                : _modelController.text.trim(),
            'serialNumber': _serialNumberController.text.trim().isEmpty
                ? null
                : _serialNumberController.text.trim(),
            'quantityTotal': qtyTotal,
            'quantity': qtyTotal, // Garder pour compatibilité
            'unitPrice': unitPrice,
            'loanUnitPrice': loanUnitPrice,
            'condition': _condition,
            'availability': _availability,
            'location': _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            'purchaseDate': _purchaseDate != null
                ? Timestamp.fromDate(_purchaseDate!)
                : null,
            'invoiceReference': _invoiceReferenceController.text.trim().isEmpty
                ? null
                : _invoiceReferenceController.text.trim(),
            'estimatedLifespanMonths': estimatedLifespan,
            'responsibleUserId': _responsibleUserId,
            'responsibleUserName': _responsibleUserName,
            'assignedTeamId': _assignedTeamId,
            'assignedTeamName': _assignedTeamName,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = EquipmentHelpers.getDefaultEquipmentBySport(
      widget.sport,
    );
    final sportLabel = widget.sport?.isNotEmpty == true
        ? widget.sport!
        : "le club";

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  const Text(
                    "Identification",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Nom *",
                      hintText: "ex. Ballons de basket",
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Requis" : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: "Catégorie *"),
                    items: EquipmentHelpers.categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(EquipmentHelpers.categoryLabel(c)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: "Marque",
                      hintText: "ex. Nike, Adidas",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: "Modèle",
                      hintText: "ex. T90, Predator",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serialNumberController,
                    decoration: const InputDecoration(
                      labelText: "Numéro de série",
                      hintText: "ex. SN123456",
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Stock et Localisation",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityTotalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Stock total *",
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return "≥ 1";
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unitPriceController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Prix d'achat à l'unité (€)",
                      hintText: "ex. 15.99",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _loanUnitPriceController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Prix du prêt à l'unité (€)",
                      hintText: "ex. 2.50 (pour le catalogue)",
                      helperText:
                          "Prix affiché dans le catalogue pour les joueurs",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Localisation",
                      hintText: "ex. Placard A, Gymnase 1",
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "État et Disponibilité",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(labelText: "État"),
                    items: EquipmentHelpers.conditions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(EquipmentHelpers.conditionLabel(c)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _condition = v ?? _condition),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _availability,
                    decoration: const InputDecoration(
                      labelText: "Disponibilité",
                    ),
                    items: EquipmentHelpers.availabilities
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(EquipmentHelpers.availabilityLabel(a)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _availability = v ?? _availability),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Achat et Garantie",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Date d'achat"),
                    subtitle: Text(
                      _purchaseDate != null
                          ? DateFormat(
                              'd MMM yyyy',
                              'fr_FR',
                            ).format(_purchaseDate!)
                          : "Non renseignée",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _purchaseDate = d);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _invoiceReferenceController,
                    decoration: const InputDecoration(
                      labelText: "Référence facture",
                      hintText: "ex. FAC-2024-001 ou URL",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _estimatedLifespanController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Durée de vie estimée (mois)",
                      hintText: "ex. 24",
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Affectation",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, userSnap) {
                      final allDocs = userSnap.data?.docs ?? [];
                      final clubMembers = filterUsersByClub(
                        allDocs,
                        widget.clubId,
                      );
                      final members = clubMembers.map((d) {
                        final data = d.data() ?? {};
                        final first = (data['firstName'] as String? ?? '')
                            .trim();
                        final last = (data['lastName'] as String? ?? '')
                            .trim()
                            .toUpperCase();
                        final name = [
                          first,
                          last,
                        ].where((e) => e.isNotEmpty).join(' ');
                        return {
                          'userId': d.id,
                          'name': name.isEmpty ? 'Membre' : name,
                        };
                      }).toList();
                      return DropdownButtonFormField<String?>(
                        initialValue: _responsibleUserId,
                        decoration: const InputDecoration(
                          labelText: "Responsable",
                          hintText: "Sélectionner un responsable",
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Aucun"),
                          ),
                          ...members.map(
                            (m) => DropdownMenuItem<String?>(
                              value: m['userId'] as String,
                              child: Text(m['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          final m = members.firstWhere(
                            (x) => x['userId'] == v,
                            orElse: () => {'userId': '', 'name': ''},
                          );
                          setState(() {
                            _responsibleUserId = v;
                            _responsibleUserName = m['name'];
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(FirebaseCollections.clubs)
                        .doc(widget.clubId)
                        .collection(FirebaseCollections.teams)
                        .snapshots(),
                    builder: (context, teamSnap) {
                      final teamDocs = teamSnap.data?.docs ?? [];
                      final teams = teamDocs.map((d) {
                        final data = d.data();
                        return {
                          'teamId': d.id,
                          'name': data['name'] as String? ?? 'Équipe',
                        };
                      }).toList();
                      return DropdownButtonFormField<String?>(
                        initialValue: _assignedTeamId,
                        decoration: const InputDecoration(
                          labelText: "Équipe affectée",
                          hintText: "Sélectionner une équipe",
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Tout le club"),
                          ),
                          ...teams.map(
                            (t) => DropdownMenuItem<String?>(
                              value: t['teamId'] as String,
                              child: Text(t['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          final t = teams.firstWhere(
                            (x) => x['teamId'] == v,
                            orElse: () => {
                              'teamId': '',
                              'name': 'Tout le club',
                            },
                          );
                          setState(() {
                            _assignedTeamId = v;
                            _assignedTeamName = v != null
                                ? t['name']
                                : 'Tout le club';
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
  late String _category;
  late String _condition;
  late String _availability;
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _serialNumberController;
  late TextEditingController _quantityTotalController;
  late TextEditingController _locationController;
  late TextEditingController _invoiceReferenceController;
  late TextEditingController _estimatedLifespanController;
  late TextEditingController _unitPriceController;
  late TextEditingController _loanUnitPriceController;
  late TextEditingController _notesController;
  DateTime? _purchaseDate;
  DateTime? _lastMaintenance;
  DateTime? _nextMaintenance;
  String? _responsibleUserId;
  String? _responsibleUserName;
  String? _assignedTeamId;
  String? _assignedTeamName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _nameController = TextEditingController(
      text: data['name'] as String? ?? '',
    );
    _category =
        data['category'] as String? ?? EquipmentHelpers.categoryEntrainement;
    _brandController = TextEditingController(
      text: data['brand'] as String? ?? '',
    );
    _modelController = TextEditingController(
      text: data['model'] as String? ?? '',
    );
    _serialNumberController = TextEditingController(
      text: data['serialNumber'] as String? ?? '',
    );
    final qtyTotal =
        data['quantityTotal'] as int? ?? data['quantity'] as int? ?? 1;
    _quantityTotalController = TextEditingController(text: qtyTotal.toString());
    _locationController = TextEditingController(
      text: data['location'] as String? ?? '',
    );
    _invoiceReferenceController = TextEditingController(
      text: data['invoiceReference'] as String? ?? '',
    );
    final lifespan = data['estimatedLifespanMonths'] as int?;
    _estimatedLifespanController = TextEditingController(
      text: lifespan?.toString() ?? '',
    );
    final unitPrice = data['unitPrice'] as num?;
    _unitPriceController = TextEditingController(
      text: unitPrice?.toString() ?? '',
    );
    final loanUnitPrice = data['loanUnitPrice'] as num?;
    _loanUnitPriceController = TextEditingController(
      text: loanUnitPrice?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: data['notes'] as String? ?? '',
    );
    _condition = data['condition'] as String? ?? EquipmentHelpers.conditionBon;
    _availability =
        data['availability'] as String? ??
        EquipmentHelpers.availabilityDisponible;
    final purchase = data['purchaseDate'] as Timestamp?;
    _purchaseDate = purchase?.toDate();
    final last = data['lastMaintenance'] as Timestamp?;
    final next = data['nextMaintenance'] as Timestamp?;
    _lastMaintenance = last?.toDate();
    _nextMaintenance = next?.toDate();
    _responsibleUserId = data['responsibleUserId'] as String?;
    _responsibleUserName = data['responsibleUserName'] as String?;
    _assignedTeamId = data['assignedTeamId'] as String?;
    _assignedTeamName = data['assignedTeamName'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _quantityTotalController.dispose();
    _locationController.dispose();
    _invoiceReferenceController.dispose();
    _estimatedLifespanController.dispose();
    _unitPriceController.dispose();
    _loanUnitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantityTotal =
        int.tryParse(_quantityTotalController.text.trim()) ?? 1;
    final qtyTotal = quantityTotal < 1 ? 1 : quantityTotal;
    final estimatedLifespan = _estimatedLifespanController.text.trim().isEmpty
        ? null
        : int.tryParse(_estimatedLifespanController.text.trim());
    final unitPrice = _unitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(
            _unitPriceController.text.trim().replaceAll(',', '.'),
          );
    final loanUnitPrice = _loanUnitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(
            _loanUnitPriceController.text.trim().replaceAll(',', '.'),
          );

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .doc(widget.data['id'] as String)
          .update({
            'name': _nameController.text.trim(),
            'category': _category,
            'brand': _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            'model': _modelController.text.trim().isEmpty
                ? null
                : _modelController.text.trim(),
            'serialNumber': _serialNumberController.text.trim().isEmpty
                ? null
                : _serialNumberController.text.trim(),
            'quantityTotal': qtyTotal,
            'quantity': qtyTotal, // Garder pour compatibilité
            'unitPrice': unitPrice,
            'loanUnitPrice': loanUnitPrice,
            'location': _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            'purchaseDate': _purchaseDate != null
                ? Timestamp.fromDate(_purchaseDate!)
                : null,
            'invoiceReference': _invoiceReferenceController.text.trim().isEmpty
                ? null
                : _invoiceReferenceController.text.trim(),
            'estimatedLifespanMonths': estimatedLifespan,
            'responsibleUserId': _responsibleUserId,
            'responsibleUserName': _responsibleUserName,
            'assignedTeamId': _assignedTeamId,
            'assignedTeamName': _assignedTeamName,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Équipement mis à jour.")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
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
        top: MediaQuery.of(context).viewPadding.top + 50,
        bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: "Annuler",
                ),
                const Expanded(
                  child: Text(
                    "Modifier l'équipement",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(
                  width: 48,
                ), // Espace pour équilibrer avec le bouton de gauche
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Identification",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nom *",
                hintText: "ex. Ballons de basket",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: "Catégorie *"),
              items: EquipmentHelpers.categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(EquipmentHelpers.categoryLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: "Marque",
                hintText: "ex. Nike, Adidas",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: "Modèle",
                hintText: "ex. T90, Predator",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serialNumberController,
              decoration: const InputDecoration(
                labelText: "Numéro de série",
                hintText: "ex. SN123456",
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Stock et Localisation",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityTotalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Stock total *",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: "Localisation",
                hintText: "ex. Placard A, Gymnase 1",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitPriceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Prix d'achat à l'unité (€)",
                hintText: "ex. 15.99",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loanUnitPriceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Prix du prêt à l'unité (€) / Jour",
                hintText: "ex. 2.50 (pour le catalogue)",
                helperText: "Prix affiché dans le catalogue pour les joueurs",
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "État et Disponibilité",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: "État"),
              items: EquipmentHelpers.conditions
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(EquipmentHelpers.conditionLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _condition = v ?? _condition),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _availability,
              decoration: const InputDecoration(labelText: "Disponibilité"),
              items: EquipmentHelpers.availabilities
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(EquipmentHelpers.availabilityLabel(a)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _availability = v ?? _availability),
            ),
            const SizedBox(height: 20),
            const Text(
              "Achat et Garantie",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Date d'achat"),
              subtitle: Text(
                _purchaseDate != null
                    ? DateFormat('d MMM yyyy', 'fr_FR').format(_purchaseDate!)
                    : "Non renseignée",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _purchaseDate = d);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _invoiceReferenceController,
              decoration: const InputDecoration(
                labelText: "Référence facture",
                hintText: "ex. FAC-2024-001 ou URL",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimatedLifespanController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Durée de vie estimée (mois)",
                hintText: "ex. 24",
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Affectation",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
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
                  final last = (data['lastName'] as String? ?? '')
                      .trim()
                      .toUpperCase();
                  final name = [
                    first,
                    last,
                  ].where((e) => e.isNotEmpty).join(' ');
                  return {
                    'userId': d.id,
                    'name': name.isEmpty ? 'Membre' : name,
                  };
                }).toList();
                // Vérifier que la valeur actuelle est dans la liste, sinon utiliser null
                final validResponsibleId =
                    _responsibleUserId != null &&
                        members.any((m) => m['userId'] == _responsibleUserId)
                    ? _responsibleUserId
                    : null;
                // Si la valeur n'est pas valide, mettre à jour l'état
                if (validResponsibleId != _responsibleUserId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _responsibleUserId = null;
                        _responsibleUserName = null;
                      });
                    }
                  });
                }
                return DropdownButtonFormField<String?>(
                  initialValue: validResponsibleId,
                  decoration: const InputDecoration(
                    labelText: "Responsable",
                    hintText: "Sélectionner un responsable",
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Aucun"),
                    ),
                    ...members.map(
                      (m) => DropdownMenuItem<String?>(
                        value: m['userId'] as String,
                        child: Text(m['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    final m = members.firstWhere(
                      (x) => x['userId'] == v,
                      orElse: () => {'userId': '', 'name': ''},
                    );
                    setState(() {
                      _responsibleUserId = v;
                      _responsibleUserName = m['name'];
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(FirebaseCollections.clubs)
                  .doc(widget.clubId)
                  .collection(FirebaseCollections.teams)
                  .snapshots(),
              builder: (context, teamSnap) {
                final teamDocs = teamSnap.data?.docs ?? [];
                final teams = teamDocs.map((d) {
                  final data = d.data();
                  return {
                    'teamId': d.id,
                    'name': data['name'] as String? ?? 'Équipe',
                  };
                }).toList();
                // Vérifier que la valeur actuelle est dans la liste, sinon utiliser null
                final validAssignedTeamId =
                    _assignedTeamId != null &&
                        teams.any((t) => t['teamId'] == _assignedTeamId)
                    ? _assignedTeamId
                    : null;
                // Si la valeur n'est pas valide, mettre à jour l'état
                if (validAssignedTeamId != _assignedTeamId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _assignedTeamId = null;
                        _assignedTeamName = null;
                      });
                    }
                  });
                }
                return DropdownButtonFormField<String?>(
                  initialValue: validAssignedTeamId,
                  decoration: const InputDecoration(
                    labelText: "Équipe affectée",
                    hintText: "Sélectionner une équipe",
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Tout le club"),
                    ),
                    ...teams.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t['teamId'] as String,
                        child: Text(t['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    final t = teams.firstWhere(
                      (x) => x['teamId'] == v,
                      orElse: () => {'teamId': '', 'name': 'Tout le club'},
                    );
                    setState(() {
                      _assignedTeamId = v;
                      _assignedTeamName = v != null
                          ? t['name']
                          : 'Tout le club';
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Maintenance",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Dernière maintenance"),
              subtitle: Text(
                _lastMaintenance != null
                    ? DateFormat(
                        'd MMM yyyy',
                        'fr_FR',
                      ).format(_lastMaintenance!)
                    : "Non renseignée",
              ),
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
              contentPadding: EdgeInsets.zero,
              title: const Text("Prochaine maintenance"),
              subtitle: Text(
                _nextMaintenance != null
                    ? DateFormat(
                        'd MMM yyyy',
                        'fr_FR',
                      ).format(_nextMaintenance!)
                    : "Non renseignée",
              ),
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
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: "Notes"),
              maxLines: 2,
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
      ),
    );
  }

  Future<void> _delete() async {
    if (_availability != EquipmentHelpers.availabilityDisponible) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer l'équipement ?"),
        content: const Text("Cette action est irréversible."),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Équipement supprimé.")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
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
        final active = allLoans.where((l) => l['status'] == 'active').toList()
          ..sort((a, b) {
            final ta = a['lentAt'] as Timestamp? ?? Timestamp.now();
            final tb = b['lentAt'] as Timestamp? ?? Timestamp.now();
            return tb.compareTo(ta);
          });
        final history =
            allLoans
                .where(
                  (l) => l['status'] == 'returned' || l['status'] == 'lost',
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
              // Section Catalogue de prêts
              _LoanCatalogSection(clubId: clubId),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Prêts en cours",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                ...active.map((l) => _LoanCard(clubId: clubId, data: l)),
              const SizedBox(height: 24),
              const Text(
                "Historique d'utilisation",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Prêt enregistré.")));
          }
        },
      ),
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
          .collection('equipmentCatalog')
          .snapshots(),
      builder: (context, catalogSnap) {
        final catalogItems = catalogSnap.data?.docs ?? [];

        return Card(
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

        // Convertir la durée des jours vers l'unité de prix pour l'affichage
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
          .collection('equipmentCatalog')
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
                          .collection('equipmentCatalog')
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
        .collection('equipmentCatalog')
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
  String _priceUnit = 'jour'; // jour, semaine, mois
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _maxQuantityController = TextEditingController(
      text: widget.existingCatalogData?['maxQuantity']?.toString() ?? '1',
    );
    // Priorité 1: prix du catalogue existant
    // Priorité 2: loanUnitPrice de l'équipement
    final catalogPrice = widget.existingCatalogData?['price'] as num?;
    final equipmentLoanPrice = widget.equipmentData['loanUnitPrice'] as num?;
    final initialPrice = catalogPrice ?? equipmentLoanPrice;
    _priceController = TextEditingController(
      text: initialPrice?.toString() ?? '',
    );
    _priceUnit = widget.existingCatalogData?['priceUnit'] as String? ?? 'jour';
    final maxLoanDurationDays =
        widget.existingCatalogData?['maxLoanDurationDays'] as int?;
    // Convertir les jours vers l'unité sélectionnée pour l'affichage
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

  // Convertir la durée de l'unité sélectionnée vers les jours
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

  // Obtenir le label de l'unité pour l'affichage
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
    // Convertir vers les jours pour le stockage
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
          .collection('equipmentCatalog')
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
                        // Convertir la valeur actuelle vers la nouvelle unité
                        final currentValue = int.tryParse(
                          _maxLoanDurationController.text.trim(),
                        );
                        if (currentValue != null) {
                          // Convertir de l'ancienne unité vers les jours
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
                          // Convertir des jours vers la nouvelle unité
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

class _LoanCard extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> data;

  const _LoanCard({required this.clubId, required this.data});

  @override
  Widget build(BuildContext context) {
    final borrowerName = data['borrowerName'] as String? ?? 'Inconnu';
    final equipmentName = data['equipmentName'] as String? ?? '—';
    final quantity = data['quantity'] as int? ?? 1;
    final loanUnitPrice = data['loanUnitPrice'] as num?;
    final lentAt = data['lentAt'] as Timestamp?;
    final dueAt = data['dueAt'] as Timestamp?;
    final lentStr = lentAt != null
        ? DateFormat('d MMM', 'fr_FR').format(lentAt.toDate())
        : '—';
    final dueStr = dueAt != null
        ? DateFormat('d MMM', 'fr_FR').format(dueAt.toDate())
        : '—';

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
                Text(
                  "$quantity prêté(s)",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text("Emprunté par $borrowerName"),
            Text(
              "Du $lentStr → retour prévu $dueStr",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (loanUnitPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                'Prix du prêt: ${loanUnitPrice.toStringAsFixed(2)} €/unité${quantity > 1 ? ' (Total: ${(loanUnitPrice * quantity).toStringAsFixed(2)} €)' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Retour enregistré.")));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
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
              decoration: const InputDecoration(hintText: "0", suffixText: "€"),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Prêt marqué comme perdu.")));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }
}

/// Dialog pour créer un prêt : équipement, emprunteur, quantité, date de retour.
class _CreateLoanDialog extends StatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CreateLoanDialog({required this.clubId, required this.onCreated});

  @override
  State<_CreateLoanDialog> createState() => _CreateLoanDialogState();
}

class _CreateLoanDialogState extends State<_CreateLoanDialog> {
  String? _selectedEquipmentId;
  String? _selectedBorrowerId;
  String _selectedBorrowerName = '';
  final _quantityController = TextEditingController(text: '1');
  final _loanUnitPriceController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _loanUnitPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEquipmentId == null || _selectedBorrowerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sélectionnez un équipement et un emprunteur."),
        ),
      );
      return;
    }
    final qty = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (qty < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Quantité invalide.")));
      return;
    }
    final loanUnitPrice = _loanUnitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(
            _loanUnitPriceController.text.trim().replaceAll(',', '.'),
          );
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
        final eqRef = FirebaseFirestore.instance
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.equipment)
            .doc(_selectedEquipmentId);
        final eqSnap = await tx.get(eqRef);
        if (!eqSnap.exists) {
          throw Exception("Équipement introuvable");
        }
        final eqData = eqSnap.data()!;
        final quantityTotal =
            eqData['quantityTotal'] as int? ?? eqData['quantity'] as int? ?? 0;
        if (quantityTotal < qty) {
          throw Exception(
            "Stock insuffisant. Total: $quantityTotal, demandé: $qty",
          );
        }

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
          'loanUnitPrice': loanUnitPrice,
          'lentAt': FieldValue.serverTimestamp(),
          'dueAt': Timestamp.fromDate(_dueDate),
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
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
                      .where(
                        'availability',
                        isEqualTo: EquipmentHelpers.availabilityDisponible,
                      )
                      .snapshots(),
                  builder: (context, eqSnap) {
                    final eqDocs = eqSnap.data?.docs ?? [];
                    final items = eqDocs
                        .map((d) {
                          final data = d.data();
                          final qtyTotal =
                              data['quantityTotal'] as int? ??
                              data['quantity'] as int? ??
                              0;
                          return {
                            'id': d.id,
                            'name': data['name'] as String? ?? '—',
                            'quantityTotal': qtyTotal,
                            'loanUnitPrice': data['loanUnitPrice'] as num?,
                          };
                        })
                        .where((e) => (e['quantityTotal'] as int) > 0)
                        .toList();
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Aucun équipement disponible.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection(FirebaseCollections.clubs)
                          .doc(widget.clubId)
                          .collection('equipmentCatalog')
                          .snapshots(),
                      builder: (context, catalogSnap) {
                        final catalogDocs = catalogSnap.data?.docs ?? [];
                        final catalogMap = <String, Map<String, dynamic>>{};
                        for (final doc in catalogDocs) {
                          catalogMap[doc.id] = doc.data();
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedEquipmentId,
                          decoration: const InputDecoration(
                            labelText: "Équipement",
                          ),
                          items: items
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['id'] as String,
                                  child: Text(
                                    '${e['name']} (${e['quantityTotal']} disponible)',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            final selectedItem = items.firstWhere(
                              (e) => e['id'] == v,
                            );
                            // Priorité 1: loanUnitPrice de l'équipement
                            num? loanPrice =
                                selectedItem['loanUnitPrice'] as num?;

                            // Priorité 2: prix du catalogue si pas de prix sur l'équipement
                            if (loanPrice == null) {
                              final catalogData = catalogMap[v];
                              if (catalogData != null) {
                                loanPrice = catalogData['price'] as num?;
                              }
                            }

                            setState(() {
                              _selectedEquipmentId = v;
                              if (loanPrice != null) {
                                _loanUnitPriceController.text = loanPrice
                                    .toString();
                              } else {
                                _loanUnitPriceController.clear();
                              }
                            });
                          },
                        );
                      },
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
                    final clubMembers = filterUsersByClub(
                      allDocs,
                      widget.clubId,
                    );
                    final members = clubMembers.map((d) {
                      final data = d.data() ?? {};
                      final first = (data['firstName'] as String? ?? '').trim();
                      final last = (data['lastName'] as String? ?? '')
                          .trim()
                          .toUpperCase();
                      final name = [
                        first,
                        last,
                      ].where((e) => e.isNotEmpty).join(' ');
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
                      initialValue: _selectedBorrowerId,
                      decoration: const InputDecoration(
                        labelText: "Emprunteur",
                      ),
                      items: members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m['userId'] as String,
                              child: Text(m['name'] as String),
                            ),
                          )
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
                TextFormField(
                  controller: _loanUnitPriceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Prix du prêt à l'unité (€)",
                    hintText: "ex. 2.50 (optionnel)",
                  ),
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
