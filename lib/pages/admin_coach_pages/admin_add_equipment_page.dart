import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viro_team/utils/firestore_instance.dart';

import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/equipment_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/photo_permission_helper.dart' show pickPhotoWithPermission;

class AdminAddEquipmentPage extends StatefulWidget {
  final String clubId;
  final String? sport;

  const AdminAddEquipmentPage({super.key, required this.clubId, this.sport});

  @override
  State<AdminAddEquipmentPage> createState() => _AdminAddEquipmentPageState();
}

class _AdminAddEquipmentPageState extends State<AdminAddEquipmentPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _saving = false;

  // Champs essentiels (step 1)
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  String _category = EquipmentHelpers.categoryEntrainement;
  String _condition = EquipmentHelpers.conditionNeuf;
  XFile? _pickedImage;

  // Champs optionnels (step 2)
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _loanUnitPriceController = TextEditingController();
  final _cautionController = TextEditingController();
  final _invoiceReferenceController = TextEditingController();
  final _estimatedLifespanController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _purchaseDate;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _unitPriceController.dispose();
    _loanUnitPriceController.dispose();
    _cautionController.dispose();
    _invoiceReferenceController.dispose();
    _estimatedLifespanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await pickPhotoWithPermission(context, imageQuality: 80);
    if (file != null) setState(() => _pickedImage = file);
  }

  bool _validateStep1() {
    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final qty = (int.tryParse(_quantityController.text.trim()) ?? 1).clamp(
        1,
        9999,
      );
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
          : double.tryParse(
              _cautionController.text.trim().replaceAll(',', '.'),
            );
      final estimatedLifespan = _estimatedLifespanController.text.trim().isEmpty
          ? null
          : int.tryParse(_estimatedLifespanController.text.trim());

      final ref = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipment)
          .add({
            'name': _nameController.text.trim(),
            'category': _category,
            'condition': _condition,
            'availability': EquipmentHelpers.availabilityDisponible,
            'quantityTotal': qty,
            'quantity': qty,
            'location': _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            'brand': _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            'model': _modelController.text.trim().isEmpty
                ? null
                : _modelController.text.trim(),
            'serialNumber': _serialNumberController.text.trim().isEmpty
                ? null
                : _serialNumberController.text.trim(),
            'unitPrice': unitPrice,
            'loanUnitPrice': loanUnitPrice,
            'caution': caution,
            'purchaseDate': _purchaseDate != null
                ? Timestamp.fromDate(_purchaseDate!)
                : null,
            'invoiceReference': _invoiceReferenceController.text.trim().isEmpty
                ? null
                : _invoiceReferenceController.text.trim(),
            'estimatedLifespanMonths': estimatedLifespan,
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('clubs')
            .child(widget.clubId)
            .child('equipment')
            .child(ref.id)
            .child('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(_pickedImage!.path));
        final imageUrl = await storageRef.getDownloadURL();
        await ref.update({'imageUrl': imageUrl});
      }

      if (!mounted) return;
      Navigator.of(context).pop();
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

  // ─── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const steps = ['Équipement', 'Détails'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == _currentStep;
          final done = i < _currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < steps.length - 1 ? 8 : 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (active || done)
                              ? ViroColors.primary
                              : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: TextStyle(
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: active
                                ? ViroColors.primary
                                : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (active || done) ? 1.0 : 0.0,
                      minHeight: 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(
                        ViroColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Step 1 ─────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  color: _pickedImage != null
                      ? ViroColors.primary
                      : Colors.grey.shade300,
                  width: _pickedImage != null ? 2 : 1,
                ),
              ),
              child: _pickedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(_pickedImage!.path),
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _pickedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Nom
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nom *',
            hintText: 'ex. Ballons de basket',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const SizedBox(height: 12),

        // Catégorie
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Catégorie *'),
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

        // Quantité
        TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité *'),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1) return '≥ 1';
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Localisation
        TextFormField(
          controller: _locationController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Rangé où',
            hintText: 'ex. Placard A, Gymnase 1',
          ),
        ),
        const SizedBox(height: 12),

        // État
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'État'),
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
      ],
    );
  }

  // ─── Step 2 ─────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tous les champs sont optionnels',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // Marque + Modèle
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Marque',
                  hintText: 'ex. Nike',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  hintText: 'ex. Predator',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Numéro de série
        TextFormField(
          controller: _serialNumberController,
          decoration: const InputDecoration(
            labelText: 'Numéro de série',
            hintText: 'ex. SN123456',
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Prix',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _unitPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Prix d'achat (€)",
                  hintText: 'ex. 15.99',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _loanUnitPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Prix prêt (€)',
                  hintText: 'ex. 2.50',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cautionController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Caution prêt (€)',
            hintText: 'ex. 50',
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Informations complémentaires',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),

        // Date d'achat
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _purchaseDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _purchaseDate = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: "Date d'achat",
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              _purchaseDate != null
                  ? '${_purchaseDate!.day.toString().padLeft(2, '0')}/${_purchaseDate!.month.toString().padLeft(2, '0')}/${_purchaseDate!.year}'
                  : '—',
              style: TextStyle(
                color: _purchaseDate != null ? null : Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _estimatedLifespanController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée de vie (mois)',
                  hintText: 'ex. 24',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _invoiceReferenceController,
                decoration: const InputDecoration(
                  labelText: 'Réf. facture',
                  hintText: 'ex. FAC-2024-001',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _notesController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Informations supplémentaires...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Ajouter un équipement'),
        centerTitle: true,
        leading: _currentStep == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 0),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : _currentStep == 0
                        ? () {
                            if (_validateStep1()) {
                              setState(() => _currentStep = 1);
                            }
                          }
                        : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ViroColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == 0 ? 'SUIVANT' : 'ENREGISTRER',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
