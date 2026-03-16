import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/services/event_service.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
import '../../services/user_session.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firestore_instance.dart';
import '../../utils/avatar_moderation.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import 'admin_edit_event_page.dart';
import 'admin_training_session_page.dart';

class AdminEventDetailsPage extends StatelessWidget {
  final String clubId;
  final String eventId;

  const AdminEventDetailsPage({
    super.key,
    required this.clubId,
    required this.eventId,
  });

  static final EventService _eventService = EventService();

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

  /// Récupère les IDs joueurs + pending_members des **autres** équipes ayant la même catégorie
  /// (exclut l'équipe de l'événement). Utilisé pour "Convoquer joueur" cross-équipe.
  static Future<List<String>> _getPlayerIdsFromOtherTeamsSameCategory(
    String clubId,
    String currentTeamName,
  ) async {
    if (currentTeamName.isEmpty) return [];
    final teamSnap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: currentTeamName)
        .limit(1)
        .get();
    if (teamSnap.docs.isEmpty) return [];
    final category = teamSnap.docs.first.data()['category'] as String?;
    if (category == null || category.isEmpty) return [];

    final teamsSnap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('category', isEqualTo: category)
        .get();

    final Set<String> allIds = {};
    for (final doc in teamsSnap.docs) {
      final data = doc.data();
      final name = data['name'] as String?;
      if (name == currentTeamName) continue; // exclure l'équipe de l'événement

      final playerList = data['playerIds'] as List?;
      if (playerList != null) {
        for (final id in playerList) {
          final s = _normalizeMemberId(id);
          if (s.isNotEmpty) allIds.add(s);
        }
      }
      final pendingList = data['pendingPlayerIds'] as List?;
      if (pendingList != null) {
        for (final id in pendingList) {
          final s = _normalizeMemberId(id);
          if (s.isNotEmpty) allIds.add(s);
        }
      }
    }
    return allIds.toList();
  }

  /// Normalise un id pour comparaison (Firestore peut renvoyer String ou autre).
  static String _normalizeMemberId(dynamic id) {
    if (id == null) return '';
    return id.toString().trim();
  }

  static Future<void> _showAddPlayerDialog(
    BuildContext context,
    String clubId,
    String eventId,
    String teamName,
    List<dynamic> currentTeamMemberIds,
  ) async {
    // Re-fetch event depuis le serveur pour avoir les teamMemberIds à jour
    final eventSnap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events)
        .doc(eventId)
        .get(const GetOptions(source: Source.server));
    final rawTeamMemberIds = eventSnap.data()?['teamMemberIds'];
    final List<dynamic> fromEvent = rawTeamMemberIds is List
        ? rawTeamMemberIds
        : (currentTeamMemberIds.isNotEmpty ? currentTeamMemberIds : []);
    final convoquedSet = <String>{
      for (final e in fromEvent)
        if (_normalizeMemberId(e).isNotEmpty) _normalizeMemberId(e),
    };

    // Joueurs et pending_members des **autres** équipes (même catégorie uniquement)
    final addableIds = await _getPlayerIdsFromOtherTeamsSameCategory(clubId, teamName);
    final notYetConvoqued = addableIds
        .where((id) {
          final n = _normalizeMemberId(id);
          return n.isNotEmpty && !convoquedSet.contains(n);
        })
        .toList();

    // Emails des pending déjà convoqués (éviter doublon par email)
    final convoquedList = convoquedSet.toList();
    final convoquedUserDocs = await fetchUsersBatch(convoquedList);
    final convoquedUserMap = <String, Map<String, dynamic>>{
      for (final d in convoquedUserDocs) d.id: d.data() as Map<String, dynamic>,
    };
    final convoquedPendingIds = convoquedList
        .where((id) => (convoquedUserMap[id] ?? {}).isEmpty)
        .toList();
    final convoquedPendingDocs = await _fetchPendingMembersBatch(clubId, convoquedPendingIds);
    final convoquedEmails = <String>{};
    for (final doc in convoquedPendingDocs) {
      final email = (doc.data()?['email'] as String?)?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) convoquedEmails.add(email);
    }

    // Infos des candidats pour affichage et filtre email
    final notYetUserDocs = await fetchUsersBatch(notYetConvoqued);
    final notYetUserMap = <String, Map<String, dynamic>>{
      for (final d in notYetUserDocs) d.id: d.data() as Map<String, dynamic>,
    };
    final notYetPendingIds = notYetConvoqued
        .where((id) => (notYetUserMap[id] ?? {}).isEmpty)
        .toList();
    final notYetPendingDocs = await _fetchPendingMembersBatch(clubId, notYetPendingIds);
    final notYetPendingMap = <String, Map<String, dynamic>>{};
    for (var i = 0; i < notYetPendingIds.length && i < notYetPendingDocs.length; i++) {
      final data = notYetPendingDocs[i].data();
      if (data != null) notYetPendingMap[notYetPendingIds[i]] = data;
    }
    final displayIds = notYetConvoqued.where((id) {
      if ((notYetUserMap[id] ?? {}).isNotEmpty) return true;
      final email = ((notYetPendingMap[id] ?? {})['email'] as String?)?.trim().toLowerCase() ?? '';
      return email.isEmpty || !convoquedEmails.contains(email);
    }).toList();

    if (!context.mounted) return;
    if (displayIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Aucun joueur d'une autre équipe de la catégorie à convoquer.",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          // Données déjà chargées pour le filtre email (uniquement les entrées pour displayIds)
          final userMap = <String, Map<String, dynamic>>{
            for (final id in displayIds) id: notYetUserMap[id] ?? <String, dynamic>{},
          };
          final pendingMap = <String, Map<String, dynamic>>{
            for (final id in displayIds) id: notYetPendingMap[id] ?? <String, dynamic>{},
          };

          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Convoquer un joueur",
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayIds.length,
                    itemBuilder: (context, index) {
                      final id = displayIds[index];
                      final user = userMap[id] ?? <String, dynamic>{};
                      final pendingData = pendingMap[id];

                      if (user.isNotEmpty) {
                        final firstName =
                            user['firstName'] as String? ?? '';
                        final lastName = user['lastName'] as String? ?? '';
                        final name =
                            '$firstName $lastName'.trim().isEmpty
                                ? 'Joueur'
                                : '$firstName $lastName'.trim();
                        final avatarUrl = effectiveAvatarUrl(user);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null &&
                                    avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(name),
                          onTap: () => _addConvoquedAndPop(
                            ctx,
                            clubId,
                            eventId,
                            id,
                            name,
                          ),
                        );
                      }

                      if (pendingData != null && pendingData.isNotEmpty) {
                        final firstName =
                            pendingData['firstName'] as String? ?? '';
                        final lastName =
                            pendingData['lastName'] as String? ?? '';
                        final email = pendingData['email'] as String? ?? '';
                        final name = '$firstName $lastName'.trim().isEmpty
                            ? (email.isNotEmpty ? email : 'Compte en attente')
                            : '$firstName $lastName'.trim();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                ViroColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person_outline,
                              color: ViroColors.primary,
                              size: 22,
                            ),
                          ),
                          title: Text(name),
                          subtitle: pendingData['email'] != null
                              ? Text(
                                  pendingData['email'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                          onTap: () => _addConvoquedAndPop(
                            ctx,
                            clubId,
                            eventId,
                            id,
                            name,
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            );
          },
      ),
    );
  }

  static Future<void> _addConvoquedAndPop(
    BuildContext ctx,
    String clubId,
    String eventId,
    String memberId,
    String displayName,
  ) async {
    Navigator.pop(ctx);
    try {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .update({
        'teamMemberIds': FieldValue.arrayUnion([memberId]),
        'attendance.$memberId': 'none',
      });
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text("$displayName convoqué")),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text("Erreur : ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot?>(
      stream: _eventService.watchEvent(clubId, eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: ViroLoader(size: 60)));
        }
        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return const Scaffold(
            body: Center(child: Text("Évènement introuvable")),
          );
        }

        final event = doc.data() as Map<String, dynamic>;
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
          appBar: AppBar(
            title: Text(type),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminEditEventPage(
                        clubId: clubId,
                        eventId: eventId,
                        eventData: event,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: FutureBuilder<List<String>>(
            future: _getPendingPlayerIdsForTeam(clubId, team),
            initialData: const <String>[],
            builder: (context, pendingSnap) {
              final pendingPlayerIds = pendingSnap.data ?? [];
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER INFO ---
                    _buildEventHeader(context, clubId, date, event, team, categories),

                    // --- BOUTON LANCER L'ENTRAÎNEMENT (jour J + coach) ---
                    _buildLaunchTrainingButton(context, date, team, event),

                    // --- INFOS PRATIQUES ---
                    _buildInfoSection(location, event),

                    // --- STATISTIQUES ---
                    _buildAttendanceSummary(
                      attendance,
                      pendingCount: pendingPlayerIds.length,
                    ),

                    // --- LISTES DES JOUEURS ---
                    _buildAttendanceTabs(
                      context,
                      clubId,
                      eventId,
                      attendance,
                      teamMembers,
                      pendingPlayerIds,
                      eventType: type,
                      teamName: team,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Vérifie si l'utilisateur courant est coach de l'équipe donnée.
  static Future<bool> _isCurrentUserCoachOfTeam(
    String clubId,
    String teamName,
  ) async {
    final uid = UserSession().currentUser?.uid;
    if (uid == null || teamName.isEmpty) return false;
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;
    final coachIds =
        (snap.docs.first.data()['coachIds'] as List?)?.cast<String>() ?? [];
    return coachIds.contains(uid);
  }

  /// Affiche le bouton "Lancer l'entraînement" le jour J pour les coachs de l'équipe.
  Widget _buildLaunchTrainingButton(
    BuildContext context,
    DateTime eventDate,
    String teamName,
    Map<String, dynamic> event,
  ) {
    final type = event['type'] as String? ?? '';
    if (type != 'Entraînement') return const SizedBox.shrink();

    final now = DateTime.now();
    final isToday = eventDate.year == now.year &&
        eventDate.month == now.month &&
        eventDate.day == now.day;
    if (!isToday) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _isCurrentUserCoachOfTeam(clubId, teamName),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminTrainingSessionPage(
                      clubId: clubId,
                      eventId: eventId,
                      teamName: teamName,
                      eventDate: eventDate,
                      sport: event['sport'] as String?,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_fill),
              label: const Text("Lancer l'entraînement"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Récupère l'URL de l'avatar de l'équipe par nom (ou null).
  static Future<String?> _getTeamAvatarUrl(String clubId, String teamName) async {
    if (teamName.isEmpty) return null;
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final url = (snap.docs.first.data()['avatarUrl'] as String?)?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Widget _buildEventHeader(
    BuildContext context,
    String clubId,
    DateTime date,
    Map<String, dynamic> event,
    String team,
    List<String> categories,
  ) {
    final bool canceled = event['canceled'] == true;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<String?>(
        future: _getTeamAvatarUrl(clubId, team),
        builder: (context, avatarSnap) {
          final teamAvatarUrl = avatarSnap.data;
          final hasTeamAvatar =
              teamAvatarUrl != null && teamAvatarUrl.isNotEmpty;
          return Column(
            children: [
              if (canceled) ...[
                const Text(
                  "ANNULÉ",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (hasTeamAvatar) ...[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
                  backgroundImage: CachedNetworkImageProvider(teamAvatarUrl),
                ),
                const SizedBox(height: 8),
              ],
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
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String location, Map<String, dynamic> event) {
    final bool isMatch = event['type'] == 'Match';
    final startTime = event['startTime'];
    final endTime = event['endTime'];
    final bool allDay = startTime == null && endTime == null;

    final reminderConfig = event['reminderConfig'] as Map<String, dynamic>?;
    final List<dynamic> reminders = reminderConfig?['reminders'] ?? [];

    if (isMatch) {
      final String matchLocation = event['location']?.toString() ?? "Non défini";
      final String matchTime = startTime?.toString() ?? '--:--';
      final String rdvLocation =
          event['meetingLocation']?.toString().trim() ?? "Non défini";
      final String rdvTime = event['meetingTime']?.toString() ?? '--:--';

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
              Icons.location_on_outlined,
              "Lieu du match",
              matchLocation,
            ),
            const Divider(height: 30),
            _infoRow(
              Icons.access_time_rounded,
              "Heure du match",
              matchTime,
            ),
            const Divider(height: 30),
            _infoRow(
              Icons.place_outlined,
              "Lieu du RDV",
              rdvLocation.isEmpty ? "Non défini" : rdvLocation,
            ),
            const Divider(height: 30),
            _infoRow(
              Icons.access_time_rounded,
              "Heure du RDV",
              rdvTime,
            ),
            if (reminders.isNotEmpty) ...[
              const Divider(height: 30),
              _buildRemindersList(reminders),
            ],
          ],
        ),
      );
    }

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
          if (reminders.isNotEmpty) ...[
            const Divider(height: 30),
            _buildRemindersList(reminders),
          ],
        ],
      ),
    );
  }

  Widget _buildRemindersList(List<dynamic> reminders) {
    const weekdayLabels = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: ViroColors.primary, size: 22),
            const SizedBox(width: 16),
            const Text(
              "Notifications",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: reminders.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final r = entry.value as Map<String, dynamic>;
              final time = r['time'] ?? '';
              
              String text = '';
              if (r['weekday'] != null) {
                final w = (r['weekday'] as num).toInt();
                final dayStr = w >= 1 && w <= 7 ? weekdayLabels[w - 1] : 'Jour inconnu';
                text = "Le $dayStr avant à $time";
              } else if (r['daysBefore'] != null) {
                final d = (r['daysBefore'] as num).toInt();
                text = d == 1 ? "1 jour avant à $time" : "$d jours avant à $time";
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• Notification $idx : $text",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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

  Widget _buildAttendanceSummary(
    Map<String, dynamic> attendance, {
    int pendingCount = 0,
  }) {
    int present = attendance.values.where((v) => v == 'present').length;
    int absent = attendance.values.where((v) => v == 'absent').length;
    int total = attendance.length;
    int noResponse = total - (present + absent) + pendingCount;

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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
    BuildContext context,
    String clubId,
    String eventId,
    Map<String, dynamic> attendance,
    List<dynamic> teamMembers,
    List<String> pendingPlayerIds, {
    String? eventType,
    String? teamName,
  }) {
    // 1. Préparation de la liste complète (id -> statut)
    final Map<String, dynamic> fullList = Map.from(attendance);
    for (final id in teamMembers) {
      final key = id.toString();
      if (!fullList.containsKey(key)) {
        fullList[key] = 'none';
      }
    }

    // 2. Tri par statut puis par id
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
      return (a.key).compareTo(b.key);
    });

    final userIds = sortedEntries.map((e) => e.key.toString()).toList();
    final hasUsers = sortedEntries.isNotEmpty;
    final currentIds = teamMembers.map((e) => e.toString()).toList();
    final notConvoquedPendingIds = pendingPlayerIds
        .where((id) => !currentIds.contains(id))
        .toList();
    final hasPending = notConvoquedPendingIds.isNotEmpty;
    final canAddPlayer = (eventType == 'Entraînement' || eventType == 'Match') &&
        (teamName != null && teamName.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "DÉTAILS DES PRÉSENCES",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              if (canAddPlayer)
                FutureBuilder<List<String>>(
                  future: _getPlayerIdsFromOtherTeamsSameCategory(clubId, teamName),
                  builder: (context, snap) {
                    final otherTeamPlayerIds = snap.data ?? [];
                    final notYetConvoqued = otherTeamPlayerIds
                        .where((id) => !currentIds.contains(id))
                        .toList();
                    if (notYetConvoqued.isEmpty) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: () => _showAddPlayerDialog(
                        context,
                        clubId,
                        eventId,
                        teamName,
                        currentIds,
                      ),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text("Convoquer joueur"),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasUsers && !hasPending)
            const Center(child: Text("Aucun joueur convoqué"))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasUsers)
                  FutureBuilder<Map<String, dynamic>>(
                    future: () async {
                      final userDocs = await fetchUsersBatch(userIds);
                      final uMap = <String, Map<String, dynamic>>{
                        for (final doc in userDocs)
                          doc.id: doc.data() as Map<String, dynamic>,
                      };
                      final pendingIds = userIds
                          .where((id) =>
                              !uMap.containsKey(id) ||
                              (uMap[id] ?? {}).isEmpty)
                          .toList();
                      final pendingDocs =
                          await _fetchPendingMembersBatch(clubId, pendingIds);
                      final pMap = <String, Map<String, dynamic>>{};
                      for (var i = 0;
                          i < pendingIds.length && i < pendingDocs.length;
                          i++) {
                        final data = pendingDocs[i].data();
                        if (data != null) pMap[pendingIds[i]] = data;
                      }
                      return {'userMap': uMap, 'pendingMap': pMap};
                    }(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: ViroLoader(size: 40));
                      }
                      final userMap = snap.data!['userMap']
                          as Map<String, Map<String, dynamic>>;
                      final pendingMap = snap.data!['pendingMap']
                          as Map<String, Map<String, dynamic>>;

                      final tiles = <Widget>[];
                      for (var i = 0; i < sortedEntries.length; i++) {
                        final entry = sortedEntries[i];
                        final id = entry.key.toString();
                        final user = userMap[id] ?? <String, dynamic>{};
                        final pendingData = pendingMap[id];
                        Widget? tile;
                        if (user.isNotEmpty) {
                          tile = _buildPlayerTile(
                            context,
                            clubId,
                            eventId,
                            id,
                            user,
                            entry.value,
                          );
                        } else if (pendingData != null && pendingData.isNotEmpty) {
                          tile = _buildPendingPlayerTile(
                            context,
                            clubId,
                            eventId,
                            id,
                            pendingData,
                          );
                        }
                        if (tile != null) {
                          if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 8));
                          tiles.add(tile);
                        }
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: tiles,
                      );
                    },
                  ),
                if (hasPending) ...[
                  if (hasUsers) const SizedBox(height: 12),
                  FutureBuilder<
                      List<DocumentSnapshot<Map<String, dynamic>>>>(
                    future: _fetchPendingMembersBatch(
                      clubId,
                      notConvoquedPendingIds,
                    ),
                    builder: (context, pendingSnap) {
                      if (!pendingSnap.hasData) {
                        return const SizedBox.shrink();
                      }
                      final pendingDocs = pendingSnap.data!;
                      final notConvoquedTiles = <Widget>[];
                      for (var i = 0; i < pendingDocs.length; i++) {
                        final id = notConvoquedPendingIds[i];
                        final data = pendingDocs[i].data() ?? {};
                        if (data.isEmpty) continue;
                        if (notConvoquedTiles.isNotEmpty) {
                          notConvoquedTiles.add(const SizedBox(height: 8));
                        }
                        notConvoquedTiles.add(_buildPendingPlayerTile(
                          context,
                          clubId,
                          eventId,
                          id,
                          data,
                        ));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: notConvoquedTiles,
                      );
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  static Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      _fetchPendingMembersBatch(
    String clubId,
    List<String> docIds,
  ) async {
    if (docIds.isEmpty) return [];
    final refs = docIds
        .map(
          (id) => appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .collection(FirebaseCollections.pendingMembers)
              .doc(id),
        )
        .toList();
    final snaps = await Future.wait(refs.map((r) => r.get()));
    return snaps.cast<DocumentSnapshot<Map<String, dynamic>>>().toList();
  }

  static Future<void> _removePlayerFromEvent(
    BuildContext context,
    String clubId,
    String eventId,
    String playerId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Déconvoquer le joueur"),
        content: const Text("Voulez-vous vraiment retirer ce joueur de l'événement ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Retirer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .doc(eventId)
          .update({
        'teamMemberIds': FieldValue.arrayRemove([playerId]),
        'attendance.$playerId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Joueur retiré de l'événement")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la déconvocation : $e")),
        );
      }
    }
  }

  Widget _buildPendingPlayerTile(
    BuildContext context,
    String clubId,
    String eventId,
    String pendingId,
    Map<String, dynamic> data,
  ) {
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final displayName = '$firstName $lastName'.trim().isEmpty
        ? email
        : '$firstName $lastName'.trim();

    // Pending_member : badge toujours "Compte en attente" (ils restent comptés dans SANS RÉPONSE)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.person_outline,
              color: ViroColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Compte en attente",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _removePlayerFromEvent(context, clubId, eventId, pendingId),
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

  Widget _buildPlayerTile(
    BuildContext context,
    String clubId,
    String eventId,
    String userId,
    Map<String, dynamic> user,
    dynamic status,
  ) {
    Color statusColor = status == 'present'
        ? ViroColors.primary
        : (status == 'absent' ? Colors.red : Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: UserDisplayTile(
              userId: userId,
              firstName: user['firstName'] as String?,
              lastName: user['lastName'] as String?,
              avatarUrl: effectiveAvatarUrl(user),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
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
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _removePlayerFromEvent(context, clubId, eventId, userId),
          ),
        ],
      ),
    );
  }
}
