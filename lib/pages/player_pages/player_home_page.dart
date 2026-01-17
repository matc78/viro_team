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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(name),
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
              _buildTodayEvents(allClubIds, userData),

              const SizedBox(height: 30),

              _buildSectionTitle("ACTION REQUISE : PRÉSENCE"),
              _buildPendingActions(allClubIds, userData),
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

  Widget _buildHeader(String name) {
    return Column(
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
    );
  }

  Widget _buildTodayEvents(
    List<String> clubIds,
    Map<String, dynamic>? userData,
  ) {
    if (clubIds.isEmpty) {
      return const Text(
        "Rien de prévu aujourd'hui.",
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Créer les streams pour chaque club
    final streams = clubIds.map((clubId) {
      return FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots();
    }).toList();

    return _buildCombinedEventStreams(
      streams,
      clubIds,
      userData,
      isToday: true,
    );
  }

  Widget _buildPendingActions(
    List<String> clubIds,
    Map<String, dynamic>? userData,
  ) {
    if (clubIds.isEmpty) {
      return const Text(
        "Tu es à jour ! ✅",
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final nextSunday = startOfDay.add(Duration(days: 7 - now.weekday + 1));

    // Créer les streams pour chaque club
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

    return _buildCombinedEventStreams(
      streams,
      clubIds,
      userData,
      isToday: false,
    );
  }

  // Construire des StreamBuilder imbriqués pour combiner les streams
  Widget _buildCombinedEventStreams(
    List<Stream<QuerySnapshot>> streams,
    List<String> clubIds,
    Map<String, dynamic>? userData, {
    required bool isToday,
  }) {
    if (streams.isEmpty) {
      return isToday
          ? const Text(
              "Rien de prévu aujourd'hui.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          : const Text(
              "Tu es à jour ! ✅",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            );
    }

    if (streams.length == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot) {
          return _buildEventsFromSnapshots(
            [snapshot.data],
            clubIds,
            userData,
            isToday: isToday,
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
              return _buildEventsFromSnapshots(
                [snapshot0.data, snapshot1.data],
                clubIds,
                userData,
                isToday: isToday,
              );
            },
          );
        },
      );
    }

    // Pour 3 clubs ou plus
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
                  return _buildEventsFromSnapshots(
                    [snapshot0.data, snapshot1.data, snapshot2.data],
                    clubIds,
                    userData,
                    isToday: isToday,
                  );
                },
              );
            }
            // Pour plus de 3 clubs, traiter les 3 premiers
            return _buildEventsFromSnapshots(
              [snapshot0.data, snapshot1.data, if (streams.length > 2) null],
              clubIds.take(3).toList(),
              userData,
              isToday: isToday,
            );
          },
        );
      },
    );
  }

  // Construire les événements à partir des snapshots
  Widget _buildEventsFromSnapshots(
    List<QuerySnapshot?>? snapshots,
    List<String> clubIds,
    Map<String, dynamic>? userData, {
    required bool isToday,
  }) {
    if (snapshots == null || snapshots.isEmpty) {
      return const SizedBox();
    }

    // Combiner tous les événements avec leur clubId
    final List<Map<String, dynamic>> allEventsWithClub = [];
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

        if (isToday) {
          // Pour les événements d'aujourd'hui
          if (isConcerned) {
            allEventsWithClub.add({
              'eventId': doc.id,
              'eventData': data,
              'clubId': clubId,
            });
          }
        } else {
          // Pour les actions en attente, vérifier aussi la présence
          final attendance = data['attendance'] as Map? ?? {};
          final needsAction =
              (attendance[_currentUserId] == null ||
              attendance[_currentUserId] == 'none');
          if (isConcerned && needsAction) {
            allEventsWithClub.add({
              'eventId': doc.id,
              'eventData': data,
              'clubId': clubId,
            });
          }
        }
      }
    }

    if (allEventsWithClub.isEmpty) {
      return isToday
          ? const Text(
              "Rien de prévu aujourd'hui.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          : const Text(
              "Tu es à jour ! ✅",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            );
    }

    if (isToday) {
      return Column(
        children: allEventsWithClub
            .map(
              (eventInfo) => _eventSmallTile(
                key: ValueKey(eventInfo['eventId']),
                eventInfo['eventId'] as String,
                eventInfo['eventData'] as Map<String, dynamic>,
                eventInfo['clubId'] as String,
              ),
            )
            .toList(),
      );
    } else {
      return Column(
        children: allEventsWithClub
            .map(
              (eventInfo) => _pendingActionCard(
                key: ValueKey(eventInfo['eventId']),
                eventInfo['eventId'] as String,
                eventInfo['eventData'] as Map<String, dynamic>,
                eventInfo['clubId'] as String,
              ),
            )
            .toList(),
      );
    }
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

  Widget _pendingActionCard(
    String id,
    Map<String, dynamic> data,
    String clubId, {
    Key? key,
  }) {
    final date = (data['date'] as Timestamp).toDate();
    final dateStr = DateFormat('EEEE d', 'fr_FR').format(date);
    final clubColor = _getClubColor(clubId);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: clubColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: clubColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data['type']?.toUpperCase() ?? "ÉVÉNEMENT",
                    style: TextStyle(
                      color: clubColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
