import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_add_event_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_event_details_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class AdminPlanningPage extends StatefulWidget {
  final String clubId;
  const AdminPlanningPage({super.key, required this.clubId});

  @override
  State<AdminPlanningPage> createState() => _AdminPlanningPageState();
}

class _AdminPlanningPageState extends State<AdminPlanningPage> {
  DateTime _selectedDate = DateTime.now();
  String _filterTeam = "Choisir une équipe";
  String _filterCategory = "Choisir une catégorie";
  bool _deleteMode = false;

  // Liste des jours pour le sélecteur horizontal (7 jours glissants)
  List<DateTime> _getDays() {
    return List.generate(
      14,
      (index) => DateTime.now().add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Planning du Club"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _deleteMode ? Icons.close : Icons.edit,
              color: _deleteMode ? Colors.redAccent : null,
            ),
            onPressed: () => setState(() => _deleteMode = !_deleteMode),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SÉLECTEUR DE JOUR HORIZONTAL
          _buildDayPicker(),

          // 2. FILTRES (ÉQUIPE & CATÉGORIE)
          _buildFilters(),

          // 3. LISTE DES ÉVÉNEMENTS
          Expanded(child: _buildEventList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: ViroColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDayPicker() {
    final days = _getDays();
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? ViroColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ViroColors.borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr_FR').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('teams')
          .snapshots(),
      builder: (context, snapshot) {
        final teamNames = <String>{"Choisir une équipe"};
        final categories = <String>{"Choisir une catégorie"};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final teamName = data['name'] as String?;
            final category = data['category'] as String?;
            if (teamName != null && teamName.isNotEmpty)
              teamNames.add(teamName);
            if (category != null && category.isNotEmpty)
              categories.add(category);
          }
        }

        final teamsList = teamNames.toList();
        final catList = categories.toList();

        final teamValue = teamsList.contains(_filterTeam)
            ? _filterTeam
            : "Choisir une équipe";
        final catValue = catList.contains(_filterCategory)
            ? _filterCategory
            : "Choisir une catégorie";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: "Équipe",
                  value: teamValue,
                  items: teamsList,
                  onChanged: (val) => setState(() => _filterTeam = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  label: "Catégorie",
                  value: catValue,
                  items: catList,
                  onChanged: (val) => setState(() => _filterCategory = val!),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEventList() {
    String dateId = DateFormat('yyyyMMdd').format(_selectedDate);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('events')
          .where('dateId', isEqualTo: dateId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ViroLoader(size: 40));

        var docs = snapshot.data!.docs;

        // Filtrage manuel (plus simple pour les filtres multiples combinés)
        var filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final bool placeholderTeam = _filterTeam.startsWith(
            "Choisir",
          ); // pas de filtre
          final bool placeholderCat = _filterCategory.startsWith(
            "Choisir",
          ); // pas de filtre
          final teamNames =
              (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
          final lcFilterTeam = _normalize(_filterTeam);
          bool matchTeam =
              placeholderTeam ||
              _normalize(data['teamName'] ?? '') == lcFilterTeam ||
              teamNames.any((name) => _normalize(name).contains(lcFilterTeam));
          final eventCategory = (data['category'] as String?) ?? "";
          final lcFilterCat = _normalize(_filterCategory);
          bool matchCat =
              placeholderCat ||
              _normalize(eventCategory) == lcFilterCat ||
              teamNames.any((name) => _normalize(name).contains(lcFilterCat));
          return matchTeam && matchCat;
        }).toList();

        filteredDocs.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final bool aAllDay = da['startTime'] == null && da['endTime'] == null;
          final bool bAllDay = db['startTime'] == null && db['endTime'] == null;
          if (aAllDay && !bAllDay) return -1;
          if (!aAllDay && bAllDay) return 1;
          return _timeToMinutes(
            da['startTime'],
          ).compareTo(_timeToMinutes(db['startTime']));
        });

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("Aucun événement prévu ce jour."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final docId = filteredDocs[index].id;
            return GestureDetector(
              onTap: () => _deleteMode ? _onEventTap(docId, data) : null,
              child: InkWell(
                onTap: () {
                  if (_deleteMode) {
                    _onEventTap(docId, data);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminEventDetailsPage(
                          clubId: widget.clubId,
                          eventId: docId,
                        ),
                      ),
                    );
                  }
                },
                child: _buildEventCard(data, editing: _deleteMode),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data, {bool editing = false}) {
    final bool canceled = data['canceled'] == true;
    final bool isMatch = data['type'] == 'Match';
    Color typeColor = _getTypeColor(data['type']);
    final Map<String, dynamic> attendance =
        Map<String, dynamic>.from(data['attendance'] ?? {});
    int presentCount =
        attendance.values.where((v) => v == 'present').length;
    int absentCount = attendance.values.where((v) => v == 'absent').length;
    // fallback sur anciennes listes si map vide
    if (presentCount == 0 && absentCount == 0) {
      presentCount = _countList(data['presentIds']);
      absentCount = _countList(data['absentIds']);
    }
    final int totalResponded = presentCount + absentCount;
    final int totalUnknown = _countList(data['teamMemberIds']) > 0
        ? (_countList(data['teamMemberIds']) - totalResponded).clamp(0, 9999)
        : 0;
    final bool allDay = data['startTime'] == null && data['endTime'] == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canceled ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          if (editing)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.redAccent.withOpacity(0.9),
                child: const Icon(Icons.remove, color: Colors.white, size: 18),
              ),
            ),
          Column(
            children: [
              Text(
                isMatch
                    ? "RDV"
                    : (allDay ? "ALL" : (data['startTime'] ?? "--:--")),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
              Text(
                isMatch
                    ? (data['startTime'] ?? "--:--")
                    : (allDay ? "DAY" : (data['endTime'] ?? "--:--")),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canceled)
                  const Text(
                    "ANNULÉ",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  (data['title'] ?? data['type']).toUpperCase(),
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _truncate(_audienceText(data)),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _truncate(data['location'] ?? "Stade du club"),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!editing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up, size: 16, color: ViroColors.primary),
                const SizedBox(width: 4),
                Text(
                  "$presentCount",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.thumb_down, size: 16, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  "$absentCount",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.help_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  "$totalUnknown",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Entraînement':
        return Colors.blue;
      case 'Match':
        return Colors.orange;
      case 'Évènement':
        return Colors.purple;
      default:
        return Colors.yellow;
    }
  }

  int _timeToMinutes(dynamic time) {
    if (time == null) return 0;
    final str = time.toString();
    try {
      final parsed = DateFormat.jm('en_US').parse(str);
      return parsed.hour * 60 + parsed.minute;
    } catch (_) {
      return 0;
    }
  }

  int _countList(dynamic list) {
    if (list is List) return list.length;
    return 0;
  }

  String _normalize(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[ûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .trim();
  }

  Future<void> _onEventTap(String docId, Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';
    final canCancelAll = type == 'Entraînement';
    _showCancelOptions(docId, data, canCancelAll: canCancelAll);
  }

  void _showCancelOptions(
    String docId,
    Map<String, dynamic> data, {
    required bool canCancelAll,
  }) {
    final canceled = data['canceled'] == true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canceled) ...[
              ListTile(
                leading: const Icon(Icons.event_busy, color: Colors.redAccent),
                title: const Text("Annuler cet évènement"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _cancelSingle(docId);
                },
              ),
              if (canCancelAll)
                ListTile(
                  leading: const Icon(Icons.repeat, color: Colors.orange),
                  title: const Text("Annuler toutes les occurrences"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _cancelRecurring(data);
                  },
                ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.green),
                title: const Text("Désannuler cet évènement"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _uncancelSingle(docId);
                },
              ),
              if (canCancelAll)
                ListTile(
                  leading: const Icon(Icons.repeat, color: Colors.green),
                  title: const Text("Désannuler toutes les occurrences"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _uncancelRecurring(data);
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Supprimer définitivement"),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteEvent(docId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSingle(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events')
        .doc(docId)
        .set({'canceled': true}, SetOptions(merge: true));
  }

  Future<void> _cancelRecurring(Map<String, dynamic> data) async {
    final team = data['teamName'];
    final type = data['type'];
    final startTime = data['startTime'];
    final query = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events')
        .where('teamName', isEqualTo: team)
        .where('type', isEqualTo: type)
        .where('startTime', isEqualTo: startTime)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.set(doc.reference, {'canceled': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _uncancelSingle(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events')
        .doc(docId)
        .set({'canceled': false}, SetOptions(merge: true));
  }

  Future<void> _uncancelRecurring(Map<String, dynamic> data) async {
    final team = data['teamName'];
    final type = data['type'];
    final startTime = data['startTime'];
    final query = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events')
        .where('teamName', isEqualTo: team)
        .where('type', isEqualTo: type)
        .where('startTime', isEqualTo: startTime)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.set(doc.reference, {'canceled': false}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _deleteEvent(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events')
        .doc(docId)
        .delete();
  }

  // --- LOGIQUE AJOUT ÉVÉNEMENT ---
  void _showAddEventDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAddEventPage(clubId: widget.clubId),
      ),
    );
  }

  String _truncate(String text, {int max = 18}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  String _audienceText(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final isTrainingOrMatch = type == 'Entraînement' || type == 'Match';
    final names =
        (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
    final teamName = data['teamName'] as String?;
    if (isTrainingOrMatch) {
      return teamName ?? (names.isNotEmpty ? names.first : 'Équipe');
    }
    if (data['allTeams'] == true) return 'Tout le club';
    if (names.length > 1) return "${names.length} équipes";
    if (names.length == 1) return names.first;
    if (data['category'] != null) return "Tout : ${data['category']}";
    return teamName ?? 'Équipe';
  }
}
