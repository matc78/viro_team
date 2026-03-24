import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_add_event_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_event_details_page.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
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
  final ScrollController _dayScrollController = ScrollController();

  /// Date du premier événement recensé (chargée une fois au démarrage).
  DateTime? _firstEventDate;
  bool _firstEventLoaded = false;

  static const double _dayItemWidth = 77.0; // 65 + 6 + 6 (container + margins)

  @override
  void initState() {
    super.initState();
    _loadFirstEventDate();
  }

  Future<void> _loadFirstEventDate() async {
    try {
      final snap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.events)
          .orderBy('date')
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        if (snap.docs.isNotEmpty) {
          final ts = snap.docs.first.get('date') as Timestamp?;
          if (ts != null) {
            final d = ts.toDate();
            _firstEventDate = DateTime(d.year, d.month, d.day);
          }
        }
        _firstEventLoaded = true;
      });
      // Auto-scroll sur aujourd'hui une fois la liste connue
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday();
      });
    } catch (_) {
      if (mounted) setState(() => _firstEventLoaded = true);
    }
  }

  /// Génère la liste des jours du planning :
  /// du premier event (si passé) jusqu'à aujourd'hui + 28 jours.
  /// Si aucun event, retourne une liste vide.
  List<DateTime> _getDays() {
    if (!_firstEventLoaded) return [];
    if (_firstEventDate == null) return [];

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final startDay = _firstEventDate!.isBefore(today) ? _firstEventDate! : today;
    final endDay = today.add(const Duration(days: 28));

    final days = <DateTime>[];
    var d = startDay;
    while (!d.isAfter(endDay)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  void _scrollToToday() {
    if (!_dayScrollController.hasClients) return;
    final days = _getDays();
    final todayIndex = days.indexWhere(
      (d) => DateUtils.isSameDay(d, DateTime.now()),
    );
    if (todayIndex >= 0) _scrollToCenterSelectedDay(todayIndex);
  }

  // Vérifie si un filtre est actif
  bool _hasActiveFilter() {
    return !_filterTeam.startsWith("Choisir") || !_filterCategory.startsWith("Choisir");
  }

  void _scrollToCenterSelectedDay(int selectedIndex) {
    if (!_dayScrollController.hasClients) return;
    final targetOffset = selectedIndex * _dayItemWidth;
    final maxOffset = _dayScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    _dayScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Planning du Club"),
        centerTitle: true,
        automaticallyImplyLeading: false,
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
        heroTag: 'fab_planning',
        onPressed: _showAddEventDialog,
        backgroundColor: ViroColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDayPicker() {
    // Si un filtre est actif, récupérer uniquement les jours avec des événements filtrés
    if (_hasActiveFilter()) {
      // Récupérer d'abord la date de fin de saison
      return FutureBuilder<DocumentSnapshot>(
        future: appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .get(),
        builder: (context, clubSnap) {
          DateTime seasonEndDate;
          if (clubSnap.hasData) {
            final clubData = clubSnap.data?.data() as Map<String, dynamic>?;
            final timestamp = clubData?['seasonEndDate'] as Timestamp?;
            if (timestamp != null) {
              seasonEndDate = timestamp.toDate();
            } else {
              // Valeur par défaut si non définie
              final now = DateTime.now();
              seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
            }
          } else {
            final now = DateTime.now();
            seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
          }

          // Utiliser la date du premier event comme borne inférieure (inclut les jours passés)
          final lowerBound = _firstEventDate != null
              ? Timestamp.fromDate(_firstEventDate!)
              : Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 365 * 2)));

          return StreamBuilder<QuerySnapshot>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(widget.clubId)
                .collection(FirebaseCollections.events)
                .where('date', isGreaterThanOrEqualTo: lowerBound)
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(seasonEndDate))
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              // Filtrer les événements selon les filtres actifs
              final filteredEvents = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final bool placeholderTeam = _filterTeam.startsWith("Choisir");
                final bool placeholderCat = _filterCategory.startsWith("Choisir");
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

              // Extraire les dates uniques
              final Set<String> dateIds = {};
              for (var doc in filteredEvents) {
                final data = doc.data() as Map<String, dynamic>;
                final dateId = data['dateId'] as String?;
                if (dateId != null) {
                  dateIds.add(dateId);
                }
              }

              // Convertir les dateIds en DateTime
              final filteredDays = dateIds.map((dateId) {
                try {
                  final year = int.parse(dateId.substring(0, 4));
                  final month = int.parse(dateId.substring(4, 6));
                  final day = int.parse(dateId.substring(6, 8));
                  return DateTime(year, month, day);
                } catch (e) {
                  return null;
                }
              }).whereType<DateTime>().toList()
                ..sort();

              if (filteredDays.isEmpty) {
                return Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Center(
                    child: Text(
                      "Aucun événement ne correspond aux filtres",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              // Si la date sélectionnée n'est pas dans les jours filtrés,
              // préférer aujourd'hui ou le premier jour futur disponible
              if (!filteredDays.any((day) => DateUtils.isSameDay(day, _selectedDate))) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && filteredDays.isNotEmpty) {
                    final todayOrAfter = filteredDays.firstWhere(
                      (d) => !d.isBefore(DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      )),
                      orElse: () => filteredDays.last,
                    );
                    setState(() => _selectedDate = todayOrAfter);
                    final idx = filteredDays.indexWhere(
                      (d) => DateUtils.isSameDay(d, todayOrAfter),
                    );
                    if (idx >= 0 && _dayScrollController.hasClients) {
                      _scrollToCenterSelectedDay(idx);
                    }
                  }
                });
              }

              final viewportWidth = MediaQuery.of(context).size.width;
              final sidePadding = (viewportWidth - _dayItemWidth) / 2;
              final today = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );

              return Container(
                height: 110,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.white,
                child: ListView.builder(
                  controller: _dayScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: filteredDays.length,
                  itemBuilder: (context, index) {
                    final date = filteredDays[index];
                    final isSelected = DateUtils.isSameDay(date, _selectedDate);
                    final isPast = date.isBefore(today);
                    final isToday = DateUtils.isSameDay(date, today);

                    Color bgColor;
                    Color borderColor;
                    Color dayNumColor;
                    Color dayLabelColor;
                    Color monthColor;

                    if (isSelected) {
                      bgColor = isPast ? Colors.grey.shade500 : ViroColors.primary;
                      borderColor = bgColor;
                      dayNumColor = Colors.white;
                      dayLabelColor = Colors.white;
                      monthColor = Colors.white70;
                    } else if (isPast) {
                      bgColor = Colors.grey.shade100;
                      borderColor = Colors.grey.shade300;
                      dayNumColor = Colors.grey.shade400;
                      dayLabelColor = Colors.grey.shade400;
                      monthColor = Colors.grey.shade400;
                    } else {
                      bgColor = Colors.grey[50]!;
                      borderColor = ViroColors.borderColor;
                      dayNumColor = Colors.black;
                      dayLabelColor = Colors.grey;
                      monthColor = Colors.grey;
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = date);
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
                          color: bgColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E', 'fr_FR').format(date).toUpperCase(),
                              style: TextStyle(
                                color: dayLabelColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                color: dayNumColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                              style: TextStyle(color: monthColor, fontSize: 10),
                            ),
                            if (isToday && !isSelected)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: ViroColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      );
    }

    // Pas de filtre actif : afficher tous les jours depuis le premier event
    if (!_firstEventLoaded) {
      return Container(
        height: 110,
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final days = _getDays();

    // Aucun événement recensé → ne rien afficher
    if (days.isEmpty) return const SizedBox.shrink();

    final viewportWidth = MediaQuery.of(context).size.width;
    final sidePadding = (viewportWidth - _dayItemWidth) / 2;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

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
          final date = days[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isPast = date.isBefore(today);
          final isToday = DateUtils.isSameDay(date, today);

          Color bgColor;
          Color borderColor;
          Color dayNumColor;
          Color dayLabelColor;
          Color monthColor;

          if (isSelected) {
            bgColor = isPast ? Colors.grey.shade500 : ViroColors.primary;
            borderColor = bgColor;
            dayNumColor = Colors.white;
            dayLabelColor = Colors.white;
            monthColor = Colors.white70;
          } else if (isPast) {
            bgColor = Colors.grey.shade100;
            borderColor = Colors.grey.shade300;
            dayNumColor = Colors.grey.shade400;
            dayLabelColor = Colors.grey.shade400;
            monthColor = Colors.grey.shade400;
          } else {
            bgColor = Colors.grey[50]!;
            borderColor = ViroColors.borderColor;
            dayNumColor = Colors.black;
            dayLabelColor = Colors.grey;
            monthColor = Colors.grey;
          }

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
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
                color: bgColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr_FR').format(date).toUpperCase(),
                    style: TextStyle(
                      color: dayLabelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: dayNumColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                    style: TextStyle(color: monthColor, fontSize: 10),
                  ),
                  if (isToday && !isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: ViroColors.primary,
                        shape: BoxShape.circle,
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
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.teams)
          .snapshots(),
      builder: (context, snapshot) {
        final teamNamesSet = <String>{};
        final categoriesSet = <String>{};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final teamName = data['name'] as String?;
            final category = data['category'] as String?;
            if (teamName != null && teamName.isNotEmpty) {
              teamNamesSet.add(teamName);
            }
            if (category != null && category.isNotEmpty) {
              categoriesSet.add(category);
            }
          }
        }

        final sortedTeams = teamNamesSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final sortedCategories = categoriesSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        final teamsList = ["Choisir une équipe", ...sortedTeams];
        final catList = ["Choisir une catégorie", ...sortedCategories];

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
                  isCategoryFilter: true,
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
    bool isCategoryFilter = false,
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
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: isCategoryFilter && e != "Choisir une catégorie"
                      ? Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: ViroColors.getCategoryColor(e),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        )
                      : Text(e, style: const TextStyle(fontSize: 13)),
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
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.events)
          .where('dateId', isEqualTo: dateId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ViroLoader(size: 40));

        var docs = snapshot.data!.docs;
        
        // Récupérer la date de fin de saison du club
        return FutureBuilder<DocumentSnapshot>(
          future: appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(widget.clubId)
              .get(),
          builder: (context, clubSnap) {
            DateTime? seasonEndDate;
            if (clubSnap.hasData) {
              final clubData = clubSnap.data?.data() as Map<String, dynamic>?;
              final timestamp = clubData?['seasonEndDate'] as Timestamp?;
              if (timestamp != null) {
                seasonEndDate = timestamp.toDate();
              } else {
                // Valeur par défaut si non définie
                final now = DateTime.now();
                seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
              }
            } else {
              final now = DateTime.now();
              seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
            }

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

            final teamNames = filteredDocs
                .map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = data['teamName'] as String? ??
                      (data['teamNames'] as List?)
                          ?.whereType<String>()
                          .firstOrNull;
                  return name;
                })
                .whereType<String>()
                .toSet()
                .toList();

            return FutureBuilder<Map<String, int>>(
              future: _getPendingCountsForTeamNames(widget.clubId, teamNames),
              builder: (context, pendingSnap) {
                final pendingByTeam = pendingSnap.data ?? {};
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final docId = filteredDocs[index].id;
                    final teamName = data['teamName'] as String? ??
                        (data['teamNames'] as List?)
                            ?.whereType<String>()
                            .firstOrNull ??
                        '';
                    final pendingCount = pendingByTeam[teamName] ?? 0;

                    // Vérifier si l'événement est terminé (après la fin de saison)
                    bool isSeasonCompleted = false;
                    if (seasonEndDate != null &&
                        data['type'] == 'Entraînement') {
                      final eventDate =
                          (data['date'] as Timestamp?)?.toDate();
                      if (eventDate != null &&
                          eventDate.isAfter(seasonEndDate)) {
                        isSeasonCompleted = true;
                      }
                    }

                    return _buildEventCard(
                      data,
                      editing: _deleteMode,
                      isSeasonCompleted: isSeasonCompleted,
                      pendingCount: pendingCount,
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

  /// Retourne pour chaque nom d'équipe le nombre de joueurs en attente (sans compte).
  Future<Map<String, int>> _getPendingCountsForTeamNames(
    String clubId,
    List<String> teamNames,
  ) async {
    if (teamNames.isEmpty) return {};
    final names = teamNames.toSet().toList();
    final batch = names.length > 30 ? names.sublist(0, 30) : names;
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', whereIn: batch)
        .get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? '';
      final list = data['pendingPlayerIds'] as List?;
      map[name] = list?.length ?? 0;
    }
    return map;
  }

  Widget _buildEventCard(
    Map<String, dynamic> data, {
    bool editing = false,
    bool isSeasonCompleted = false,
    int pendingCount = 0,
    VoidCallback? onTap,
  }) {
    final bool canceled = data['canceled'] == true;
    final bool isMatch = data['type'] == 'Match';
    final bool allDay = data['startTime'] == null && data['endTime'] == null;
    final String time = isMatch
        ? (data['meetingTime']?.toString() ?? data['startTime']?.toString() ?? "--:--")
        : (allDay ? "ALL DAY" : (data['startTime']?.toString() ?? "--:--"));
    final String? endTimeStr = data['endTime']?.toString();
    final String type = (data['title'] ?? data['type'] ?? "Événement").toString();
    final String teamName = _audienceText(data);
    final String? meetingLoc = data['meetingLocation']?.toString().trim();
    final String locationDisplay = isMatch
        ? ((meetingLoc != null && meetingLoc.isNotEmpty)
            ? "RDV $meetingLoc"
            : (data['location']?.toString() ?? "Stade du club"))
        : (data['location']?.toString() ?? "Stade du club");

    final String eventCategory = (data['category'] as String?)?.trim() ?? '';
    // Couleur par catégorie (orange et vert réservés aux badges licence)
    final Color teamColor = eventCategory.isNotEmpty
        ? ViroColors.getCategoryColor(eventCategory)
        : ViroColors.primary;

    final Map<String, dynamic> attendance = Map<String, dynamic>.from(
      data['attendance'] ?? {},
    );
    int presentCount = attendance.values.where((v) => v == 'present').length;
    int absentCount = attendance.values.where((v) => v == 'absent').length;
    if (presentCount == 0 && absentCount == 0) {
      presentCount = _countList(data['presentIds']);
      absentCount = _countList(data['absentIds']);
    }
    final int totalResponded = presentCount + absentCount;
    final int unknownFromMembers = _countList(data['teamMemberIds']) > 0
        ? (_countList(data['teamMemberIds']) - totalResponded).clamp(0, 9999)
        : 0;
    final int noResponseCount = unknownFromMembers + pendingCount;

    final Color borderColor = canceled
        ? Colors.grey
        : (isSeasonCompleted
            ? Colors.grey.shade400
            : teamColor.withValues(alpha: 0.5));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: canceled
            ? Colors.grey.shade300
            : (isSeasonCompleted ? Colors.grey.shade100 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editing)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Colors.redAccent.withValues(alpha: 0.9),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: teamColor,
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color: teamColor,
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
                                    color: teamColor,
                                  ),
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
                              _truncate(teamName),
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
                                    _truncate(locationDisplay, max: 50),
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
                          color: teamColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: teamColor,
                            ),
                            Text(
                              endTimeStr,
                              style: TextStyle(
                                color: teamColor,
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

  int _timeToMinutes(dynamic time) {
    if (time == null) return 0;
    final str = time.toString().trim();
    try {
      // Format 24h "HH:mm" (ex: "18:00")
      final parts = str.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      }
      return 0;
    } catch (e) {
      AppLogger.instance.error('_timeToMinutes parse failed', error: e, context: {'time': str});
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
              title: const Text("Supprimer cet évènement"),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteEvent(docId);
              },
            ),
            if (canCancelAll)
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text("Supprimer toutes les occurrences"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteRecurring(data);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSingle(String docId) async {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .doc(docId)
        .set({'canceled': true}, SetOptions(merge: true));
  }

  Future<void> _cancelRecurring(Map<String, dynamic> data) async {
    final team = data['teamName'];
    final type = data['type'];
    final startTime = data['startTime'];
    final query = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .where('teamName', isEqualTo: team)
        .where('type', isEqualTo: type)
        .where('startTime', isEqualTo: startTime)
        .get();

    final batch = appFirestore.batch();
    for (final doc in query.docs) {
      batch.set(doc.reference, {'canceled': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _uncancelSingle(String docId) async {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .doc(docId)
        .set({'canceled': false}, SetOptions(merge: true));
  }

  Future<void> _uncancelRecurring(Map<String, dynamic> data) async {
    final team = data['teamName'];
    final type = data['type'];
    final startTime = data['startTime'];
    final query = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .where('teamName', isEqualTo: team)
        .where('type', isEqualTo: type)
        .where('startTime', isEqualTo: startTime)
        .get();

    final batch = appFirestore.batch();
    for (final doc in query.docs) {
      batch.set(doc.reference, {'canceled': false}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _deleteEvent(String docId) async {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .doc(docId)
        .delete();
  }

  Future<void> _deleteRecurring(Map<String, dynamic> data) async {
    final team = data['teamName'];
    final type = data['type'];
    final startTime = data['startTime'];
    
    // Si on a le seriesId (nouvelle méthode), on l'utilise
    final seriesId = data['seriesId'] as String?;
    
    Query query;
    if (seriesId != null && seriesId.isNotEmpty) {
      query = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.events)
          .where('seriesId', isEqualTo: seriesId);
    } else {
      // Ancienne méthode de rapprochement
      query = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.events)
          .where('teamName', isEqualTo: team)
          .where('type', isEqualTo: type)
          .where('startTime', isEqualTo: startTime);
    }

    final querySnap = await query.get();
    final batch = appFirestore.batch();
    for (final doc in querySnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- LOGIQUE AJOUT ÉVÉNEMENT ---
  void _showAddEventDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAddEventPage(
          clubId: widget.clubId,
          initialDate: _selectedDate,
        ),
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
