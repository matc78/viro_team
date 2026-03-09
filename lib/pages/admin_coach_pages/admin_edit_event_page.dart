import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firestore_instance.dart';

class AdminEditEventPage extends StatefulWidget {
  final String clubId;
  final String eventId;
  final Map<String, dynamic> eventData;

  const AdminEditEventPage({
    super.key,
    required this.clubId,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<AdminEditEventPage> createState() => _AdminEditEventPageState();
}

class _AdminEditEventPageState extends State<AdminEditEventPage> {
  bool _isLoading = false;

  late String _selectedType;
  late DateTime _originalDate;
  late DateTime _eventDate;
  
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);
  TimeOfDay _rdvTime = const TimeOfDay(hour: 17, minute: 30);
  bool _allDay = false;

  // Rappels
  int _reminderCount = 0;
  bool _reminder1UseWeekday = false;
  int _reminder1Weekday = 7;
  int _reminder1DaysBefore = 1;
  TimeOfDay _reminder1Time = const TimeOfDay(hour: 16, minute: 0);
  final _reminder1MessageController = TextEditingController();

  bool _reminder2UseWeekday = false;
  int _reminder2Weekday = 7;
  int _reminder2DaysBefore = 2;
  TimeOfDay _reminder2Time = const TimeOfDay(hour: 18, minute: 30);
  final _reminder2MessageController = TextEditingController();

  static const List<String> _weekdayLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.eventData['type'] ?? 'Évènement';
    final timestamp = widget.eventData['date'] as Timestamp?;
    _originalDate = timestamp?.toDate() ?? DateTime.now();
    _eventDate = _originalDate;

    _allDay = widget.eventData['startTime'] == null && widget.eventData['endTime'] == null;
    if (widget.eventData['startTime'] != null) {
      _startTime = _parseTimeOfDay(widget.eventData['startTime']);
    }
    if (widget.eventData['endTime'] != null) {
      _endTime = _parseTimeOfDay(widget.eventData['endTime']);
    }
    if (widget.eventData['meetingTime'] != null) {
      _rdvTime = _parseTimeOfDay(widget.eventData['meetingTime']);
    }

    _initReminders();
  }

  TimeOfDay _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 12, minute: 0);
    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 12;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _reminder1MessageController.dispose();
    _reminder2MessageController.dispose();
    super.dispose();
  }

  void _initReminders() {
    final reminderConfig =
        widget.eventData['reminderConfig'] as Map<String, dynamic>?;
    if (reminderConfig == null) {
      _reminderCount = 0;
      return;
    }
    final reminders = reminderConfig['reminders'] as List<dynamic>? ?? [];
    _reminderCount = reminders.length;

    if (_reminderCount >= 1) {
      final r1 = reminders[0] as Map<String, dynamic>;
      _parseReminder(r1, 1);
    }
    if (_reminderCount >= 2) {
      final r2 = reminders[1] as Map<String, dynamic>;
      _parseReminder(r2, 2);
    }
  }

  void _parseReminder(Map<String, dynamic> r, int index) {
    final timeStr = r['time'] as String? ?? '12:00';
    final parts = timeStr.split(':');
    final time = TimeOfDay(
      hour: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 12 : 12,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final msg = r['message'] as String? ?? '';

    if (index == 1) {
      _reminder1Time = time;
      _reminder1MessageController.text = msg;
      if (r['weekday'] != null) {
        _reminder1UseWeekday = true;
        _reminder1Weekday = (r['weekday'] as num).toInt();
      } else if (r['daysBefore'] != null) {
        _reminder1UseWeekday = false;
        _reminder1DaysBefore = (r['daysBefore'] as num).toInt();
      }
    } else {
      _reminder2Time = time;
      _reminder2MessageController.text = msg;
      if (r['weekday'] != null) {
        _reminder2UseWeekday = true;
        _reminder2Weekday = (r['weekday'] as num).toInt();
      } else if (r['daysBefore'] != null) {
        _reminder2UseWeekday = false;
        _reminder2DaysBefore = (r['daysBefore'] as num).toInt();
      }
    }
  }

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

  Future<void> _saveChanges() async {
    if (!_allDay && _selectedType != 'Match') {
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("L'heure de fin doit être après l'heure de début")),
        );
        return;
      }
    }

    final seriesId = widget.eventData['seriesId'] as String?;

    if (seriesId != null && seriesId.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Modifier les événements"),
          content: const Text(
            "Cet événement fait partie d'une série. Voulez-vous modifier uniquement cet événement, ou également tous les événements futurs de cette série ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'single'),
              child: const Text("Seulement cet événement"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'series'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ViroColors.primary,
              ),
              child: const Text(
                "Toute la série future",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;
      await _executeSave(updateSeries: choice == 'series', seriesId: seriesId);
    } else {
      await _executeSave(updateSeries: false);
    }
  }

  Future<void> _executeSave({
    required bool updateSeries,
    String? seriesId,
  }) async {
    setState(() => _isLoading = true);
    try {
      final reminderConfig = _buildReminderConfig();
      
      final startStr = _allDay ? null : _startTime.format(context);
      final endStr = (_selectedType == 'Match' || _allDay) ? null : _endTime.format(context);
      final meetingStr = _selectedType == 'Match' ? _rdvTime.format(context) : null;

      final updateData = <String, dynamic>{
        if (reminderConfig != null)
          'reminderConfig': reminderConfig
        else
          'reminderConfig': FieldValue.delete(),
        'startTime': startStr,
        'endTime': endStr,
        if (_selectedType == 'Match') 'meetingTime': meetingStr,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!updateSeries) {
        updateData['date'] = Timestamp.fromDate(_eventDate);
        updateData['dateId'] = DateFormat('yyyyMMdd').format(_eventDate);

        await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.events)
            .doc(widget.eventId)
            .update(updateData);
      } else {
        // Récupérer tous les événements de la série, puis filtrer en mémoire
        // pour éviter de nécessiter un index composite (seriesId + date).
        final snap = await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.events)
            .where('seriesId', isEqualTo: seriesId)
            .get();

        final batch = appFirestore.batch();
        final targetDate = (widget.eventData['date'] as Timestamp).toDate();
        
        final originalDateOnly = DateTime(_originalDate.year, _originalDate.month, _originalDate.day);
        final newDateOnly = DateTime(_eventDate.year, _eventDate.month, _eventDate.day);
        final daysDiff = newDateOnly.difference(originalDateOnly).inDays;

        for (var doc in snap.docs) {
          final eventDate = (doc.data()['date'] as Timestamp?)?.toDate();
          if (eventDate != null &&
              (eventDate.isAfter(targetDate) ||
                  eventDate.isAtSameMomentAs(targetDate))) {
                  
            final docUpdate = Map<String, dynamic>.from(updateData);
            if (daysDiff != 0) {
              final newDocDate = eventDate.add(Duration(days: daysDiff));
              docUpdate['date'] = Timestamp.fromDate(newDocDate);
              docUpdate['dateId'] = DateFormat('yyyyMMdd').format(newDocDate);
            }
            
            batch.update(doc.reference, docUpdate);
          }
        }
        await batch.commit();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppLogger.instance.error('Erreur édition événement', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPERS UI RAPPELS (SIMILAIRES A ADD_EVENT) ---

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

  DateTime _getReminderExampleSendDate(
    bool useWeekday,
    int weekday,
    int daysBefore,
  ) {
    final eventDate = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
    );
    if (useWeekday) {
      int diff = eventDate.weekday - weekday;
      if (diff <= 0) diff += 7;
      return eventDate.subtract(Duration(days: diff));
    }
    return eventDate.subtract(Duration(days: daysBefore));
  }

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
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _reminder1Time,
            );
            if (picked != null) setState(() => _reminder1Time = picked);
          },
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
                const Icon(
                  Icons.info_outline,
                  color: ViroColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getReminderExampleText(1),
                    style: const TextStyle(
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
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _reminder2Time,
            );
            if (picked != null) setState(() => _reminder2Time = picked);
          },
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
                const Icon(
                  Icons.info_outline,
                  color: ViroColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getReminderExampleText(2),
                    style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Éditer l'événement")),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ViroColors.primary),
            )
          : Form(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    "Date et Heure",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimePicker(
                          label: _selectedType == 'Match' ? "Jour du match" : "Jour",
                          value: () {
                            final s = DateFormat('EEEE dd/MM/yyyy', 'fr_FR').format(_eventDate);
                            return s[0].toUpperCase() + s.substring(1);
                          }(),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _eventDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _eventDate = picked);
                          },
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
                      contentPadding: EdgeInsets.zero,
                    ),
                  if (!_allDay)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePicker(
                            label: _selectedType == 'Match' ? "Heure du match" : "Début",
                            value: _startTime.format(context),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  _startTime = picked;
                                  int newEndHour = (_startTime.hour + 2) % 24;
                                  _endTime = TimeOfDay(hour: newEndHour, minute: _startTime.minute);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_selectedType != 'Match')
                          Expanded(
                            child: _buildDateTimePicker(
                              label: "Fin",
                              value: _endTime.format(context),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _endTime,
                                );
                                if (picked != null) setState(() => _endTime = picked);
                              },
                            ),
                          ),
                      ],
                    ),
                  if (_selectedType == 'Match') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePicker(
                            label: "Heure du RDV (même jour que le match)",
                            value: _rdvTime.format(context),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _rdvTime,
                              );
                              if (picked != null) setState(() => _rdvTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
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
                    onPressed: _saveChanges,
                    child: const Text(
                      "ENREGISTRER LES MODIFICATIONS",
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
}
