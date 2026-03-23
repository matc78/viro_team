import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/document_cache.dart';
import '../../utils/firebase_helpers.dart';
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
  final ScrollController _dayScrollController = ScrollController();

  // Jours ayant au moins un événement pertinent (format "YYYY-MM-DD")
  Set<String> _daysWithEvents = {};
  List<String>? _dotsLoadedForClubIds;

  // Liste des jours pour le sélecteur horizontal (4 semaines = 28 jours)
  List<DateTime> _getDays() {
    return List.generate(
      28,
      (index) => DateTime.now().add(Duration(days: index)),
    );
  }

  // Extraire tous les clubIds du joueur depuis profileSummaries
  List<String> _extractClubIds(Map<String, dynamic>? userData) {
    final Set<String> clubIdsSet = {};
    final summaries =
        (userData?['profileSummaries'] as List?)?.whereType<Map>().toList() ??
        [];
    for (final e in summaries) {
      final cid = e['clubId'] as String?;
      if (cid != null && cid.isNotEmpty) clubIdsSet.add(cid);
    }
    final activeContext = userData?['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    if (activeClubId != null && activeClubId.isNotEmpty) {
      clubIdsSet.add(activeClubId);
    }
    final legacyClubId = userData?['clubId'] as String?;
    if (legacyClubId != null) clubIdsSet.add(legacyClubId);

    return clubIdsSet.toList();
  }

  // Charger les jours ayant des événements pertinents sur les 28 prochains jours
  Future<void> _loadEventDots(List<String> clubIds) async {
    if (clubIds.isEmpty || _currentUserId.isEmpty) return;

    final startDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final endDate = startDate.add(const Duration(days: 28));

    // Charger les données membre en parallèle pour tous les clubs
    final memberDataByClub = <String, Map<String, dynamic>?>{};
    await Future.wait(clubIds.map((cid) async {
      memberDataByClub[cid] = await getMemberData(appFirestore, _currentUserId, cid);
    }));

    final Set<String> days = {};

    await Future.wait(clubIds.map((clubId) async {
      final snap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .get();

      final player = memberDataByClub[clubId]?['player'] as Map<String, dynamic>?;
      final userTeams =
          (player?['teamNames'] as List?)?.whereType<String>().toList() ?? [];
      final userCategories =
          (player?['categories'] as List?)?.whereType<String>().toList() ?? [];

      for (final doc in snap.docs) {
        final data = doc.data();
        if (_isEventRelevantForPlayer(data, userTeams, userCategories)) {
          final ts = data['date'] as Timestamp?;
          if (ts != null) {
            final d = ts.toDate();
            days.add(
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            );
          }
        }
      }
    }));

    if (mounted) setState(() => _daysWithEvents = days);
  }

  // Générer une couleur unique par clubId
  Color _getClubColor(String clubId) {
    final index = clubId.hashCode % ViroColors.clubPalette.length;
    return ViroColors.clubPalette[index.abs()];
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollToCenterSelectedDay(int selectedIndex) {
    const itemWidth = 77.0; // 65 + 6 + 6 (container + margins)
    // Avec le padding symétrique, l'offset pour centrer l'item i est i * itemWidth
    final targetOffset = selectedIndex * itemWidth;
    final maxOffset = _dayScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    _dayScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Mon Planning"),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildDaySelector(context),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: appFirestore
                  .collection(FirebaseCollections.users)
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: ViroLoader(size: 60));
                }
                _userData = snapshot.data?.data();

                // Déclencher le chargement des dots si les clubs ont changé
                final clubIds = _extractClubIds(_userData);
                if (clubIds.isNotEmpty &&
                    clubIds.join(',') != (_dotsLoadedForClubIds?.join(',') ?? '')) {
                  _dotsLoadedForClubIds = clubIds;
                  Future.microtask(() => _loadEventDots(clubIds));
                }

                return _buildEventList();
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- SÉLECTEUR DE JOURS HORIZONTAL ---
  Widget _buildDaySelector(BuildContext context) {
    final days = _getDays();
    const itemWidth = 77.0; // 65 + 6 + 6 (container + margins)
    final viewportWidth = MediaQuery.of(context).size.width;
    final sidePadding = (viewportWidth - itemWidth) / 2;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, _selectedDate);
          final dayKey =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final hasEvents = _daysWithEvents.contains(dayKey);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_dayScrollController.hasClients) {
                  _scrollToCenterSelectedDay(index);
                }
              });
            },
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
                  Text(
                    DateFormat('MMM', 'fr_FR').format(day).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasEvents
                          ? (isSelected
                              ? Colors.white
                              : ViroColors.primary)
                          : Colors.transparent,
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
    final clubIds = _extractClubIds(_userData);

    if (clubIds.isEmpty) {
      return _buildEmptyState();
    }

    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Créer les streams pour chaque club
    final streams = clubIds.map((clubId) {
      return appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .snapshots();
    }).toList();

    // Utiliser des StreamBuilder imbriqués pour combiner les événements
    return _buildCombinedStreamBuilder(streams, clubIds);
  }

  // Construire des StreamBuilder imbriqués pour combiner les streams
  Widget _buildCombinedStreamBuilder(
    List<Stream<QuerySnapshot>> streams,
    List<String> clubIds,
  ) {
    if (streams.isEmpty) {
      return _buildEmptyState();
    }

    if (streams.length == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot) {
          return _buildEventsListFromSnapshots(context, [
            snapshot.data,
          ], clubIds);
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
              return _buildEventsListFromSnapshots(context, [
                snapshot0.data,
                snapshot1.data,
              ], clubIds);
            },
          );
        },
      );
    }

    // Pour 3 clubs ou plus, continuer l'imbrication
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
                  return _buildEventsListFromSnapshots(context, [
                    snapshot0.data,
                    snapshot1.data,
                    snapshot2.data,
                  ], clubIds);
                },
              );
            }
            // Pour plus de 3 clubs, traiter les 3 premiers (peut être étendu)
            return _buildEventsListFromSnapshots(context, [
              snapshot0.data,
              snapshot1.data,
              if (streams.length > 2) null,
            ], clubIds.take(3).toList());
          },
        );
      },
    );
  }

  // Construire la liste d'événements à partir des snapshots
  Widget _buildEventsListFromSnapshots(
    BuildContext context,
    List<QuerySnapshot?>? snapshots,
    List<String> clubIds,
  ) {
    if (snapshots == null || snapshots.isEmpty) {
      return const Center(child: ViroLoader(size: 50));
    }

    // Récupérer les dates de fin de saison pour tous les clubs
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSeasonEndDates(clubIds),
      builder: (context, seasonEndSnap) {
        final seasonEndDates = seasonEndSnap.data ?? [];
        final seasonEndMap = <String, DateTime?>{};
        for (var entry in seasonEndDates) {
          final clubId = entry['clubId'] as String;
          final date = entry['date'] as DateTime?;
          seasonEndMap[clubId] = date;
        }

        // Charger teams/categories par club — en parallèle, 1 seule lecture
        // du doc member par club (au lieu de 2 lectures séquentielles)
        return FutureBuilder<Map<String, Map<String, List<String>>>>(
          future: () async {
            final map = <String, Map<String, List<String>>>{};
            final uid = _currentUserId;
            if (uid.isNotEmpty && clubIds.isNotEmpty) {
              await Future.wait(clubIds.map((cid) async {
                final memberData = await getMemberData(appFirestore, uid, cid);
                final player = memberData?['player'] as Map<String, dynamic>?;
                final teams = (player?['teamNames'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                final cats = (player?['categories'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                map[cid] = {'teams': teams, 'categories': cats};
              }));
            }
            return map;
          }(),
          builder: (context, userDataSnap) {
            if (!userDataSnap.hasData) {
              return const Center(child: ViroLoader(size: 50));
            }
            final userTeamsByClub = userDataSnap.data!;
            // Combiner tous les événements avec leur clubId
            final List<Map<String, dynamic>> allEventsWithClub = [];
            for (int i = 0; i < snapshots.length && i < clubIds.length; i++) {
              final snapshot = snapshots[i];
              if (snapshot == null) continue;
              final clubId = clubIds[i];
              final seasonEndDate = seasonEndMap[clubId];
              final userTeams = userTeamsByClub[clubId]?['teams'] ?? [];
              final userCategories =
                  userTeamsByClub[clubId]?['categories'] ?? [];
              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (_isEventRelevantForPlayer(
                  data,
                  userTeams,
                  userCategories,
                )) {
                  bool isSeasonCompleted = false;
                  if (seasonEndDate != null && data['type'] == 'Entraînement') {
                    final eventDate = (data['date'] as Timestamp?)?.toDate();
                    if (eventDate != null && eventDate.isAfter(seasonEndDate)) {
                      isSeasonCompleted = true;
                    }
                  }
                  allEventsWithClub.add({
                    'eventId': doc.id,
                    'eventData': data,
                    'clubId': clubId,
                    'isSeasonCompleted': isSeasonCompleted,
                  });
                }
              }
            }

            // Trier par date
            allEventsWithClub.sort((a, b) {
              final eventDataA = a['eventData'] as Map<String, dynamic>;
              final eventDataB = b['eventData'] as Map<String, dynamic>;
              final dateA =
                  (eventDataA['date'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final dateB =
                  (eventDataB['date'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              return dateA.compareTo(dateB);
            });

            if (allEventsWithClub.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allEventsWithClub.length,
              itemBuilder: (context, index) {
                final eventInfo = allEventsWithClub[index];
                final eventId = eventInfo['eventId'] as String;
                final eventData =
                    eventInfo['eventData'] as Map<String, dynamic>;
                final clubId = eventInfo['clubId'] as String;
                final isSeasonCompleted =
                    eventInfo['isSeasonCompleted'] as bool? ?? false;
                return _buildEventCard(
                  eventId,
                  eventData,
                  clubId,
                  isSeasonCompleted: isSeasonCompleted,
                );
              },
            );
          },
        );
      },
    );
  }

  // Récupérer les dates de fin de saison pour plusieurs clubs (avec cache)
  Future<List<Map<String, dynamic>>> _getSeasonEndDates(
    List<String> clubIds,
  ) async {
    final List<Map<String, dynamic>> results = [];
    await Future.wait(clubIds.map((clubId) async {
      try {
        final snap = await DocumentCache.getDocument(
          '${FirebaseCollections.clubs}/$clubId',
          cacheDuration: const Duration(minutes: 15),
        );
        final timestamp = snap.data()?['seasonEndDate'] as Timestamp?;
        final now = DateTime.now();
        final seasonEndDate = timestamp?.toDate() ?? DateTime(now.year, 7, 31, 23, 59);
        results.add({'clubId': clubId, 'date': seasonEndDate});
      } catch (e) {
        final now = DateTime.now();
        results.add({'clubId': clubId, 'date': DateTime(now.year, 7, 31, 23, 59)});
      }
    }));
    return results;
  }

  // Vérifier si un événement concerne le joueur (teamNames/categories chargés depuis member)
  bool _isEventRelevantForPlayer(
    Map<String, dynamic> eventData,
    List<String> userTeams,
    List<String> userCategories,
  ) {
    final memberIds = (eventData['teamMemberIds'] as List<dynamic>?) ?? [];
    final teamNames =
        (eventData['teamNames'] as List?)?.whereType<String>().toList() ?? [];
    final teamName = eventData['teamName'] as String?;
    final eventCategory = eventData['category'] as String?;

    if (memberIds.isNotEmpty) {
      return memberIds.contains(_currentUserId);
    }

    final bool matchTeam =
        teamNames.any(userTeams.contains) ||
        (teamName != null && userTeams.contains(teamName));
    final bool matchCat =
        eventCategory != null && userCategories.contains(eventCategory);

    return matchTeam || matchCat;
  }

  /// Récupère les IDs des joueurs en attente (pending_members) de l'équipe.
  static Future<List<String>> _getPendingPlayerIdsForTeam(
    String clubId,
    String teamName,
  ) async {
    if (teamName.isEmpty) return [];
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return [];
    final data = snap.docs.first.data();
    final list = data['pendingPlayerIds'] as List?;
    return list?.whereType<String>().toList() ?? [];
  }

  Future<void> _updateAttendance(
    String clubId,
    String eventId,
    String status,
  ) async {
    try {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .update({'attendance.$_currentUserId': status});
    } catch (e) {
      if (mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Widget _buildEventCard(
    String docId,
    Map<String, dynamic> data,
    String clubId, {
    bool isSeasonCompleted = false,
  }) {
    final type = data['title'] ?? data['type'] ?? "Événement";
    final isAllDay = data['startTime'] == null && data['endTime'] == null;
    final time = isAllDay ? "ALL DAY" : (data['startTime'] ?? "--:--");
    final String? endTimeStr = data['endTime']?.toString();
    final teamName = data['teamName'] ?? "Club";
    final location = data['location'] ?? "Lieu non défini";
    final bool canceled = data['canceled'] == true;

    // On vérifie le statut de présence du joueur actuel pour afficher un indicateur
    final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
    final myStatus = attendance[_currentUserId]?.toString() ?? 'none';
    final presentCount = attendance.values.where((v) => v == 'present').length;
    final absentCount = attendance.values.where((v) => v == 'absent').length;
    final teamMemberIds = (data['teamMemberIds'] as List<dynamic>?) ?? [];
    final hasNotResponded = myStatus != 'present' && myStatus != 'absent';

    // Récupérer la couleur du club
    final clubColor = _getClubColor(clubId);

    // Récupérer le nom du club (mis en cache 15 min) et le nombre de pending
    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final clubDoc = await DocumentCache.getDocument(
          '${FirebaseCollections.clubs}/$clubId',
          cacheDuration: const Duration(minutes: 15),
        );
        final pendingIds = await _getPendingPlayerIdsForTeam(clubId, teamName);
        return {'club': clubDoc, 'pendingCount': pendingIds.length};
      }(),
      builder: (context, snap) {
        final clubDoc = snap.data?['club'] as DocumentSnapshot?;
        final pendingCount = (snap.data?['pendingCount'] as int?) ?? 0;
        final clubData = clubDoc?.data() as Map<String, dynamic>?;
        final clubName = clubData?['name'] as String? ?? "Club";
        final sport = clubData?['sport'] as String?;

        // Total convoqués = membres avec compte + pending ; sans réponse = total - présents - absents
        final totalConvoqued = teamMemberIds.length + pendingCount;
        final noResponseCount = (totalConvoqued - presentCount - absentCount)
            .clamp(0, totalConvoqued);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: canceled
                ? Colors.grey.shade300
                : (isSeasonCompleted ? Colors.grey.shade100 : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canceled
                  ? Colors.grey
                  : (isSeasonCompleted
                        ? Colors.grey.shade400
                        : clubColor.withValues(alpha: 0.5)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerEventDetailsPage(clubId: clubId, eventId: docId),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          decoration: BoxDecoration(
                            color: clubColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: clubColor,
                              ),
                              Text(
                                time,
                                style: TextStyle(
                                  color: clubColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      type.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: clubColor,
                                      ),
                                    ),
                                  ),
                                  if (canceled)
                                    _buildStatusChip(myStatus)
                                  else
                                    GestureDetector(
                                      onTap: () {
                                        final nextStatus = myStatus == 'present'
                                            ? 'absent'
                                            : 'present';
                                        _updateAttendance(
                                          clubId,
                                          docId,
                                          nextStatus,
                                        );
                                      },
                                      child: _buildStatusChip(myStatus),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
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
                                  const SizedBox(width: 4),
                                  Text(
                                    formatClubNameWithEmoji(clubName, sport),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: clubColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (canceled)
                                const Text(
                                  "ANNULÉ",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              if (isSeasonCompleted && !canceled)
                                const Text(
                                  "SAISON TERMINÉE",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  teamName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (endTimeStr != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            width: 50,
                            decoration: BoxDecoration(
                              color: clubColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: clubColor,
                                ),
                                Text(
                                  endTimeStr,
                                  style: TextStyle(
                                    color: clubColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasNotResponded && !canceled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _updateAttendance(clubId, docId, 'present'),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text("Présent"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ViroColors.primary,
                                side: BorderSide(color: ViroColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _updateAttendance(clubId, docId, 'absent'),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text("Absent"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPresenceNumber(presentCount, ViroColors.primary),
                        const SizedBox(width: 16),
                        _buildPresenceNumber(absentCount, Colors.red),
                        const SizedBox(width: 16),
                        _buildPresenceNumber(noResponseCount, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresenceNumber(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    if (status == 'present') {
      color = ViroColors.primary;
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
        color: color.withValues(alpha: 0.1),
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
