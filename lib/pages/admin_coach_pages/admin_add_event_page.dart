import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/avatar_moderation.dart';

class AdminAddEventPage extends StatefulWidget {
  final String clubId;
  final DateTime? initialDate;

  const AdminAddEventPage({super.key, required this.clubId, this.initialDate});

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
  bool _summonAllPlayers = true;
  final List<String> _selectedPlayersMatch = [];
  final List<String> _selectedTeams = [];
  final List<String> _selectedCategoriesAudience = [];
  bool _allTeams = false;

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);

  final _locationController = TextEditingController(text: "Stade du club");
  final _titleController = TextEditingController();
  final _meetingLocationController = TextEditingController();
  TimeOfDay _rdvTime = const TimeOfDay(hour: 17, minute: 30);
  bool _allDay = false;

  bool _isRecurring = false;
  int _weeksCount = 4;
  String _recurrenceMode = 'weeks'; // 'weeks' ou 'season_end'
  DateTime? _seasonEndDate;

  // Rappels de présence (Match / Entraînement uniquement)
  int _reminderCount = 2; // 0 = aucun, 1 = un rappel, 2 = deux rappels
  bool _reminder1UseWeekday =
      true; // true = jour de la semaine avant, false = X jours avant
  int _reminder1Weekday = 7; // 1 = lundi, 7 = dimanche (défaut : dimanche 16h)
  int _reminder1DaysBefore = 1;
  TimeOfDay _reminder1Time = const TimeOfDay(hour: 16, minute: 0);
  bool _reminder2UseWeekday = false; // défaut : jours avant
  int _reminder2Weekday = 7;
  int _reminder2DaysBefore = 2; // défaut : 2 jours avant à 18h30
  TimeOfDay _reminder2Time = const TimeOfDay(hour: 18, minute: 30);
  final _reminder1MessageController = TextEditingController();
  final _reminder2MessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _date = widget.initialDate!;
    }
    _loadClubSport();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    _meetingLocationController.dispose();
    _reminder1MessageController.dispose();
    _reminder2MessageController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE ---

  Future<void> _saveEvent() async {
    // 1. Validations de base
    if (!_allDay && _selectedType != 'Match') {
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      if (endMinutes <= startMinutes) {
        _showError("L'heure de fin doit être après l'heure de début");
        return;
      }
    }

    if (_selectedType == 'Entraînement' || _selectedType == 'Match') {
      if (_selectedTeamName == null) {
        _showError("Choisis une équipe pour cet évènement");
        return;
      }
      if (_selectedType == 'Match' &&
          !_summonAllPlayers &&
          _selectedPlayersMatch.isEmpty) {
        _showError("Sélectionne au moins un joueur ou convoque toute l'équipe");
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
      List<String> audienceMembers = await _collectAudienceMembers(
        isTraining: _selectedType == 'Entraînement',
        isMatch: _selectedType == 'Match',
      );
      if (_selectedType == 'Match' && !_summonAllPlayers) {
        // Utilise uniquement les joueurs sélectionnés
        audienceMembers = List.from(_selectedPlayersMatch);
      }
      // Récupération du nom du club
      final clubSnap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .get();
      final clubData = clubSnap.data();
      final clubName = clubData?['name'] as String? ?? "";
      final clubSport = clubData?['sport'] as String?;

      // Récupération de la catégorie pour les entraînements/matchs (utilisée pour les filtres)
      String? categoryForEvent = _selectedCategoriesAudience.isNotEmpty
          ? _selectedCategoriesAudience.first
          : null;
      if (_selectedType == 'Entraînement' || _selectedType == 'Match') {
        final snap = await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.teams)
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

      final batch = appFirestore.batch();
      int iterations = 1;
      if (_selectedType == 'Entraînement' && _isRecurring) {
        if (_recurrenceMode == 'season_end' && _seasonEndDate != null) {
          // Calculer le nombre de semaines jusqu'à la fin de saison
          final daysDifference = _seasonEndDate!.difference(_date).inDays;
          if (daysDifference < 0) {
            _showError(
              "La date de début ne peut pas être après la fin de saison",
            );
            setState(() => _isLoading = false);
            return;
          }
          iterations = (daysDifference / 7).ceil();
          // Limiter à 52 semaines pour sécurité
          if (iterations > 52) iterations = 52;
          if (iterations < 1) iterations = 1;
        } else {
          iterations = _weeksCount;
        }
      }

      if (!context.mounted) return;

      // Générer un ID de série unique si c'est un événement récurrent
      final String? seriesId = iterations > 1
          ? appFirestore.collection(FirebaseCollections.clubs).doc().id
          : null;

      // 3. Boucle de création (gestion récurrence)
      for (int i = 0; i < iterations; i++) {
        DateTime eventDate = _date.add(Duration(days: i * 7));
        String dateId = DateFormat('yyyyMMdd').format(eventDate);

        DocumentReference ref = appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.events)
            .doc();

        final startStr = _allDay ? null : _startTime.format(context);
        final endStr = (_selectedType == 'Match' || _allDay)
            ? null
            : _endTime.format(context);

        final Map<String, dynamic> eventData = {
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
          'clubSport': clubSport,
        };
        if (seriesId != null) {
          eventData['seriesId'] = seriesId;
        }
        final reminderConfig = _buildReminderConfig();
        if (reminderConfig != null) {
          eventData['reminderConfig'] = reminderConfig;
        }
        if (_selectedType == 'Match') {
          eventData['meetingLocation'] = _meetingLocationController.text.trim();
          eventData['meetingTime'] = _rdvTime.format(context);
        }
        batch.set(ref, eventData);
      }

      await batch.commit();
      if (!context.mounted) return;
      AppLogger.instance.info(
        iterations > 1 ? 'Événements récurrents créés' : 'Événement créé',
        {
          'clubId': widget.clubId,
          'eventType': _selectedType,
          'iterations': iterations,
          'date': _date.toIso8601String(),
          'teamName': _selectedTeamName ?? 'N/A',
          'creatorId': FirebaseAuth.instance.currentUser?.uid,
        },
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la création d\'événement',
        error: e,
        context: {
          'clubId': widget.clubId,
          'eventType': _selectedType,
          'creatorId': FirebaseAuth.instance.currentUser?.uid,
        },
      );
      _showError("Erreur lors de l'enregistrement : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Construit reminderConfig pour Firestore (null si 0 rappel).
  /// Rappel 1 : weekday (1-7) ou daysBefore (1-10) + time.
  /// Rappel 2 : daysBefore + time.
  Map<String, dynamic>? _buildReminderConfig() {
    if (_reminderCount == 0) return null;
    final reminders = <Map<String, dynamic>>[];
    String formatTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final isCustomText =
        _selectedType != 'Entraînement' && _selectedType != 'Match';

    if (_reminderCount >= 1) {
      final r1 = <String, dynamic>{'time': formatTime(_reminder1Time)};
      if (_reminder1UseWeekday) {
        r1['weekday'] = _reminder1Weekday;
      } else {
        r1['daysBefore'] = _reminder1DaysBefore;
      }
      if (isCustomText && _reminder1MessageController.text.trim().isNotEmpty) {
        r1['message'] = _reminder1MessageController.text.trim();
      }
      reminders.add(r1);
    }
    if (_reminderCount >= 2) {
      final r2 = <String, dynamic>{'time': formatTime(_reminder2Time)};
      if (_reminder2UseWeekday) {
        r2['weekday'] = _reminder2Weekday;
      } else {
        r2['daysBefore'] = _reminder2DaysBefore;
      }
      if (isCustomText && _reminder2MessageController.text.trim().isNotEmpty) {
        r2['message'] = _reminder2MessageController.text.trim();
      }
      reminders.add(r2);
    }
    return {'reminders': reminders};
  }

  // --- RÉCUPÉRATION DES MEMBRES ---

  Future<List<String>> _collectAudienceMembers({
    required bool isTraining,
    required bool isMatch,
  }) async {
    final clubsRef = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.teams);
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

  Widget _buildMatchPlayersSelector() {
    if (_selectedTeamName == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.teams)
          .where('name', isEqualTo: _selectedTeamName)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }
        final teamData = snapshot.data!.docs.first.data();
        final playerIds =
            (teamData['playerIds'] as List?)?.whereType<String>().toList() ??
            [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text("Convoquer toute l'équipe"),
              value: _summonAllPlayers,
              onChanged: (v) {
                setState(() {
                  _summonAllPlayers = v;
                  if (v) _selectedPlayersMatch.clear();
                });
              },
            ),
            if (!_summonAllPlayers) ...[
              const Text(
                "Sélectionne les joueurs à convoquer :",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                future: fetchUsersBatch(playerIds),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ViroColors.primary,
                        ),
                      ),
                    );
                  }
                  final docs = userSnap.data!;
                  final users = {
                    for (final doc in docs)
                      doc.id: doc.data() as Map<String, dynamic>,
                  };

                  return Column(
                    children: playerIds.map((id) {
                      final userData = users[id];
                      if (userData == null) return const SizedBox.shrink();
                      final first = (userData['firstName'] as String? ?? "")
                          .trim();
                      final last = (userData['lastName'] as String? ?? "")
                          .trim();
                      final name =
                          "${first.isNotEmpty ? first[0].toUpperCase() + first.substring(1).toLowerCase() : ''} ${last.toUpperCase()}"
                              .trim();
                      final avatar = effectiveAvatarUrl(userData);
                      final checked = _selectedPlayersMatch.contains(id);
                      return CheckboxListTile(
                        dense: true,
                        secondary: CircleAvatar(
                          radius: 14,
                          backgroundImage: (avatar != null && avatar.isNotEmpty)
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: (avatar == null || avatar.isEmpty)
                              ? const Icon(Icons.person, size: 14)
                              : null,
                        ),
                        title: Text(name),
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedPlayersMatch.add(id);
                            } else {
                              _selectedPlayersMatch.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        );
      },
    );
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
    final doc = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .get();
    if (!mounted) return;
    final data = doc.data();
    final sport = data?['sport'] as String?;
    final clubAddress = data?['address'] as String?;

    // Charger la date de fin de saison
    final seasonEndTimestamp = data?['seasonEndDate'] as Timestamp?;
    if (seasonEndTimestamp != null) {
      if (mounted) {
        setState(() => _seasonEndDate = seasonEndTimestamp.toDate());
      }
    } else {
      // Valeur par défaut si non définie
      final now = DateTime.now();
      if (mounted) {
        setState(() => _seasonEndDate = DateTime(now.year, 7, 31, 23, 59));
      }
    }

    if (_locationController.text == "Stade du club") {
      if (clubAddress != null && clubAddress.isNotEmpty) {
        if (mounted) {
          setState(() => _locationController.text = clubAddress);
        }
      } else {
        if (mounted) {
          setState(
            () => _locationController.text = _defaultLocationForSport(sport),
          );
        }
      }
    }
  }

  String _defaultLocationForSport(String? sport) {
    if (sport == null) return "Lieu du club";
    final s = sport.toLowerCase();
    if (s.contains("basket") || s.contains("hand") || s.contains("volley")) {
      return "Gymnase du club";
    }
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
                      if (_selectedType != 'Match') {
                        _summonAllPlayers = true;
                        _selectedPlayersMatch.clear();
                      }
                      if (_selectedType == 'Match') {
                        _weeksCount = 1;
                        _meetingLocationController.text =
                            _locationController.text;
                      }
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
                    stream: appFirestore
                        .collection(FirebaseCollections.clubs)
                        .doc(widget.clubId)
                        .collection(FirebaseCollections.teams)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      var teams = snap.data!.docs.toList()
                        ..sort((a, b) {
                          final nameA = (a['name'] as String?) ?? '';
                          final nameB = (b['name'] as String?) ?? '';
                          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
                        });
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
                          .toList()
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                      if (_selectedType == 'Entraînement' ||
                          _selectedType == 'Match') {
                        return _buildDropdown<String>(
                          label: "Équipe concernée",
                          value: _selectedTeamName,
                          hint: "Choisir une équipe",
                          items: teams.map((t) => t['name'] as String).toList(),
                          onChanged: (val) => setState(() {
                            _selectedTeamName = val;
                            _selectedPlayersMatch.clear();
                            _summonAllPlayers = true;
                          }),
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

                  if (_selectedType == 'Match' && _selectedTeamName != null)
                    _buildMatchPlayersSelector(),

                  TextFormField(
                    controller: _locationController,
                    decoration: _inputDecoration(
                      _selectedType == 'Match' ? "Lieu du match" : "Lieu",
                      Icons.location_on_outlined,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimePicker(
                          label: _selectedType == 'Match'
                              ? "Jour du match"
                              : "Jour",
                          value: () {
                            final s = DateFormat(
                              'EEEE dd/MM/yyyy',
                              'fr_FR',
                            ).format(_date);
                            return s[0].toUpperCase() + s.substring(1);
                          }(),
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
                            label: _selectedType == 'Match'
                                ? "Heure du match"
                                : "Début",
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

                  if (_selectedType == 'Match') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _meetingLocationController,
                      decoration: _inputDecoration(
                        "Lieu du RDV",
                        Icons.place_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePicker(
                            label: "Heure du RDV (même jour que le match)",
                            value: _rdvTime.format(context),
                            onTap: _pickRdvTime,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_selectedType == 'Entraînement') ...[
                    const Divider(height: 40),
                    SwitchListTile(
                      title: const Text(
                        "Récurrence hebdomadaire",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _isRecurring,
                      onChanged: (val) => setState(() {
                        _isRecurring = val;
                        if (!val) {
                          _recurrenceMode = 'weeks';
                        }
                      }),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text("Nombre de semaines"),
                        value: 'weeks',
                        groupValue: _recurrenceMode,
                        onChanged: (val) => setState(() {
                          _recurrenceMode = val!;
                        }),
                      ),
                      RadioListTile<String>(
                        title: Text(
                          _seasonEndDate != null
                              ? "Jusqu'à la fin de saison (${DateFormat('dd/MM/yyyy', 'fr_FR').format(_seasonEndDate!)})"
                              : "Jusqu'à la fin de saison",
                        ),
                        value: 'season_end',
                        groupValue: _recurrenceMode,
                        onChanged: (val) => setState(() {
                          _recurrenceMode = val!;
                        }),
                      ),
                      if (_recurrenceMode == 'weeks') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _buildDropdown<int>(
                            label: "Nombre de semaines",
                            value: _weeksCount,
                            items: List.generate(24, (i) => i + 2), // 2 à 25
                            onChanged: (val) =>
                                setState(() => _weeksCount = val!),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 8,
                            bottom: 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ViroColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ViroColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: ViroColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    () {
                                      final lastDate = _date.add(
                                        Duration(days: (_weeksCount - 1) * 7),
                                      );
                                      final s = DateFormat(
                                        'EEEE d MMMM yyyy',
                                        'fr_FR',
                                      ).format(lastDate);
                                      final formattedDate =
                                          s[0].toUpperCase() + s.substring(1);
                                      return "Les entraînements seront créés jusqu'au $formattedDate";
                                    }(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ViroColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_recurrenceMode == 'season_end' &&
                          _seasonEndDate != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ViroColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ViroColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: ViroColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Les entraînements seront créés jusqu'au ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_seasonEndDate!)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ViroColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],

                  const Divider(height: 40),
                  Text(
                    _selectedType == 'Entraînement' || _selectedType == 'Match'
                        ? "Notifications de présence"
                        : "Notifications de l'événement",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedType == 'Entraînement' || _selectedType == 'Match'
                        ? "0, 1 ou 2 notifications pour demander de donner sa présence (max 10 jours avant ou jour de la semaine avant)."
                        : "0, 1 ou 2 notifications pour annoncer l'événement (max 10 jours avant ou jour de la semaine avant).",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text("Aucune")),
                      ButtonSegment(value: 1, label: Text("1 notif")),
                      ButtonSegment(value: 2, label: Text("2 notifs")),
                    ],
                    selected: {_reminderCount},
                    onSelectionChanged: (s) =>
                        setState(() => _reminderCount = s.first),
                  ),
                  if (_reminderCount >= 1) ...[
                    const SizedBox(height: 16),
                    _buildReminder1Fields(),
                  ],
                  if (_reminderCount >= 2) ...[
                    const SizedBox(height: 12),
                    _buildReminder2Fields(),
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
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          int newEndHour = (_startTime.hour + 2) % 24;
          _endTime = TimeOfDay(hour: newEndHour, minute: _startTime.minute);
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickRdvTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _rdvTime,
    );
    if (picked != null) setState(() => _rdvTime = picked);
  }

  Future<void> _pickReminder1Time() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder1Time,
    );
    if (picked != null) setState(() => _reminder1Time = picked);
  }

  Future<void> _pickReminder2Time() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder2Time,
    );
    if (picked != null) setState(() => _reminder2Time = picked);
  }

  static const List<String> _weekdayLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  /// Calcule la date d'envoi pour le premier événement (ex. pour afficher un exemple).
  DateTime _getReminderExampleSendDate(
    bool useWeekday,
    int weekday,
    int daysBefore,
  ) {
    final eventDate = DateTime(_date.year, _date.month, _date.day);
    if (useWeekday) {
      int diff = eventDate.weekday - weekday;
      if (diff <= 0) diff += 7;
      return eventDate.subtract(Duration(days: diff));
    }
    return eventDate.subtract(Duration(days: daysBefore));
  }

  /// Texte d'exemple "Exemple : notif X sera envoyée le [jour] [date] à [heure]h".
  String _getReminderExampleText(int reminderIndex) {
    final useWeekday = reminderIndex == 1
        ? _reminder1UseWeekday
        : _reminder2UseWeekday;
    final weekday = reminderIndex == 1 ? _reminder1Weekday : _reminder2Weekday;
    final daysBefore = reminderIndex == 1
        ? _reminder1DaysBefore
        : _reminder2DaysBefore;
    final time = reminderIndex == 1 ? _reminder1Time : _reminder2Time;
    final sendDate = _getReminderExampleSendDate(
      useWeekday,
      weekday,
      daysBefore,
    );
    final dayName = _weekdayLabels[sendDate.weekday - 1];
    final dateStr = DateFormat('d MMMM', 'fr_FR').format(sendDate);
    final timeStr = time.minute > 0
        ? '${time.hour}h${time.minute.toString().padLeft(2, '0')}'
        : '${time.hour}h';
    return 'Exemple : notif $reminderIndex sera envoyée le $dayName $dateStr à $timeStr';
  }

  Widget _buildReminder1Fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Notification 1",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text("Jour de la semaine")),
                  ButtonSegment(value: false, label: Text("Jours avant")),
                ],
                selected: {_reminder1UseWeekday},
                onSelectionChanged: (s) =>
                    setState(() => _reminder1UseWeekday = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_reminder1UseWeekday)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              initialValue: _reminder1Weekday,
              decoration: _reminderFieldDecoration(
                "Le jour avant l'événement",
                Icons.calendar_today_outlined,
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text(_weekdayLabels[i]),
                ),
              ),
              onChanged: (v) => setState(() => _reminder1Weekday = v ?? 7),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              initialValue: _reminder1DaysBefore,
              decoration: _reminderFieldDecoration(
                "Jours avant l'événement",
                Icons.layers_outlined,
              ),
              items: List.generate(
                10,
                (i) => DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text('${i + 1}'),
                ),
              ),
              onChanged: (v) => setState(() => _reminder1DaysBefore = v ?? 1),
            ),
          ),
        _buildDateTimePicker(
          label: "Heure d'envoi",
          value: _reminder1Time.format(context),
          onTap: _pickReminder1Time,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ViroColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ViroColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ViroColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getReminderExampleText(1),
                    style: TextStyle(
                      fontSize: 12,
                      color: ViroColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedType == 'Évènement' || _selectedType == 'Autre') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _reminder1MessageController,
            decoration: _reminderFieldDecoration(
              "Texte de la notification (optionnel)",
              Icons.message_outlined,
            ),
            maxLength: 100,
          ),
        ],
      ],
    );
  }

  Widget _buildReminder2Fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Notification 2",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text("Jour de la semaine")),
                  ButtonSegment(value: false, label: Text("Jours avant")),
                ],
                selected: {_reminder2UseWeekday},
                onSelectionChanged: (s) =>
                    setState(() => _reminder2UseWeekday = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_reminder2UseWeekday)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              initialValue: _reminder2Weekday,
              decoration: _reminderFieldDecoration(
                "Le jour avant l'événement",
                Icons.calendar_today_outlined,
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text(_weekdayLabels[i]),
                ),
              ),
              onChanged: (v) => setState(() => _reminder2Weekday = v ?? 7),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              initialValue: _reminder2DaysBefore,
              decoration: _reminderFieldDecoration(
                "Jours avant l'événement",
                Icons.layers_outlined,
              ),
              items: List.generate(
                10,
                (i) => DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text('${i + 1}'),
                ),
              ),
              onChanged: (v) => setState(() => _reminder2DaysBefore = v ?? 2),
            ),
          ),
        _buildDateTimePicker(
          label: "Heure d'envoi",
          value: _reminder2Time.format(context),
          onTap: _pickReminder2Time,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ViroColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ViroColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ViroColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getReminderExampleText(2),
                    style: TextStyle(
                      fontSize: 12,
                      color: ViroColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedType == 'Évènement' || _selectedType == 'Autre') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _reminder2MessageController,
            decoration: _reminderFieldDecoration(
              "Texte de la notification (optionnel)",
              Icons.message_outlined,
            ),
            maxLength: 100,
          ),
        ],
      ],
    );
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

  /// Décoration identique pour tous les champs des rappels (bordures uniformes).
  InputDecoration _reminderFieldDecoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ViroColors.borderColor),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ViroColors.borderColor),
      enabledBorder: border,
      focusedBorder: border,
      border: border,
    );
  }
}
