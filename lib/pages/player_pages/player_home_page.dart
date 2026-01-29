import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/player_pages/player_teams_page.dart';
import '../../constants/firebase_collections.dart';
import '../../utils/firebase_error_handler.dart';

// Import de tes nouvelles pages
import 'player_pending_page.dart';
import 'player_no_club_page.dart';
import 'player_profil_page.dart';
import 'player_planning_page.dart';
import 'player_event_details_page.dart';
import 'player_infos_page.dart';
import 'player_loan_catalog_page.dart';

import '../../theme/viro_theme.dart';
import '../../widget/profile_switcher_dialog.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import '../add_profile_page.dart';

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

  // Extraire tous les clubIds du joueur depuis roles
  List<String> _extractClubIds(Map<String, dynamic>? userData) {
    final Set<String> clubIdsSet = {};
    final roles = userData?['roles'] as Map<String, dynamic>? ?? {};

    // Player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        for (var club in clubs) {
          final clubId = club['clubId'] as String?;
          if (clubId != null) clubIdsSet.add(clubId);
        }
      }
      // Ancienne structure : clubId direct (compatibilité)
      else {
        final playerClubId = playerData['clubId'] as String?;
        if (playerClubId != null) clubIdsSet.add(playerClubId);
      }
    }

    // Fallback pour compatibilité
    final legacyClubId = userData?['clubId'] as String?;
    if (legacyClubId != null) clubIdsSet.add(legacyClubId);

    return clubIdsSet.toList();
  }

  // Générer une couleur unique par clubId
  Color _getClubColor(String clubId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
    ];
    final index = clubId.hashCode % colors.length;
    return colors[index.abs()];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bonjour';
    if (hour >= 12 && hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
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
        if (!snapshot.hasData) {
          return const Scaffold(body: ViroLoader(size: 80));
        }

        final userData =
            _manualUserData ?? snapshot.data!.data() as Map<String, dynamic>?;
        final bool hasPendingRequest = userData?['hasPendingRequest'] ?? false;

        // Utiliser activeContext au lieu de clubId à la racine
        final activeContext =
            userData?['activeContext'] as Map<String, dynamic>?;
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
          clubName ??= userData?['clubName'] as String? ?? "Mon Club";

          final allClubIds = _extractClubIds(userData);
          // Utiliser le premier clubId pour la compatibilité avec les paramètres existants
          final primaryClubId = finalClubId.isNotEmpty
              ? finalClubId
              : (allClubIds.isNotEmpty ? allClubIds.first : "");

          return _buildClubMemberView(
            firstName,
            primaryClubId,
            clubName,
            userData,
            allClubIds,
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
    List<String> allClubIds,
  ) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: Text("Bonjour, $name"),
        backgroundColor: ViroColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Ajouter un profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProfilePage()),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUserId)
                .snapshots(),
            builder: (context, snap) {
              final avatarUrl = snap.data?.data()?['avatarUrl'] as String?;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerProfilPage()),
                ),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (_) => const ProfileSwitcherDialog(),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          imageBuilder: (context, imageProvider) =>
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: ViroColors.primary.withOpacity(
                                  0.1,
                                ),
                                backgroundImage: imageProvider,
                              ),
                          placeholder: (context, url) => CircleAvatar(
                            radius: 18,
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 18,
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: ViroColors.primary,
                            ),
                          ),
                          memCacheWidth: 72,
                          memCacheHeight: 72,
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: ViroColors.primary.withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: ViroColors.primary,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Logo en arrière-plan avec opacité
            Positioned(
              bottom: -150,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/logo/logo_seul.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
            // Contenu principal
            RefreshIndicator(
              onRefresh: _refreshUserStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(name, clubId, clubName, allClubIds, userData),
                    const SizedBox(height: 28),

                    _buildActionRequiredBloc(clubId, allClubIds, userData),
                    const SizedBox(height: 28),

                    _buildTodaySection(clubId, allClubIds, userData),
                    const SizedBox(height: 28),

                    // Navigation Rapide (carte Mes Équipes)
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(clubId),
    );
  }

  // --- COMPOSANTS DE L'INTERFACE ---

  Widget _buildAnnouncements(
    List<String> clubIds,
    Map<String, dynamic>? userData,
  ) {
    if (clubIds.isEmpty) return const SizedBox.shrink();

    // Récupérer les informations du joueur pour chaque club
    final roles = userData?['roles'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> clubTeamIdsMap = {};
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        for (var club in clubs) {
          final clubIdFromClub = club['clubId'] as String?;
          if (clubIdFromClub == null || !clubIds.contains(clubIdFromClub)) {
            continue;
          }
          final teamIds =
              (club['teamIds'] as List?)?.whereType<String>().toList() ?? [];
          clubTeamIdsMap[clubIdFromClub] = teamIds;
        }
      }
    }

    // Combiner les annonces de tous les clubs via StreamBuilders imbriqués
    return _buildAnnouncementsNestedStream(
      clubIds: clubIds,
      clubTeamIdsMap: clubTeamIdsMap,
      currentIndex: 0,
      snapshots: [],
    );
  }

  Widget _buildAnnouncementsNestedStream({
    required List<String> clubIds,
    required Map<String, List<String>> clubTeamIdsMap,
    required int currentIndex,
    required List<QuerySnapshot?> snapshots,
  }) {
    if (currentIndex >= clubIds.length) {
      return _buildCombinedAnnouncementsUI(
        clubIds: clubIds,
        clubTeamIdsMap: clubTeamIdsMap,
        snapshots: snapshots,
      );
    }
    final clubId = clubIds[currentIndex];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final newSnapshots = List<QuerySnapshot?>.from(snapshots)
          ..add(snapshot.hasData ? snapshot.data : null);
        return _buildAnnouncementsNestedStream(
          clubIds: clubIds,
          clubTeamIdsMap: clubTeamIdsMap,
          currentIndex: currentIndex + 1,
          snapshots: newSnapshots,
        );
      },
    );
  }

  Widget _buildCombinedAnnouncementsUI({
    required List<String> clubIds,
    required Map<String, List<String>> clubTeamIdsMap,
    required List<QuerySnapshot?> snapshots,
  }) {
    final now = DateTime.now();
    final combined = <({DocumentSnapshot doc, String clubId})>[];

    for (var i = 0; i < clubIds.length && i < snapshots.length; i++) {
      final snap = snapshots[i];
      final clubId = clubIds[i];
      final userTeamIds = clubTeamIdsMap[clubId] ?? [];
      if (snap == null || snap.docs.isEmpty) continue;

      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdTs = data['createdAt'] as Timestamp?;
        final durationDays = data['durationDays'] as int? ?? 7;
        if (createdTs != null) {
          final createdAt = createdTs.toDate();
          if (createdAt.isAfter(now)) continue;
          final expiresAt = createdAt.add(Duration(days: durationDays));
          if (expiresAt.isBefore(now)) continue;
        }
        final targetType = data['targetType'] as String? ?? '';
        final targetIds =
            (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
        if (targetIds.isNotEmpty) {
          switch (targetType) {
            case 'Tous les membres':
              break;
            case 'Joueurs':
              if (!targetIds.contains(_currentUserId)) continue;
              break;
            case 'Équipes':
              if (!targetIds.any((teamId) => userTeamIds.contains(teamId))) {
                continue;
              }
              break;
            case 'Catégories':
              break;
            default:
              continue;
          }
        }
        combined.add((doc: doc, clubId: clubId));
      }
    }

    combined.sort((a, b) {
      final aTs =
          (a.doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTs =
          (b.doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });

    if (combined.isEmpty) return const SizedBox.shrink();

    final firstClubId = combined.first.clubId;
    final containerColor = _getClubColor(firstClubId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: containerColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded, color: containerColor),
              const SizedBox(width: 8),
              Text(
                "Message(s) du club",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: containerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...combined.take(5).map((item) {
            final doc = item.doc;
            final clubId = item.clubId;
            final data = doc.data() as Map<String, dynamic>;
            final clubColor = _getClubColor(clubId);
            final created = (data['createdAt'] as Timestamp?)
                ?.toDate()
                .toLocal();
            final senderId = data['senderId'] as String?;
            final dateLabel = created != null
                ? DateFormat('dd/MM à HH:mm').format(created)
                : '';
            final message = data['message'] as String? ?? '';
            final senderFirstName = data['senderFirstName'] as String? ?? '';
            final senderLastName = data['senderLastName'] as String? ?? '';
            final senderName = "$senderFirstName $senderLastName".trim();

            return Padding(
              key: ValueKey('${clubId}_${doc.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: clubColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateLabel.isNotEmpty)
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        if (senderName.isNotEmpty || senderId != null) ...[
                          const SizedBox(height: 4),
                          (senderId != null && senderName.isNotEmpty)
                              ? UserDisplayTile(
                                  userId: senderId,
                                  firstName: senderFirstName,
                                  lastName: senderLastName,
                                  compact: true,
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    color: clubColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : senderId != null
                              ? FutureBuilder<DocumentSnapshot>(
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
                                        userSnap.data!.data()
                                            as Map<String, dynamic>?;
                                    return UserDisplayTile(
                                      userId: senderId,
                                      firstName: uData?['firstName'] as String?,
                                      lastName: uData?['lastName'] as String?,
                                      avatarUrl: uData?['avatarUrl'] as String?,
                                      compact: true,
                                      textStyle: TextStyle(
                                        fontSize: 12,
                                        color: clubColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                )
                              : UserDisplayTile(
                                  userId: null,
                                  firstName: senderFirstName,
                                  lastName: senderLastName,
                                  compact: true,
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    color: clubColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitleLarge(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ViroColors.primary,
        ),
      ),
    );
  }

  Widget _buildHero(
    String name,
    String clubId,
    String clubName,
    List<String> allClubIds,
    Map<String, dynamic>? userData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ViroColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        _buildAllClubsCards(allClubIds),
        const SizedBox(height: 20),
        _buildAnnouncements(allClubIds, userData),
        const SizedBox(height: 14),
        _buildNextEventSummaryLine(allClubIds, userData),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchClubInfos(
    List<String> clubIds,
  ) async {
    if (clubIds.isEmpty) return [];
    final snaps = await Future.wait(
      clubIds.map(
        (id) => FirebaseFirestore.instance.collection('clubs').doc(id).get(),
      ),
    );
    return clubIds.asMap().entries.map((e) {
      final i = e.key;
      final id = e.value;
      final data = snaps[i].data();
      final name = data?['name'] as String? ?? 'Club';
      final logoUrl = data?['logoUrl'] as String?;
      return <String, dynamic>{'id': id, 'name': name, 'logoUrl': logoUrl};
    }).toList();
  }

  Widget _buildAllClubsCards(List<String> allClubIds) {
    if (allClubIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchClubInfos(allClubIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final clubs = snapshot.data!;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: clubs
              .map(
                (c) => _buildClubCard(
                  c['id'] as String,
                  c['name'] as String,
                  c['logoUrl'] as String?,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildClubCard(String clubId, String clubName, String? logoUrl) {
    final clubColor = _getClubColor(clubId);
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerInfosPage(clubId: clubId)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: clubColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: clubColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: hasLogo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Icon(
                            Icons.groups_rounded,
                            color: clubColor,
                            size: 24,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.groups_rounded,
                            color: clubColor,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(Icons.groups_rounded, color: clubColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  clubName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: clubColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextEventSummaryLine(
    List<String> clubIds,
    Map<String, dynamic>? userData,
  ) {
    if (clubIds.isEmpty) {
      return Text(
        "Ta journée est libre.",
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      );
    }
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final nextSunday = startOfDay.add(Duration(days: 7 - now.weekday + 1));
    final streams = clubIds.map((clubId) {
      return FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(nextSunday))
          .orderBy('date')
          .snapshots();
    }).toList();

    if (streams.length == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot) {
          final line = _getNextEventLineFromSnapshots(
            [snapshot.data],
            clubIds,
            userData,
          );
          return Text(
            line ?? "Ta journée est libre.",
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          );
        },
      );
    }
    if (streams.length == 2) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot0) {
          return StreamBuilder<QuerySnapshot>(
            stream: streams[1],
            builder: (context, snapshot1) {
              final line = _getNextEventLineFromSnapshots(
                [snapshot0.data, snapshot1.data],
                clubIds,
                userData,
              );
              return Text(
                line ?? "Ta journée est libre.",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              );
            },
          );
        },
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: streams[0],
      builder: (context, snapshot0) {
        return StreamBuilder<QuerySnapshot>(
          stream: streams[1],
          builder: (context, snapshot1) {
            if (streams.length == 3) {
              return StreamBuilder<QuerySnapshot>(
                stream: streams[2],
                builder: (context, snapshot2) {
                  final line = _getNextEventLineFromSnapshots(
                    [snapshot0.data, snapshot1.data, snapshot2.data],
                    clubIds,
                    userData,
                  );
                  return Text(
                    line ?? "Ta journée est libre.",
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  );
                },
              );
            }
            final line = _getNextEventLineFromSnapshots(
              [snapshot0.data, snapshot1.data],
              clubIds.take(2).toList(),
              userData,
            );
            return Text(
              line ?? "Ta journée est libre.",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            );
          },
        );
      },
    );
  }

  String? _getNextEventLineFromSnapshots(
    List<QuerySnapshot?>? snapshots,
    List<String> clubIds,
    Map<String, dynamic>? userData,
  ) {
    final events = _extractEventsFromSnapshots(
      snapshots,
      clubIds,
      userData,
      onlyNeedingAction: false,
    );
    if (events.isEmpty) return null;
    events.sort((a, b) {
      final aDate = (a['eventData'] as Map)['date'] as Timestamp?;
      final bDate = (b['eventData'] as Map)['date'] as Timestamp?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    final first = events.first;
    final data = first['eventData'] as Map<String, dynamic>;
    final date = (data['date'] as Timestamp?)?.toDate();
    final title = data['title'] ?? data['type'] ?? 'Événement';
    final startTime = data['startTime'] as String?;
    String dateLabel;
    if (date == null) {
      dateLabel = '';
    } else {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final eventDate = DateTime(date.year, date.month, date.day);
      if (eventDate == todayDate) {
        dateLabel = startTime != null
            ? "aujourd'hui à $startTime"
            : "aujourd'hui";
      } else if (eventDate == todayDate.add(const Duration(days: 1))) {
        dateLabel = startTime != null ? "demain à $startTime" : "demain";
      } else {
        dateLabel = DateFormat('EEEE d MMM', 'fr_FR').format(date);
        if (startTime != null) dateLabel += ' à $startTime';
      }
    }
    return "Prochain événement : $title${dateLabel.isNotEmpty ? ' — $dateLabel' : ''}";
  }

  List<Map<String, dynamic>> _extractEventsFromSnapshots(
    List<QuerySnapshot?>? snapshots,
    List<String> clubIds,
    Map<String, dynamic>? userData, {
    required bool onlyNeedingAction,
  }) {
    final List<Map<String, dynamic>> result = [];
    if (snapshots == null || snapshots.isEmpty) return result;
    for (int i = 0; i < snapshots.length && i < clubIds.length; i++) {
      final snapshot = snapshots[i];
      if (snapshot == null) continue;
      final clubId = clubIds[i];
      for (var doc in snapshot.docs) {
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
            (userData?['categories'] as List?)?.whereType<String>().toList() ??
            [];
        if (userCategories.isEmpty && _manualUserData?['category'] is String) {
          userCategories.add(_manualUserData?['category'] as String);
        } else if (userCategories.isEmpty && userData?['category'] is String) {
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
        if (!isConcerned) continue;
        if (onlyNeedingAction) {
          final attendance = data['attendance'] as Map? ?? {};
          final needsAction =
              attendance[_currentUserId] == null ||
              attendance[_currentUserId] == 'none';
          if (!needsAction) continue;
        }
        result.add({'eventId': doc.id, 'eventData': data, 'clubId': clubId});
      }
    }
    return result;
  }

  Widget _buildActionRequiredBloc(
    String clubId,
    List<String> allClubIds,
    Map<String, dynamic>? userData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleLarge("À faire maintenant"),
        _buildActionRequiredBlocBody(clubId, allClubIds, userData),
      ],
    );
  }

  Widget _buildActionRequiredBlocBody(
    String clubId,
    List<String> allClubIds,
    Map<String, dynamic>? userData,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final nextSunday = startOfDay.add(Duration(days: 7 - now.weekday + 1));
    final oneDayAgo = now.subtract(const Duration(days: 1));
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final inThreeDays = today.add(const Duration(days: 3));

    final eventStream = allClubIds.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('clubs')
              .doc(allClubIds.first)
              .collection('events')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('date', isLessThan: Timestamp.fromDate(nextSunday))
              .orderBy('date')
              .snapshots();

    final loanRequestStream = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('equipment_loan_requests')
        .where('playerId', isEqualTo: _currentUserId)
        .where('status', whereIn: ['accepted', 'refused'])
        .where(
          'respondedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(oneDayAgo),
        )
        .orderBy('respondedAt', descending: true)
        .limit(10)
        .snapshots();

    final preparationStream = FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .where('borrowerId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .where('lentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('lentAt', isLessThan: Timestamp.fromDate(tomorrow))
        .snapshots();

    final returnStream = FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .where('borrowerId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('dueAt', isLessThanOrEqualTo: Timestamp.fromDate(inThreeDays))
        .snapshots();

    if (eventStream == null) {
      return StreamBuilder<QuerySnapshot>(
        stream: loanRequestStream,
        builder: (context, loanReqSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: preparationStream,
            builder: (context, prepSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: returnStream,
                builder: (context, returnSnap) {
                  return _buildActionRequiredList(
                    null,
                    loanReqSnap.data,
                    prepSnap.data,
                    returnSnap.data,
                    clubId,
                    allClubIds,
                    userData,
                  );
                },
              );
            },
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: eventStream,
      builder: (context, eventSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: loanRequestStream,
          builder: (context, loanReqSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: preparationStream,
              builder: (context, prepSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: returnStream,
                  builder: (context, returnSnap) {
                    return _buildActionRequiredList(
                      eventSnap.data,
                      loanReqSnap.data,
                      prepSnap.data,
                      returnSnap.data,
                      clubId,
                      allClubIds,
                      userData,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionRequiredList(
    QuerySnapshot? eventSnapshot,
    QuerySnapshot? loanRequestSnapshot,
    QuerySnapshot? preparationSnapshot,
    QuerySnapshot? returnSnapshot,
    String clubId,
    List<String> allClubIds,
    Map<String, dynamic>? userData,
  ) {
    final List<Widget> items = [];
    final primaryClubId = allClubIds.isNotEmpty ? allClubIds.first : clubId;

    final pendingEvents = eventSnapshot == null
        ? <Map<String, dynamic>>[]
        : _extractEventsFromSnapshots(
            [eventSnapshot],
            [primaryClubId],
            userData,
            onlyNeedingAction: true,
          );

    for (final e in pendingEvents) {
      final eventId = e['eventId'] as String;
      final data = e['eventData'] as Map<String, dynamic>;
      final cId = e['clubId'] as String;
      final date = (data['date'] as Timestamp?)?.toDate();
      final dateStr = date != null
          ? DateFormat('EEEE d', 'fr_FR').format(date)
          : '';
      final title = data['teamName'] ?? data['type'] ?? 'Événement';
      items.add(
        _buildActionRequiredItem(
          icon: Icons.event_available,
          iconColor: _getClubColor(cId),
          title: 'Présence à confirmer',
          subtitle: '$title — $dateStr',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlayerEventDetailsPage(clubId: cId, eventId: eventId),
            ),
          ),
        ),
      );
    }

    final loanRequestDocs = loanRequestSnapshot?.docs ?? [];
    for (final doc in loanRequestDocs.take(5)) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final equipmentName = data['equipmentName'] as String? ?? 'Équipement';
      final isAccepted = status == 'accepted';
      final statusLabel = isAccepted ? 'Acceptée' : 'Refusée';
      items.add(
        _buildActionRequiredItem(
          icon: isAccepted ? Icons.check_circle : Icons.cancel,
          iconColor: isAccepted ? ViroColors.success : ViroColors.error,
          title: 'Réponse prêt : $statusLabel',
          subtitle: equipmentName,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerLoanCatalogPage(clubId: clubId),
            ),
          ),
        ),
      );
    }

    final preparationDocs = preparationSnapshot?.docs ?? [];
    for (final doc in preparationDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final equipmentName = data['equipmentName'] as String? ?? 'Équipement';
      final quantity = data['quantity'] as int? ?? 1;
      items.add(
        _buildActionRequiredItem(
          icon: Icons.inventory_2_rounded,
          iconColor: ViroColors.primary,
          title: 'Prêt à récupérer',
          subtitle: '$equipmentName (x$quantity)',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerLoanCatalogPage(clubId: clubId),
            ),
          ),
        ),
      );
    }

    final returnDocs = returnSnapshot?.docs ?? [];
    final sortedReturn = returnDocs.toList()
      ..sort((a, b) {
        final aDue = (a.data() as Map)['dueAt'] as Timestamp?;
        final bDue = (b.data() as Map)['dueAt'] as Timestamp?;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    for (final doc in sortedReturn) {
      final data = doc.data() as Map<String, dynamic>;
      final equipmentName = data['equipmentName'] as String? ?? 'Équipement';
      final quantity = data['quantity'] as int? ?? 1;
      final dueAt = data['dueAt'] as Timestamp?;
      final dueDate = dueAt?.toDate();
      final todayDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final isToday =
          dueDate != null &&
          DateTime(dueDate.year, dueDate.month, dueDate.day) == todayDate;
      final sub = dueDate != null
          ? (isToday
                ? "Retour aujourd'hui"
                : "Retour le ${DateFormat('dd/MM', 'fr_FR').format(dueDate)}")
          : '';
      items.add(
        _buildActionRequiredItem(
          icon: isToday ? Icons.warning_amber_rounded : Icons.schedule_rounded,
          iconColor: isToday ? ViroColors.error : ViroColors.warning,
          title: '$equipmentName (x$quantity)',
          subtitle: sub,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerLoanCatalogPage(clubId: clubId),
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: ViroColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ViroColors.success.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: ViroColors.success, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Tu es à jour !",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ViroColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRequiredItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySection(
    String clubId,
    List<String> allClubIds,
    Map<String, dynamic>? userData,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final primaryClubId = allClubIds.isNotEmpty ? allClubIds.first : clubId;

    final activeLoansStream = FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.equipmentLoans)
        .where('borrowerId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .snapshots();

    final todayEventsStream = FirebaseFirestore.instance
        .collection('clubs')
        .doc(primaryClubId)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: activeLoansStream,
      builder: (context, loansSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: todayEventsStream,
          builder: (context, eventsSnap) {
            final hasLoans =
                loansSnap.data != null && loansSnap.data!.docs.isNotEmpty;
            final todayEvents = _extractEventsFromSnapshots(
              [eventsSnap.data],
              [primaryClubId],
              userData,
              onlyNeedingAction: false,
            );
            final hasEvents = todayEvents.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitleLarge("Aujourd'hui"),
                if (!hasLoans && !hasEvents) ...[
                  _buildTodayEmptyStateCard(clubId),
                ] else ...[
                  _buildTodayLoansFromSnapshot(loansSnap.data, clubId),
                  const SizedBox(height: 12),
                  _buildTodayEventsFromEventList(todayEvents),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTodayEmptyStateCard(String clubId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            "Aucun événement aujourd'hui",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPlanningPage(clubId: clubId),
              ),
            ),
            icon: const Icon(Icons.calendar_month, size: 20),
            label: const Text("Voir le planning"),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLoansFromSnapshot(QuerySnapshot? snapshot, String clubId) {
    if (snapshot == null || snapshot.docs.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sortedLoans = snapshot.docs.toList()
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aDue = aData?['dueAt'] as Timestamp?;
        final bDue = bData?['dueAt'] as Timestamp?;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ViroColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ViroColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: ViroColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Prêt en cours",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: ViroColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...sortedLoans.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final equipmentName =
                data['equipmentName'] as String? ?? 'Équipement';
            final quantity = data['quantity'] as int? ?? 1;
            final dueAt = data['dueAt'] as Timestamp?;
            final dueDate = dueAt?.toDate();
            final isToday =
                dueDate != null &&
                DateTime(dueDate.year, dueDate.month, dueDate.day) == today;
            return Padding(
              key: ValueKey(doc.id),
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    isToday
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: isToday ? ViroColors.error : ViroColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$equipmentName (x$quantity)",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        if (dueDate != null)
                          Text(
                            isToday
                                ? "Retour aujourd'hui"
                                : "Retour le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday
                                  ? ViroColors.error
                                  : Colors.grey[700],
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTodayEventsFromEventList(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      children: events
          .map(
            (e) => _eventSmallTile(
              e['eventId'] as String,
              e['eventData'] as Map<String, dynamic>,
              e['clubId'] as String,
              key: ValueKey(e['eventId']),
            ),
          )
          .toList(),
    );
  }

  Widget _eventSmallTile(
    String id,
    Map<String, dynamic> data,
    String clubId, {
    Key? key,
  }) {
    final isAllDay = data['startTime'] == null && data['endTime'] == null;
    final timeLabel = isAllDay ? "ALL DAY" : (data['startTime'] ?? "--:--");
    final typeLabel = data['title'] ?? data['type'] ?? "Événement";
    final bool canceled = data['canceled'] == true;
    final clubColor = _getClubColor(clubId);

    return Card(
      key: key,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: canceled ? ViroColors.borderColor : clubColor.withOpacity(0.5),
          width: canceled ? 1 : 2,
        ),
      ),
      color: canceled ? Colors.grey.shade300 : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: clubColor.withOpacity(0.1),
          child: Text(
            timeLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: clubColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                typeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: clubColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .get(),
              builder: (context, clubSnap) {
                final clubData = clubSnap.data?.data() as Map<String, dynamic>?;
                final clubName = clubData?['name'] as String? ?? "Club";
                return Text(
                  clubName,
                  style: TextStyle(
                    fontSize: 11,
                    color: clubColor,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            Text(
              canceled
                  ? "ANNULÉ • ${data['location'] ?? ''}"
                  : (data['location'] ?? ""),
              style: TextStyle(
                fontSize: 12,
                color: canceled ? Colors.red : Colors.grey,
                fontWeight: canceled ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
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
            MaterialPageRoute(
              builder: (_) => PlayerLoanCatalogPage(clubId: clubId),
            ),
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
          icon: Icon(Icons.inventory_2_outlined),
          label: "Catalogue prêt",
        ),
      ],
    );
  }
}
