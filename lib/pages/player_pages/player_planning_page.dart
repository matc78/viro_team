import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import 'player_event_details_page.dart'; // Importation de ta page de détails player

class PlayerPlanningPage extends StatefulWidget {
  final String clubId;
  const PlayerPlanningPage({super.key, required this.clubId});

  @override
  State<PlayerPlanningPage> createState() => _PlayerPlanningPageState();
}

class _PlayerPlanningPageState extends State<PlayerPlanningPage> {
  DateTime _selectedDate = DateTime.now();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  Map<String, dynamic>? _userData;

  // Liste des jours pour le sélecteur horizontal (14 jours glissants)
  List<DateTime> _getDays() {
    return List.generate(
      14,
      (index) => DateTime.now().add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: ViroLoader(size: 60)));
        }
        _userData = snapshot.data?.data();
        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(
            title: const Text("Mon Planning"),
            centerTitle: true,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildDaySelector(),
              Expanded(child: _buildEventList()),
            ],
          ),
        );
      },
    );
  }

  // --- SÉLECTEUR DE JOURS HORIZONTAL ---
  Widget _buildDaySelector() {
    final days = _getDays();
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, _selectedDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = day),
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? ViroColors.primary : Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected
                      ? ViroColors.primary
                      : ViroColors.borderColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr_FR').format(day).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  // --- LISTE DES ÉVÉNEMENTS (STREAM) ---
  Widget _buildEventList() {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ViroLoader(size: 50));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final events = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final memberIds = (data['teamMemberIds'] as List<dynamic>?) ?? [];
          final teamNames =
              (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
          final teamName = data['teamName'] as String?;
          final eventCategory = data['category'] as String?;

          final userTeams =
              (_userData?['teamNames'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];
          if (userTeams.isEmpty && _userData?['teamName'] is String) {
            userTeams.add(_userData?['teamName'] as String);
          }
          final userCategories =
              (_userData?['categories'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];
          if (userCategories.isEmpty && _userData?['category'] is String) {
            userCategories.add(_userData?['category'] as String);
          }

          final bool inMemberIds =
              memberIds.isNotEmpty && memberIds.contains(_currentUserId);
          final bool matchTeam =
              teamNames.any(userTeams.contains) ||
              (teamName != null && userTeams.contains(teamName));
          final bool matchCat =
              eventCategory != null && userCategories.contains(eventCategory);
          final isConcerned = memberIds.isEmpty
              ? (matchTeam || matchCat)
              : inMemberIds;
          return isConcerned;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final eventDoc = events[index];
            final event = eventDoc.data() as Map<String, dynamic>;
            return _buildEventCard(eventDoc.id, event);
          },
        );
      },
    );
  }

  Widget _buildEventCard(String docId, Map<String, dynamic> data) {
    final type = data['title'] ?? data['type'] ?? "Événement";
    final isAllDay = data['startTime'] == null && data['endTime'] == null;
    final time = isAllDay ? "ALL DAY" : (data['startTime'] ?? "--:--");
    final teamName = data['teamName'] ?? "Club";
    final location = data['location'] ?? "Lieu non défini";
    final bool canceled = data['canceled'] == true;

    // On vérifie le statut de présence du joueur actuel pour afficher un indicateur
    final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
    final myStatus = attendance[_currentUserId] ?? 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: canceled ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          decoration: BoxDecoration(
            color: ViroColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: ViroColors.primary,
              ),
              Text(
                time,
                style: const TextStyle(
                  color: ViroColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                type.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: ViroColors.primary,
                ),
              ),
            ),
            _buildStatusChip(myStatus),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canceled)
              const Text(
                "ANNULÉ",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              teamName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlayerEventDetailsPage(clubId: widget.clubId, eventId: docId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    if (status == 'present') {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'absent') {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.orange;
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun événement prévu",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
