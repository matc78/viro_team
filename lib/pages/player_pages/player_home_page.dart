import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/player_pages/players_teams_page.dart';

// Import de tes nouvelles pages
import 'player_pending_page.dart';
import 'player_no_club_page.dart';
import 'player_profil_page.dart';
import 'player_planning_page.dart';
import 'player_event_details_page.dart';
import 'player_infos_page.dart';

import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class PlayerHomePage extends StatefulWidget {
  const PlayerHomePage({super.key});

  @override
  State<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends State<PlayerHomePage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isManualRefreshing = false;
  Map<String, dynamic>? _manualUserData;

  // --- LOGIQUE DE FLUX ---

  // Force la vérification du statut (utile si l'admin vient de valider)
  Future<void> _refreshUserStatus() async {
    setState(() => _isManualRefreshing = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get(const GetOptions(source: Source.server));
      if (!mounted) return;
      setState(() => _manualUserData = snap.data());
    } finally {
      if (mounted) setState(() => _isManualRefreshing = false);
    }
  }

  // Mise à jour de la présence (pour la vue membre)
  Future<void> _updatePresence(
    String clubId,
    String eventId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .doc(eventId)
          .update({'attendance.$_currentUserId': status});
    } catch (e) {
      debugPrint("Erreur présence: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Scaffold(body: Center(child: Text("Erreur réseau")));
        if (!snapshot.hasData)
          return const Scaffold(body: ViroLoader(size: 80));

        final userData =
            _manualUserData ?? snapshot.data!.data() as Map<String, dynamic>?;
        final bool hasPendingRequest = userData?['hasPendingRequest'] ?? false;
        final String? clubId = userData?['clubId'];
        final String firstName = userData?['firstName'] ?? "Sportif";

        // 1. SI DEMANDE EN ATTENTE
        if (hasPendingRequest) {
          return PlayerPendingPage(
            clubName: userData?['lastClubRequested'] ?? "ton club",
            isRefreshing: _isManualRefreshing,
            onRefresh: _refreshUserStatus,
          );
        }

        // 2. SI MEMBRE D'UN CLUB (VUE NORMALE)
        if (clubId != null && clubId.isNotEmpty) {
          return _buildClubMemberView(
            firstName,
            clubId,
            userData?['clubName'] ?? "Mon Club",
            userData,
          );
        }

        // 3. SI AUCUN CLUB (ET PAS DE DEMANDE)
        return PlayerNoClubPage(firstName: firstName);
      },
    );
  }

  // --- VUE MEMBRE (L'INTERFACE PRINCIPALE) ---

  Widget _buildClubMemberView(
    String name,
    String clubId,
    String clubName,
    Map<String, dynamic>? userData,
  ) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(name),
              const SizedBox(height: 25),

              // Navigation Rapide
              Row(
                children: [
                  _buildMenuCard("Planning", Icons.calendar_today_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerPlanningPage(clubId: clubId),
                      ),
                    );
                  }),
                  const SizedBox(width: 15),
                  _buildMenuCard("Mes Équipes", Icons.group_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerTeamsPage(clubId: clubId),
                      ),
                    );
                  }),
                  const SizedBox(width: 15),
                  _buildMenuCard("Infos", Icons.notifications_none_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerInfosPage(clubId: clubId),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 30),

              _buildSectionTitle("À NE PAS MANQUER AUJOURD'HUI"),
              _buildTodayEvents(clubId, userData),

              const SizedBox(height: 30),

              _buildSectionTitle("ACTION REQUISE : PRÉSENCE"),
              _buildPendingActions(clubId, userData),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(clubId),
    );
  }

  // --- COMPOSANTS DE L'INTERFACE ---

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Salut 👋",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerProfilPage()),
          ),
          child: const CircleAvatar(
            backgroundColor: ViroColors.primary,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayEvents(String clubId, Map<String, dynamic>? userData) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final memberIds = (data['teamMemberIds'] as List<dynamic>?) ?? [];
          final teamNames =
              (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
          final teamName = data['teamName'] as String?;
          final eventCategory = data['category'] as String?;

          final userTeams =
              (_manualUserData?['teamNames'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              (userData?['teamNames'] as List?)?.whereType<String>().toList() ??
              [];
          if (userTeams.isEmpty && _manualUserData?['teamName'] is String) {
            userTeams.add(_manualUserData?['teamName'] as String);
          } else if (userTeams.isEmpty && userData?['teamName'] is String) {
            userTeams.add(userData?['teamName'] as String);
          }
          final userCategories =
              (_manualUserData?['categories'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              (userData?['categories'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];
          if (userCategories.isEmpty &&
              _manualUserData?['category'] is String) {
            userCategories.add(_manualUserData?['category'] as String);
          } else if (userCategories.isEmpty &&
              userData?['category'] is String) {
            userCategories.add(userData?['category'] as String);
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
        if (docs.isEmpty)
          return const Text(
            "Rien de prévu aujourd'hui.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );

        return Column(
          children: docs
              .map(
                (doc) => _eventSmallTile(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                  clubId,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPendingActions(String clubId, Map<String, dynamic>? userData) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final nextSunday = startOfDay.add(Duration(days: 7 - now.weekday + 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(nextSunday))
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final pendingDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final attendance = data['attendance'] as Map? ?? {};
          final memberIds = (data['teamMemberIds'] as List<dynamic>?) ?? [];
          final teamNames =
              (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
          final teamName = data['teamName'] as String?;
          final eventCategory = data['category'] as String?;

          final userTeams =
              (userData?['teamNames'] as List?)?.whereType<String>().toList() ??
              [];
          if (userTeams.isEmpty && userData?['teamName'] is String) {
            userTeams.add(userData?['teamName'] as String);
          }

          final userCategories =
              (userData?['categories'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];
          if (userCategories.isEmpty && userData?['category'] is String) {
            userCategories.add(userData?['category'] as String);
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
          return isConcerned &&
              (attendance[_currentUserId] == null ||
                  attendance[_currentUserId] == 'none');
        }).toList();

        if (pendingDocs.isEmpty)
          return const Text(
            "Tu es à jour ! ✅",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );

        return Column(
          children: pendingDocs
              .map(
                (doc) => _pendingActionCard(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                  clubId,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _eventSmallTile(String id, Map<String, dynamic> data, String clubId) {
    final isAllDay = data['startTime'] == null && data['endTime'] == null;
    final timeLabel = isAllDay ? "ALL DAY" : (data['startTime'] ?? "--:--");
    final typeLabel = data['title'] ?? data['type'] ?? "Événement";
    final bool canceled = data['canceled'] == true;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ViroColors.borderColor),
      ),
      color: canceled ? Colors.grey.shade300 : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ViroColors.secondary,
          child: Text(
            timeLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ViroColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        title: Text(
          typeLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          canceled
              ? "ANNULÉ • ${data['location'] ?? ''}"
              : (data['location'] ?? ""),
          style: TextStyle(
            fontSize: 12,
            color: canceled ? Colors.red : Colors.grey,
            fontWeight: canceled ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerEventDetailsPage(clubId: clubId, eventId: id),
          ),
        ),
      ),
    );
  }

  Widget _pendingActionCard(
    String id,
    Map<String, dynamic> data,
    String clubId,
  ) {
    final date = (data['date'] as Timestamp).toDate();
    final dateStr = DateFormat('EEEE d', 'fr_FR').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['type']?.toUpperCase() ?? "ÉVÉNEMENT",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['teamName'] ?? "Équipe",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updatePresence(clubId, id, 'absent'),
                  child: const Text("ABSENT"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updatePresence(clubId, id, 'present'),
                  child: const Text("PRÉSENT"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ViroColors.borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: ViroColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildBottomNav(String clubId) {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: ViroColors.background,
      selectedItemColor: ViroColors.primary,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerPlanningPage(clubId: clubId),
            ),
          );
        }
        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerInfosPage(clubId: clubId)),
          );
        }
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerProfilPage()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: "Planning",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          label: "Infos",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: "Profil",
        ),
      ],
    );
  }
}
