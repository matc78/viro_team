import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class AdminEventDetailsPage extends StatelessWidget {
  final String clubId;
  final String eventId;

  const AdminEventDetailsPage({
    super.key,
    required this.clubId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .doc(eventId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: ViroLoader(size: 60)));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Évènement introuvable")),
          );
        }

        final event = snapshot.data!.data() as Map<String, dynamic>;
        final String type = event['type'] ?? "Évènement";
        final String team = event['teamName'] ?? "Équipe";
        final String location = event['location'] ?? "Non défini";
        final Timestamp? timestamp = event['date'];
        final DateTime date = timestamp?.toDate() ?? DateTime.now();
        final List<String> categories =
            (event['categories'] as List?)?.whereType<String>().toList() ?? [];

        // Récupération de l'attendance et de la liste des IDs membres
        final Map<String, dynamic> attendance = Map<String, dynamic>.from(
          event['attendance'] ?? {},
        );
        final List<dynamic> teamMembers = event['teamMemberIds'] ?? [];

        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(title: Text(type), elevation: 0),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER INFO ---
                _buildEventHeader(date, event, team, categories),

                // --- INFOS PRATIQUES ---
                _buildInfoSection(location, event),

                // --- STATISTIQUES ---
                _buildAttendanceSummary(attendance),

                // --- LISTES DES JOUEURS ---
                _buildAttendanceTabs(attendance, teamMembers),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventHeader(
    DateTime date,
    Map<String, dynamic> event,
    String team,
    List<String> categories,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE d MMMM', 'fr_FR').format(date).toUpperCase(),
            style: const TextStyle(
              color: ViroColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            team,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (event['title'] != null && event['title'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                event['title'],
                style: const TextStyle(fontSize: 18, color: ViroColors.primary),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            "Catégorie : ${_formatCategories(categories, event['category'])}",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String location, Map<String, dynamic> event) {
    final startTime = event['startTime'];
    final endTime = event['endTime'];
    final bool allDay = startTime == null && endTime == null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.access_time_rounded,
            "Horaire",
            allDay
                ? "Toute la journée"
                : "${startTime ?? '--:--'} - ${endTime ?? '--:--'}",
          ),
          const Divider(height: 30),
          _infoRow(Icons.location_on_outlined, "Lieu", location),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: ViroColors.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceSummary(Map<String, dynamic> attendance) {
    int present = attendance.values.where((v) => v == 'present').length;
    int absent = attendance.values.where((v) => v == 'absent').length;
    int total = attendance.length;
    int noResponse = total - (present + absent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statBadge("PRÉSENTS", present, ViroColors.primary),
          const SizedBox(width: 10),
          _statBadge("ABSENTS", absent, Colors.redAccent),
          const SizedBox(width: 10),
          _statBadge("SANS RÉPONSE", noResponse, Colors.orange),
        ],
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTabs(
    Map<String, dynamic> attendance,
    List<dynamic> teamMembers,
  ) {
    // 1. Préparation de la liste complète
    final Map<String, dynamic> fullList = Map.from(attendance);
    for (var id in teamMembers) {
      if (!fullList.containsKey(id)) {
        fullList[id] = 'none';
      }
    }

    // 2. Logique de tri extraite pour la clarté
    final sortedEntries = fullList.entries.toList();
    sortedEntries.sort((a, b) {
      int score(String v) {
        if (v == 'present') return 0;
        if (v == 'absent') return 1;
        return 2;
      }

      final sa = score(a.value as String? ?? 'none');
      final sb = score(b.value as String? ?? 'none');

      if (sa != sb) return sa.compareTo(sb);
      return (a.key).compareTo(b.key); // Tri par ID si statut identique
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DÉTAILS DES PRÉSENCES",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (sortedEntries.isEmpty)
            const Center(child: Text("Aucun joueur convoqué"))
          else
            ...sortedEntries.map(
              (entry) => _buildPlayerTile(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  String _formatCategories(List<String> categories, dynamic single) {
    if (categories.isNotEmpty) {
      return categories.join(", ");
    }
    return single?.toString() ?? 'N/A';
  }

  Widget _buildPlayerTile(String userId, dynamic status) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final user = snap.data!.data() as Map<String, dynamic>?;
        if (user == null) return const SizedBox();

        Color statusColor = status == 'present'
            ? ViroColors.primary
            : (status == 'absent' ? Colors.red : Colors.orange);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ViroColors.borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ViroColors.primary.withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  size: 18,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${user['firstName']} ${user['lastName']}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'present'
                      ? "Présent"
                      : (status == 'absent' ? "Absent" : "En attente"),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
