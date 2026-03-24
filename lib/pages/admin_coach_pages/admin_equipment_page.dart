import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/equipment_helpers.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/photo_permission_helper.dart';
import 'admin_add_equipment_page.dart';
import 'admin_loans_page.dart';

class AdminEquipmentPage extends StatefulWidget {
  final String clubId;
  final String? sport;

  const AdminEquipmentPage({super.key, required this.clubId, this.sport});

  @override
  State<AdminEquipmentPage> createState() => _AdminEquipmentPageState();
}

class _AdminEquipmentPageState extends State<AdminEquipmentPage> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: ViroColors.background,
        appBar: AppBar(title: const Text("Équipement"), centerTitle: true, automaticallyImplyLeading: false),
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
        final rolesInClub =
            getAllUserRolesInClub(userData ?? {}, widget.clubId);
        final canManageEquipment = rolesInClub.contains('admin') ||
            rolesInClub.contains('admin_fondateur');
        if (userSnap.hasData && userData != null && !canManageEquipment) {
          return Scaffold(
            backgroundColor: ViroColors.background,
            appBar: AppBar(title: const Text("Équipement"), centerTitle: true, automaticallyImplyLeading: false),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Accès réservé aux administrateurs",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "La gestion des équipements n'est pas disponible pour les coaches.",
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
            title: const Text("Équipement"),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminLoansPage(clubId: widget.clubId),
                  ),
                ),
                icon: const Icon(Icons.handshake_outlined, size: 18),
                label: const Text("Prêts"),
                style: TextButton.styleFrom(
                  foregroundColor: ViroColors.primary,
                ),
              ),
            ],
          ),
          body: _InventoryTab(clubId: widget.clubId, sport: widget.sport),
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_equipment',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminAddEquipmentPage(
                  clubId: widget.clubId,
                  sport: widget.sport,
                ),
              ),
            ),
            backgroundColor: ViroColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
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
      stream: appFirestore
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                FirebaseErrorHandler.getErrorMessage(snap.error),
                style: const TextStyle(color: ViroColors.error),
                textAlign: TextAlign.center,
              ),
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
                  color: ViroColors.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Valeur totale de l'inventaire",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
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
      color: ViroColors.warning.withValues(alpha: 0.15),
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
    final nextMaintenance = data['nextMaintenance'] as Timestamp?;
    final imageUrl = data['imageUrl'] as String?;

    final conditionColor = (condition == EquipmentHelpers.conditionBon || condition == EquipmentHelpers.conditionNeuf)
        ? ViroColors.primary
        : (condition == EquipmentHelpers.conditionHorsService ? ViroColors.error : ViroColors.warning);
    final availabilityColor = availability == EquipmentHelpers.availabilityDisponible
        ? ViroColors.primary
        : Colors.grey.shade500;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditEquipmentSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image ou placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  color: ViroColors.primary.withValues(alpha: 0.06),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Icon(Icons.inventory_2_outlined, size: 22, color: ViroColors.primary.withValues(alpha: 0.4)),
                        errorWidget: (_, __, ___) => Icon(Icons.inventory_2_outlined, size: 22, color: ViroColors.primary.withValues(alpha: 0.4)),
                      )
                    : Icon(Icons.inventory_2_outlined, size: 22, color: ViroColors.primary.withValues(alpha: 0.4)),
              ),
              const SizedBox(width: 12),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                      ],
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        EquipmentHelpers.categoryLabel(category),
                        style: TextStyle(fontSize: 11, color: ViroColors.primary.withValues(alpha: 0.75)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Infos compactes sur une ligne
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        _infoItem(Icons.inventory_2_outlined, 'x$quantityTotal'),
                        if (location != null) _infoItem(Icons.location_on_outlined, location),
                        if (unitPrice != null) _infoItem(Icons.euro_outlined, '${unitPrice.toStringAsFixed(2)} €'),
                        if (loanUnitPrice != null) _infoItem(Icons.handshake_outlined, 'Prêt ${loanUnitPrice.toStringAsFixed(2)} €'),
                        if (brand != null || model != null)
                          _infoItem(Icons.label_outline, [if (brand != null) brand, if (model != null) model].join(' ')),
                        if (nextMaintenance != null)
                          _infoItem(Icons.build_outlined, 'Maint. ${DateFormat('d MMM', 'fr_FR').format(nextMaintenance.toDate())}', color: ViroColors.warning),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(EquipmentHelpers.conditionLabel(condition), conditionColor),
                        _chip(EquipmentHelpers.availabilityLabel(availability), availabilityColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String? label, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label ?? '', style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
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
  final _cautionController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = EquipmentHelpers.categoryEntrainement;
  String _condition = EquipmentHelpers.conditionBon;
  String _availability = EquipmentHelpers.availabilityDisponible;
  DateTime? _purchaseDate;
  String? _responsibleUserId;
  String? _responsibleUserName;
  String? _assignedTeamId;
  String? _assignedTeamName;
  XFile? _pickedImage;
  bool _saving = false;

  Future<void> _pickImage() async {
    final file = await pickPhotoWithPermission(context, imageQuality: 85);
    if (file != null) setState(() => _pickedImage = file);
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
    _cautionController.dispose();
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
    final caution = _cautionController.text.trim().isEmpty
        ? null
        : double.tryParse(_cautionController.text.trim().replaceAll(',', '.'));

    setState(() => _saving = true);
    try {
      final ref = await appFirestore
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
            'caution': caution,
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
      final equipmentId = ref.id;
      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('clubs')
            .child(widget.clubId)
            .child('equipment')
            .child(equipmentId)
            .child('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(_pickedImage!.path));
        final imageUrl = await storageRef.getDownloadURL();
        await ref.update({'imageUrl': imageUrl});
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
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
                  // Photo de l'objet
                  Row(
                    children: [
                      InkWell(
                        onTap: _saving ? null : _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: _pickedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_pickedImage!.path),
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 36,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Photo",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Photo de l'objet",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _saving ? null : _pickImage,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 20,
                              ),
                              label: const Text("Choisir une photo"),
                            ),
                            if (_pickedImage != null)
                              TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _pickedImage = null),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text("Retirer"),
                                style: TextButton.styleFrom(
                                  foregroundColor: ViroColors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                    controller: _cautionController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Caution (€) si perdu ou endommagé",
                      hintText: "ex. 50",
                      helperText: "Montant en cas de perte ou d'endommagement",
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
                    stream: appFirestore
                        .collection(FirebaseCollections.users)
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
                        isExpanded: true,
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
                    stream: appFirestore
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
                        isExpanded: true,
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
  late TextEditingController _cautionController;
  late TextEditingController _notesController;
  DateTime? _purchaseDate;
  DateTime? _lastMaintenance;
  DateTime? _nextMaintenance;
  String? _responsibleUserId;
  String? _responsibleUserName;
  String? _assignedTeamId;
  String? _assignedTeamName;
  String? _imageUrl;
  XFile? _newPhotoFile;
  bool _removePhoto = false;
  bool _saving = false;

  Future<void> _pickImage() async {
    final file = await pickPhotoWithPermission(context, imageQuality: 85);
    if (file != null) {
      setState(() {
        _newPhotoFile = file;
        _removePhoto = false;
      });
    }
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 36,
          color: Colors.grey.shade600,
        ),
        const SizedBox(height: 4),
        Text(
          "Photo",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _imageUrl = data['imageUrl'] as String?;
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
    final caution = data['caution'] as num?;
    _cautionController = TextEditingController(text: caution?.toString() ?? '');
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
    _cautionController.dispose();
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
    final caution = _cautionController.text.trim().isEmpty
        ? null
        : double.tryParse(_cautionController.text.trim().replaceAll(',', '.'));

    setState(() => _saving = true);
    try {
      await appFirestore
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
            'caution': caution,
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
      final equipmentId = widget.data['id'] as String;
      if (_removePhoto) {
        await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.equipment)
            .doc(equipmentId)
            .update({'imageUrl': null});
      } else if (_newPhotoFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('clubs')
            .child(widget.clubId)
            .child('equipment')
            .child(equipmentId)
            .child('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(_newPhotoFile!.path));
        final imageUrl = await storageRef.getDownloadURL();
        await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.equipment)
            .doc(equipmentId)
            .update({'imageUrl': imageUrl});
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Équipement mis à jour.")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value != null ? DateFormat('d MMM yyyy', 'fr_FR').format(value) : '—',
          style: TextStyle(color: value != null ? null : Colors.grey.shade500),
        ),
      ),
    );
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
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    "Modifier l'équipement",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),

            // ── ESSENTIELLES ─────────────────────────────────────────────────

            // Photo
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickImage,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_newPhotoFile != null || (_imageUrl != null && !_removePhoto))
                          ? ViroColors.primary
                          : Colors.grey.shade300,
                      width: (_newPhotoFile != null || (_imageUrl != null && !_removePhoto)) ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _newPhotoFile != null
                      ? Image.file(File(_newPhotoFile!.path), fit: BoxFit.cover)
                      : (!_removePhoto && _imageUrl != null && _imageUrl!.isNotEmpty)
                          ? Image.network(_imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photoPlaceholder())
                          : _photoPlaceholder(),
                ),
              ),
            ),
            if ((_imageUrl != null && _imageUrl!.isNotEmpty && !_removePhoto) || _newPhotoFile != null)
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : () => setState(() { _newPhotoFile = null; _removePhoto = true; }),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text("Retirer la photo"),
                  style: TextButton.styleFrom(foregroundColor: ViroColors.error),
                ),
              )
            else
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text("Ajouter une photo"),
                ),
              ),
            const SizedBox(height: 12),

            // Nom
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: "Nom *", hintText: "ex. Ballons de basket"),
            ),
            const SizedBox(height: 12),

            // Catégorie
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: "Catégorie *"),
              items: EquipmentHelpers.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(EquipmentHelpers.categoryLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),

            // Quantité + Localisation
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityTotalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantité *"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: "Rangé où", hintText: "ex. Placard A"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // État + Disponibilité
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(labelText: "État"),
                    items: EquipmentHelpers.conditions
                        .map((c) => DropdownMenuItem(value: c, child: Text(EquipmentHelpers.conditionLabel(c))))
                        .toList(),
                    onChanged: (v) => setState(() => _condition = v ?? _condition),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _availability,
                    decoration: const InputDecoration(labelText: "Disponibilité"),
                    items: EquipmentHelpers.availabilities
                        .map((a) => DropdownMenuItem(value: a, child: Text(EquipmentHelpers.availabilityLabel(a))))
                        .toList(),
                    onChanged: (v) => setState(() => _availability = v ?? _availability),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── OPTIONNELLES (ExpansionTile) ──────────────────────────────────
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  "Informations optionnelles",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade700),
                ),
                children: [
                  const SizedBox(height: 4),
                  // Marque + Modèle
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: "Marque", hintText: "ex. Nike"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(labelText: "Modèle", hintText: "ex. Predator"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serialNumberController,
                    decoration: const InputDecoration(labelText: "Numéro de série", hintText: "ex. SN123456"),
                  ),
                  const SizedBox(height: 16),
                  // Prix
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _unitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Prix achat (€)", hintText: "ex. 15.99"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _loanUnitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Prix prêt (€)", hintText: "ex. 2.50"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cautionController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Caution (€)", hintText: "ex. 50"),
                  ),
                  const SizedBox(height: 16),
                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: _dateTile("Date d'achat", _purchaseDate, () async {
                          final d = await showDatePicker(context: context, initialDate: _purchaseDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                          if (d != null) setState(() => _purchaseDate = d);
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _estimatedLifespanController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Durée de vie (mois)", hintText: "ex. 24"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoiceReferenceController,
                    decoration: const InputDecoration(labelText: "Réf. facture", hintText: "ex. FAC-2024-001"),
                  ),
                  const SizedBox(height: 16),
                  // Affectation
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: appFirestore.collection(FirebaseCollections.users).snapshots(),
                    builder: (context, userSnap) {
                      final members = filterUsersByClub(userSnap.data?.docs ?? [], widget.clubId).map((d) {
                        final ud = d.data() ?? {};
                        final name = ['${ud['firstName'] ?? ''}'.trim(), '${ud['lastName'] ?? ''}'.trim().toUpperCase()].where((e) => e.isNotEmpty).join(' ');
                        return {'userId': d.id, 'name': name.isEmpty ? 'Membre' : name};
                      }).toList();
                      final validId = _responsibleUserId != null && members.any((m) => m['userId'] == _responsibleUserId) ? _responsibleUserId : null;
                      if (validId != _responsibleUserId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() { _responsibleUserId = null; _responsibleUserName = null; }); });
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: validId,
                        decoration: const InputDecoration(labelText: "Responsable"),
                        items: [const DropdownMenuItem(value: null, child: Text("Aucun")), ...members.map((m) => DropdownMenuItem(value: m['userId'] as String, child: Text(m['name'] as String)))],
                        onChanged: (v) { final m = members.firstWhere((x) => x['userId'] == v, orElse: () => {'userId': '', 'name': ''}); setState(() { _responsibleUserId = v; _responsibleUserName = m['name']; }); },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: appFirestore.collection(FirebaseCollections.clubs).doc(widget.clubId).collection(FirebaseCollections.teams).snapshots(),
                    builder: (context, teamSnap) {
                      final teams = (teamSnap.data?.docs ?? []).map((d) => {'teamId': d.id, 'name': d.data()['name'] as String? ?? 'Équipe'}).toList();
                      final validId = _assignedTeamId != null && teams.any((t) => t['teamId'] == _assignedTeamId) ? _assignedTeamId : null;
                      if (validId != _assignedTeamId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() { _assignedTeamId = null; _assignedTeamName = null; }); });
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: validId,
                        decoration: const InputDecoration(labelText: "Équipe affectée"),
                        items: [const DropdownMenuItem(value: null, child: Text("Tout le club")), ...teams.map((t) => DropdownMenuItem(value: t['teamId'] as String, child: Text(t['name'] as String)))],
                        onChanged: (v) { final t = teams.firstWhere((x) => x['teamId'] == v, orElse: () => {'teamId': '', 'name': 'Tout le club'}); setState(() { _assignedTeamId = v; _assignedTeamName = v != null ? t['name'] : 'Tout le club'; }); },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Maintenance
                  Row(
                    children: [
                      Expanded(
                        child: _dateTile("Dernière maintenance", _lastMaintenance, () async {
                          final d = await showDatePicker(context: context, initialDate: _lastMaintenance ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                          if (d != null) setState(() => _lastMaintenance = d);
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile("Prochaine maintenance", _nextMaintenance, () async {
                          final d = await showDatePicker(context: context, initialDate: _nextMaintenance ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                          if (d != null) setState(() => _nextMaintenance = d);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: "Notes", alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViroColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_availability == EquipmentHelpers.availabilityDisponible) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: Text("Supprimer", style: TextStyle(color: ViroColors.error)),
              ),
            ],
            const SizedBox(height: 8),
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
      await appFirestore
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
        ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
