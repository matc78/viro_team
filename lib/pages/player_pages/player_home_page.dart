import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/player_pages/players_teams_page.dart';
import '../../utils/firebase_error_handler.dart';

// Import de tes nouvelles pages
import 'player_pending_page.dart';
import 'player_no_club_page.dart';
import 'player_profil_page.dart';
import 'player_planning_page.dart';
import 'player_event_details_page.dart';
import 'player_infos_page.dart';

import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../widget/profile_switcher_dialog.dart';

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
        if (snapshot.hasError) {
          return Scaffold(
            body: FirebaseErrorHandler.buildErrorWidget(
              context,
              snapshot.error,
            ),
          );
        }
        if (!snapshot.hasData)
          return const Scaffold(body: ViroLoader(size: 80));

        final userData =
            _manualUserData ?? snapshot.data!.data() as Map<String, dynamic>?;
        final bool hasPendingRequest = userData?['hasPendingRequest'] ?? false;
        
        // Utiliser activeContext au lieu de clubId à la racine
        final activeContext = userData?['activeContext'] as Map<String, dynamic>?;
        final String? clubId = activeContext?['clubId'] as String?;
        
        // Fallback pour compatibilité avec ancien système
        final String? legacyClubId = userData?['clubId'] as String?;
        final String? finalClubId = clubId ?? legacyClubId;
        
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
        if (finalClubId != null && finalClubId.isNotEmpty) {
          // Récupérer le nom du club depuis activeContext ou depuis userData
          String? clubName = activeContext?['clubName'] as String?;
          if (clubName == null) {
            // Essayer de récupérer depuis Firestore si nécessaire
            clubName = userData?['clubName'] as String? ?? "Mon Club";
          }
          
          return _buildClubMemberView(
            firstName,
            finalClubId,
            clubName,
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
      appBar: AppBar(
        title: Text("Bonjour, $name"),
        backgroundColor: ViroColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Bouton pour changer de profil
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Changer de profil',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ProfileSwitcherDialog(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(name, userData?['avatarUrl'] as String?),
              const SizedBox(height: 25),

              _buildAnnouncements(clubId, userData),
              const SizedBox(height: 20),

              // Navigation Rapide
              Row(
                children: [
                  _buildMenuCard("Mes Équipes", Icons.group_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerTeamsPage(clubId: clubId),
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

  Widget _buildAnnouncements(String clubId, Map<String, dynamic>? userData) {
    final List<String> userTeamIds =
        (userData?['teamIds'] as List?)?.whereType<String>().toList() ?? [];
    final List<String> userTeamNames =
        (userData?['teamNames'] as List?)?.whereType<String>().toList() ?? [];
    final List<String> userCategories =
        (userData?['categories'] as List?)?.whereType<String>().toList() ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetType = data['targetType'] as String? ?? '';
          final targets =
              (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
          final durationDays = data['durationDays'] as int?;
          final Timestamp? createdTs = data['createdAt'] as Timestamp?;
          if (createdTs != null && durationDays != null) {
            final expires = createdTs.toDate().add(
              Duration(days: durationDays),
            );
            if (expires.isBefore(now)) return false;
          }

          if (targets.isEmpty) return true; // diffusion générale
          switch (targetType) {
            case 'Joueurs':
              return targets.contains(_currentUserId);
            case 'Équipes':
              return targets.any(
                    (t) => userTeamIds.contains(t) || userTeamNames.contains(t),
                  ) ||
                  (userTeamIds.isEmpty && userTeamNames.isEmpty);
            case 'Catégories':
              return targets.any(userCategories.contains);
            default:
              return false;
          }
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ViroColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ViroColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.campaign_rounded, color: ViroColors.primary),
                  SizedBox(width: 8),
                  Text(
                    "Message(s) du club",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...docs.take(3).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final created = (data['createdAt'] as Timestamp?)
                    ?.toDate()
                    .toLocal();
                final senderId = data['senderId'] as String?;
                final dateLabel = created != null
                    ? DateFormat('dd/MM à HH:mm').format(created)
                    : '';
                return Padding(
                  key: ValueKey(doc.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dateLabel.isNotEmpty)
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        data['message'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (senderId != null) ...[
                        const SizedBox(height: 4),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(senderId)
                              .get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData ||
                                !(userSnap.data?.exists ?? false)) {
                              return const SizedBox.shrink();
                            }
                            final uData =
                                userSnap.data!.data() as Map<String, dynamic>?;
                            final senderName = _formatName(
                              uData?['firstName'] as String?,
                              uData?['lastName'] as String?,
                            );
                            if (senderName.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              "Par $senderName",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatName(String? first, String? last) {
    final f = (first ?? "").trim();
    final l = (last ?? "").trim();
    final fFormatted = f.isEmpty
        ? ""
        : "${f[0].toUpperCase()}${f.length > 1 ? f.substring(1).toLowerCase() : ""}";
    final lFormatted = l.isEmpty ? "" : l.toUpperCase();
    return [fFormatted, lFormatted].where((s) => s.isNotEmpty).join(" ").trim();
  }

  Widget _buildHeader(String name, String? avatarUrl) {
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
          child: CircleAvatar(
            backgroundColor: ViroColors.primary,
            radius: 22,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
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
                  key: ValueKey(doc.id),
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
                  key: ValueKey(doc.id),
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

  Widget _eventSmallTile(String id, Map<String, dynamic> data, String clubId, {Key? key}) {
    final isAllDay = data['startTime'] == null && data['endTime'] == null;
    final timeLabel = isAllDay ? "ALL DAY" : (data['startTime'] ?? "--:--");
    final typeLabel = data['title'] ?? data['type'] ?? "Événement";
    final bool canceled = data['canceled'] == true;
    return Card(
      key: key,
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
    String clubId, {
    Key? key,
  }) {
    final date = (data['date'] as Timestamp).toDate();
    final dateStr = DateFormat('EEEE d', 'fr_FR').format(date);

    return Container(
      key: key,
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
