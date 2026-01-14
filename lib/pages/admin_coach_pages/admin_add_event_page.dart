import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';

class AdminAddEventPage extends StatefulWidget {
  final String clubId;
  const AdminAddEventPage({super.key, required this.clubId});

  @override
  State<AdminAddEventPage> createState() => _AdminAddEventPageState();
}

class _AdminAddEventPageState extends State<AdminAddEventPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Champs de formulaire
  final List<Map<String, String>> _teamsMeta = [];
  String _selectedType = 'Entraînement';
  String? _selectedTeamName;
  final List<String> _selectedTeams = [];
  final List<String> _selectedCategoriesAudience = [];
  bool _allTeams = false;

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);

  final _locationController = TextEditingController(text: "Stade du club");
  final _titleController = TextEditingController();
  bool _allDay = false;

  bool _isRecurring = false;
  int _weeksCount = 4;

  @override
  void initState() {
    super.initState();
    _loadClubSport();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE ---

  Future<void> _saveEvent() async {
    // 1. Validations de base
    if (_selectedType == 'Entraînement' || _selectedType == 'Match') {
      if (_selectedTeamName == null) {
        _showError("Choisis une équipe pour cet évènement");
        return;
      }
    } else {
      if (_titleController.text.trim().isEmpty) {
        _showError("Titre requis pour cet évènement");
        return;
      }
      if (!_allTeams &&
          _selectedTeams.isEmpty &&
          _selectedCategoriesAudience.isEmpty) {
        _showError("Choisis une audience (équipe ou catégorie)");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // 2. Collecte des IDs des membres concernés pour l'attendance
      final List<String> audienceMembers = await _collectAudienceMembers(
        isTraining: _selectedType == 'Entraînement',
        isMatch: _selectedType == 'Match',
      );
      // Récupération du nom du club
      final clubSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .get();
      final clubName = clubSnap.data()?['name'] as String? ?? "";

      // Récupération de la catégorie pour les entraînements/matchs (utilisée pour les filtres)
      String? categoryForEvent = _selectedCategoriesAudience.isNotEmpty
          ? _selectedCategoriesAudience.first
          : null;
      if (_selectedType == 'Entraînement' || _selectedType == 'Match') {
        final snap = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('teams')
            .where('name', isEqualTo: _selectedTeamName)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          categoryForEvent = snap.docs.first.data()['category'] as String?;
        }
      }

      // Initialisation de la map d'attendance : { 'userId1': 'none', ... }
      final Map<String, String> initialAttendance = {
        for (var id in audienceMembers) id: 'none',
      };

      final batch = FirebaseFirestore.instance.batch();
      int iterations = (_selectedType == 'Entraînement' && _isRecurring)
          ? _weeksCount
          : 1;

      // 3. Boucle de création (gestion récurrence)
      for (int i = 0; i < iterations; i++) {
        DateTime eventDate = _date.add(Duration(days: i * 7));
        String dateId = DateFormat('yyyyMMdd').format(eventDate);

        DocumentReference ref = FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('events')
            .doc();

        final startStr = _allDay ? null : _startTime.format(context);
        final endStr = (_selectedType == 'Match' || _allDay)
            ? null
            : _endTime.format(context);

        batch.set(ref, {
          'title': (_selectedType == 'Entraînement' || _selectedType == 'Match')
              ? null
              : _titleController.text.trim(),
          'type': _selectedType,
          'teamName':
              (_selectedType == 'Entraînement' || _selectedType == 'Match')
              ? _selectedTeamName
              : (_allTeams
                    ? "Tout le club"
                    : (_selectedTeams.isNotEmpty
                          ? _selectedTeams.first
                          : "Multi-équipes")),
          'teamNames':
              (_selectedType == 'Entraînement' || _selectedType == 'Match')
              ? [_selectedTeamName]
              : _selectedTeams,
          'category': categoryForEvent,
          'categories':
              (_selectedType == 'Entraînement' || _selectedType == 'Match')
              ? null
              : _selectedCategoriesAudience,
          'allTeams':
              (_selectedType == 'Entraînement' || _selectedType == 'Match')
              ? false
              : _allTeams,
          'location': _locationController.text.trim(),
          'date': Timestamp.fromDate(eventDate),
          'dateId': dateId,
          'startTime': startStr,
          'endTime': endStr,
          'createdAt': FieldValue.serverTimestamp(),
          'attendance': initialAttendance,
          'teamMemberIds': audienceMembers,
          'creatorId': FirebaseAuth.instance.currentUser?.uid,
          'clubName': clubName,
        });
      }

      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError("Erreur lors de l'enregistrement : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RÉCUPÉRATION DES MEMBRES ---

  Future<List<String>> _collectAudienceMembers({
    required bool isTraining,
    required bool isMatch,
  }) async {
    final clubsRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('teams');
    final Set<String> ids = {};

    if (isTraining || isMatch) {
      if (_selectedTeamName == null) return [];
      final snap = await clubsRef
          .where('name', isEqualTo: _selectedTeamName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        ids.addAll(
          (snap.docs.first.data()['playerIds'] as List?)?.whereType<String>() ??
              [],
        );
      }
    } else if (_allTeams) {
      final snap = await clubsRef.get();
      for (var doc in snap.docs) {
        ids.addAll(
          (doc.data()['playerIds'] as List?)?.whereType<String>() ?? [],
        );
      }
    } else if (_selectedTeams.isNotEmpty) {
      final snap = await clubsRef.where('name', whereIn: _selectedTeams).get();
      for (var doc in snap.docs) {
        ids.addAll(
          (doc.data()['playerIds'] as List?)?.whereType<String>() ?? [],
        );
      }
    } else if (_selectedCategoriesAudience.isNotEmpty) {
      for (final cat in _selectedCategoriesAudience) {
        final snap = await clubsRef.where('category', isEqualTo: cat).get();
        for (var doc in snap.docs) {
          ids.addAll(
            (doc.data()['playerIds'] as List?)?.whereType<String>() ?? [],
          );
        }
      }
    }
    return ids.toList();
  }

  // --- UI HELPERS ---
  bool _isAllTeamsSelected() {
    final names = _teamsMeta
        .map((e) => e['name'] ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return names.isNotEmpty && names.every(_selectedTeams.contains);
  }

  void _toggleAllTeams(bool value) {
    setState(() {
      _allTeams = value;
      if (value) {
        _selectedTeams
          ..clear()
          ..addAll(
            _teamsMeta
                .map((e) => e['name'] ?? '')
                .where((e) => e.isNotEmpty)
                .toSet(),
          );
        _selectedCategoriesAudience
          ..clear()
          ..addAll(
            _teamsMeta
                .map((e) => e['category'] ?? '')
                .where((e) => e.isNotEmpty)
                .toSet(),
          );
      } else {
        _allTeams = false;
      }
    });
  }

  void _toggleCategory(String category, bool value) {
    setState(() {
      if (value) {
        if (!_selectedCategoriesAudience.contains(category)) {
          _selectedCategoriesAudience.add(category);
        }
        for (final team in _teamsMeta.where((t) => t['category'] == category)) {
          final name = team['name'] ?? '';
          if (name.isNotEmpty && !_selectedTeams.contains(name)) {
            _selectedTeams.add(name);
          }
        }
      } else {
        _selectedCategoriesAudience.remove(category);
        _selectedTeams.removeWhere(
          (teamName) => _teamsMeta.any(
            (t) => t['category'] == category && t['name'] == teamName,
          ),
        );
        _allTeams = false;
      }

      if (_isAllTeamsSelected()) {
        _allTeams = true;
        _selectedCategoriesAudience
          ..clear()
          ..addAll(
            _teamsMeta
                .map((e) => e['category'] ?? '')
                .where((e) => e.isNotEmpty)
                .toSet(),
          );
      }
    });
  }

  void _toggleTeam(String name, String category, bool value) {
    setState(() {
      if (value) {
        if (!_selectedTeams.contains(name)) _selectedTeams.add(name);
      } else {
        _selectedTeams.remove(name);
        _allTeams = false;
      }

      final catTeams = _teamsMeta
          .where((t) => t['category'] == category)
          .map((t) => t['name'] ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final allCatSelected =
          catTeams.isNotEmpty && catTeams.every(_selectedTeams.contains);

      if (allCatSelected) {
        if (!_selectedCategoriesAudience.contains(category)) {
          _selectedCategoriesAudience.add(category);
        }
      } else {
        _selectedCategoriesAudience.remove(category);
      }

      _allTeams = _isAllTeamsSelected();
      if (_allTeams) {
        _selectedCategoriesAudience
          ..clear()
          ..addAll(
            _teamsMeta
                .map((e) => e['category'] ?? '')
                .where((e) => e.isNotEmpty)
                .toSet(),
          );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadClubSport() async {
    final doc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .get();
    final sport = doc.data()?['sport'] as String?;
    if (_locationController.text == "Stade du club") {
      setState(
        () => _locationController.text = _defaultLocationForSport(sport),
      );
    }
  }

  String _defaultLocationForSport(String? sport) {
    if (sport == null) return "Lieu du club";
    final s = sport.toLowerCase();
    if (s.contains("basket") || s.contains("hand") || s.contains("volley"))
      return "Gymnase du club";
    if (s.contains("foot") || s.contains("rugby")) return "Stade du club";
    if (s.contains("tennis")) return "Terrain du club";
    return "Lieu du club";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajouter un évènement")),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ViroColors.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDropdown<String>(
                    label: "Type d'évènement",
                    value: _selectedType,
                    items: ['Entraînement', 'Match', 'Évènement', 'Autre'],
                    onChanged: (val) => setState(() {
                      _selectedType = val!;
                      _allDay = false;
                      _isRecurring = false;
                      if (_selectedType == 'Match') _weeksCount = 1;
                    }),
                  ),

                  if (_selectedType != 'Entraînement' &&
                      _selectedType != 'Match')
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        "Titre de l'évènement",
                        Icons.title,
                      ),
                    ),

                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(widget.clubId)
                        .collection('teams')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      var teams = snap.data!.docs;
                      _teamsMeta
                        ..clear()
                        ..addAll(
                          teams.map(
                            (t) => {
                              'name': (t['name'] as String?) ?? '',
                              'category': (t['category'] as String?) ?? '',
                            },
                          ),
                        );

                      final categories = _teamsMeta
                          .map((t) => t['category'] ?? '')
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList();

                      if (_selectedType == 'Entraînement' ||
                          _selectedType == 'Match') {
                        return _buildDropdown<String>(
                          label: "Équipe concernée",
                          value: _selectedTeamName,
                          hint: "Choisir une équipe",
                          items: teams.map((t) => t['name'] as String).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedTeamName = val),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text("Tout le club"),
                            value: _allTeams,
                            onChanged: (v) => _toggleAllTeams(v),
                          ),
                          if (!_allTeams) ...[
                            const Text(
                              "Par catégories (sélection multiple) :",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            ...categories.map(
                              (c) => CheckboxListTile(
                                title: Text(c),
                                value: _selectedCategoriesAudience.contains(c),
                                onChanged: (v) =>
                                    _toggleCategory(c, v ?? false),
                              ),
                            ),
                            const Text(
                              "Ou par équipes spécifiques :",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            ...teams.map(
                              (t) => CheckboxListTile(
                                title: Text(t['name']),
                                value: _selectedTeams.contains(t['name']),
                                onChanged: (v) => _toggleTeam(
                                  t['name'],
                                  t['category'],
                                  v ?? false,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  TextFormField(
                    controller: _locationController,
                    decoration: _inputDecoration(
                      "Lieu",
                      Icons.location_on_outlined,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimePicker(
                          label: "Jour",
                          value: DateFormat(
                            'dd/MM/yyyy',
                            'fr_FR',
                          ).format(_date),
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_selectedType != 'Match')
                    SwitchListTile(
                      title: const Text("Journée entière"),
                      value: _allDay,
                      onChanged: (v) => setState(() => _allDay = v),
                    ),

                  if (!_allDay)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePicker(
                            label: "Début",
                            value: _startTime.format(context),
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_selectedType != 'Match')
                          Expanded(
                            child: _buildDateTimePicker(
                              label: "Fin",
                              value: _endTime.format(context),
                              onTap: () => _pickTime(false),
                            ),
                          ),
                      ],
                    ),

                  if (_selectedType == 'Entraînement') ...[
                    const Divider(height: 40),
                    SwitchListTile(
                      title: const Text(
                        "Récurrence hebdomadaire",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _isRecurring,
                      onChanged: (val) => setState(() => _isRecurring = val),
                    ),
                    if (_isRecurring)
                      _buildDropdown<int>(
                        label: "Nombre de semaines",
                        value: _weeksCount,
                        items: [2, 4, 8, 12],
                        onChanged: (val) => setState(() => _weeksCount = val!),
                      ),
                  ],

                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ViroColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveEvent,
                    child: const Text(
                      "ENREGISTRER",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- PICKERS ---

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null)
      setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  Widget _buildDropdown<T>({
    required String label,
    T? value,
    String? hint,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: _inputDecoration(label, Icons.layers_outlined),
        hint: hint != null ? Text(hint) : null,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: ViroColors.borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ViroColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
