import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../constants/firebase_collections.dart';
import '../../../../models/tournament/tournament_model.dart';
import '../../../../utils/firestore_instance.dart';

class Step1GeneralInfo extends StatelessWidget {
  final String clubId;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? linkedEventId;
  final TournamentType type;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<String?> onLinkedEventChanged;
  final ValueChanged<TournamentType> onTypeChanged;

  const Step1GeneralInfo({
    super.key,
    required this.clubId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.linkedEventId,
    required this.type,
    required this.formKey,
    required this.onNameChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onLinkedEventChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y', 'fr_FR');

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Nom
          TextFormField(
            initialValue: name,
            decoration: const InputDecoration(
              labelText: 'Nom du tournoi *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 16),

          // Type
          const Text('Type',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          SegmentedButton<TournamentType>(
            segments: const [
              ButtonSegment(
                value: TournamentType.ponctuel,
                label: Text('Tournoi ponctuel'),
                icon: Icon(Icons.emoji_events_outlined),
              ),
              ButtonSegment(
                value: TournamentType.championnat,
                label: Text('Championnat'),
                icon: Icon(Icons.leaderboard_outlined),
              ),
            ],
            selected: {type},
            onSelectionChanged: (s) => onTypeChanged(s.first),
          ),
          const SizedBox(height: 20),

          // Dates
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Date de début *',
                  value: startDate,
                  formatter: dateFmt,
                  onChanged: onStartDateChanged,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Date de fin',
                  value: endDate,
                  formatter: dateFmt,
                  onChanged: onEndDateChanged,
                  firstDate: startDate ?? DateTime(2020),
                  lastDate: DateTime(2100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lien événement (optionnel)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(clubId)
                .collection(FirebaseCollections.events)
                .orderBy('date', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final items = docs.map((d) {
                final data = d.data();
                final title = data['title'] as String? ??
                    data['teamName'] as String? ??
                    d.id;
                return DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(title, overflow: TextOverflow.ellipsis),
                );
              }).toList();

              return DropdownButtonFormField<String>(
                initialValue: linkedEventId,
                decoration: const InputDecoration(
                  labelText: 'Lier à un événement (optionnel)',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Aucun'),
                  ),
                  ...items,
                ],
                onChanged: onLinkedEventChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: (value != null && !value!.isBefore(firstDate))
              ? value
              : firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value != null ? formatter.format(value!) : '',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
