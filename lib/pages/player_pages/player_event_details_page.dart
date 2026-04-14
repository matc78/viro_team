import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/event_service.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../utils/event_attendance_stats.dart';
import '../../utils/app_logger.dart';
import '../../utils/avatar_moderation.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/team_avatar_upload.dart';
import '../../widget/full_screen_image_page.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';

class PlayerEventDetailsPage extends StatelessWidget {
  final String clubId;
  final String eventId;
  const PlayerEventDetailsPage({
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

  static Future<String?> _getTeamIdByName(String clubId, String teamName) async {
    if (teamName.isEmpty) return null;
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
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

        final String currentUserId =
            FirebaseAuth.instance.currentUser?.uid ?? "";

        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(title: Text(type), elevation: 0),
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

                    // --- INFOS PRATIQUES ---
                    _buildInfoSection(location, event),

                    // --- STATISTIQUES (cliquables pour les joueurs) ---
                    _buildAttendanceSummary(
                      context,
                      attendance,
                      teamMembers,
                      clubId,
                      eventId,
                      currentUserId,
                      pendingPlayerIds,
                    ),

                    // --- LISTES DES JOUEURS ---
                    _buildAttendanceTabs(
                      context,
                      attendance,
                      teamMembers,
                      clubId,
                      eventId,
                      pendingPlayerIds,
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
                GestureDetector(
                  onTap: () => showFullScreenImage(
                    context,
                    teamAvatarUrl,
                    onEditTap: (ctx) async {
                      final teamId = await _getTeamIdByName(clubId, team);
                      if (teamId == null || !ctx.mounted) return;
                      await pickAndUploadTeamAvatar(
                        ctx,
                        clubId: clubId,
                        teamId: teamId,
                        teamName: team,
                      );
                    },
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        ViroColors.primary.withValues(alpha: 0.1),
                    backgroundImage:
                        CachedNetworkImageProvider(teamAvatarUrl),
                  ),
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
    final startTime = event['startTime'];
    final endTime = event['endTime'];
    final bool allDay = startTime == null && endTime == null;
    final clubName = event['clubName'] as String? ?? "Club";
    final bool isMatch = (event['type'] as String?) == 'Match';
    final String meetingTime = event['meetingTime']?.toString() ?? '--:--';

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
          if (isMatch) ...[
            _infoRow(Icons.groups_outlined, "Rendez-vous", "$meetingTime · $location"),
            const Divider(height: 30),
            _infoRow(
              Icons.sports_score_outlined,
              "Match",
              "${allDay ? 'Toute la journée' : '${startTime ?? '--:--'}${endTime != null ? ' - $endTime' : ''}'} · $location",
            ),
          ] else ...[
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
          const Divider(height: 30),
          _infoRow(Icons.emoji_events_outlined, "Club", formatClubNameWithEmoji(clubName, event['clubSport'] as String?)),
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

  Future<void> _toggleAttendance(
    BuildContext context,
    String clubId,
    String eventId,
    String? newStatus,
  ) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) {
      AppLogger.instance.warning(
        'Tentative de mise à jour de présence sans utilisateur connecté',
        {'clubId': clubId, 'eventId': eventId},
      );
      return;
    }

    try {
      final ok = await _eventService.updatePlayerAttendanceWithStats(
        clubId: clubId,
        eventId: eventId,
        userId: uid,
        newStatus: newStatus,
      );
      if (!ok) {
        if (context.mounted) {
          FirebaseErrorHandler.showErrorSnackBar(
            context,
            Exception('Mise à jour impossible'),
          );
        }
        return;
      }
      AppLogger.instance.info('Mise à jour de présence', {
        'userId': uid,
        'clubId': clubId,
        'eventId': eventId,
        'status': newStatus ?? 'none',
      });
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la mise à jour de présence',
        error: e,
        context: {
          'userId': uid,
          'clubId': clubId,
          'eventId': eventId,
          'status': newStatus ?? 'none',
        },
      );
      if (context.mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Widget _buildAttendanceSummary(
    BuildContext context,
    Map<String, dynamic> attendance,
    List<dynamic> teamMembers,
    String clubId,
    String eventId,
    String currentUserId,
    List<String> pendingPlayerIds,
  ) {
    final s = computeRsvpSummaryExcludingPendingMembers(
      attendance: attendance,
      teamMemberIds: teamMembers,
      teamPendingPlayerIds: pendingPlayerIds.toSet(),
    );
    final present = s.present;
    final absent = s.absent;
    final noResponse = s.sansReponse;

    final String currentStatus =
        (attendance[currentUserId] as String?) ?? 'none';

    // L'utilisateur peut modifier sa présence s'il est convoqué
    // (son UID figure dans attendance ou teamMemberIds).
    final bool isConvoked = currentUserId.isNotEmpty &&
        (attendance.containsKey(currentUserId) ||
            teamMembers.any((id) => id.toString() == currentUserId));

    return _summaryRow(
      present: present,
      absent: absent,
      noResponse: noResponse,
      currentStatus: currentStatus,
      isPlayer: isConvoked,
      context: context,
      clubId: clubId,
      eventId: eventId,
    );
  }

  Widget _summaryRow({
    required int present,
    required int absent,
    required int noResponse,
    required String currentStatus,
    required bool isPlayer,
    required BuildContext context,
    required String clubId,
    required String eventId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statBadge(
            "PRÉSENTS",
            present,
            ViroColors.primary,
            isSelected: isPlayer && currentStatus == 'present',
            isPlayer: isPlayer,
            onTap: isPlayer
                ? () => _toggleAttendance(context, clubId, eventId, 'present')
                : null,
          ),
          const SizedBox(width: 10),
          _statBadge(
            "ABSENTS",
            absent,
            Colors.redAccent,
            isSelected: isPlayer && currentStatus == 'absent',
            isPlayer: isPlayer,
            onTap: isPlayer
                ? () => _toggleAttendance(context, clubId, eventId, 'absent')
                : null,
          ),
          const SizedBox(width: 10),
          _statBadge(
            "SANS RÉPONSE",
            noResponse,
            Colors.orange,
            isSelected: isPlayer && currentStatus == 'none',
            isPlayer: isPlayer,
            onTap: isPlayer
                ? () => _toggleAttendance(context, clubId, eventId, null)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _statBadge(
    String label,
    int count,
    Color color, {
    required bool isSelected,
    required bool isPlayer,
    VoidCallback? onTap,
  }) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(isSelected && isPlayer ? 1.03 : 1.0),
      transformAlignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected && isPlayer
              ? color
              : color.withValues(alpha: 0.3),
          width: isSelected && isPlayer ? 2.0 : 1.0,
        ),
        boxShadow: isSelected && isPlayer
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (isSelected && isPlayer) ...[
            Icon(Icons.check_circle_rounded, color: color, size: 20),
            const SizedBox(height: 4),
          ],
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
      );
    }

    return Expanded(child: child);
  }

  Widget _buildAttendanceTabs(
    BuildContext context,
    Map<String, dynamic> attendance,
    List<dynamic> teamMembers,
    String clubId,
    String eventId,
    List<String> pendingPlayerIds,
  ) {
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
    final hasPending = pendingPlayerIds.isNotEmpty;

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
          if (!hasUsers && !hasPending)
            const Center(child: Text("Aucun joueur convoqué"))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasUsers)
                  FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                    future: fetchUsersBatch(userIds),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: ViroLoader(size: 40));
                      }
                      final docs = snap.data!;
                      final userMap = {
                        for (final doc in docs)
                          doc.id: doc.data() as Map<String, dynamic>,
                      };

                      return Column(
                        children: sortedEntries.map((entry) {
                          final userId = entry.key.toString();
                          final user = userMap[userId] ?? <String, dynamic>{};
                          if (user.isEmpty) return const SizedBox.shrink();
                          return _buildPlayerTile(
                            context,
                            userId,
                            user,
                            entry.value,
                            clubId,
                            eventId,
                          );
                        }).toList(),
                      );
                    },
                  ),
                if (hasPending) ...[
                  if (hasUsers) const SizedBox(height: 12),
                  FutureBuilder<
                      List<DocumentSnapshot<Map<String, dynamic>>>>(
                    future: _fetchPendingMembersBatch(
                      clubId,
                      pendingPlayerIds,
                    ),
                    builder: (context, pendingSnap) {
                      if (!pendingSnap.hasData) {
                        return const SizedBox.shrink();
                      }
                      final pendingDocs = pendingSnap.data!;
                      return Column(
                        children: pendingDocs.asMap().entries.map((e) {
                          final id = pendingPlayerIds[e.key];
                          final doc = e.value;
                          final data = doc.data() ?? {};
                          if (data.isEmpty) return const SizedBox.shrink();
                          return _buildPendingPlayerTile(id, data);
                        }).toList(),
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

  Widget _buildPendingPlayerTile(
    String pendingId,
    Map<String, dynamic> data,
  ) {
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final displayName = '$firstName $lastName'.trim().isEmpty
        ? email
        : '$firstName $lastName'.trim();

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
    String userId,
    Map<String, dynamic> user,
    dynamic status,
    String clubId,
    String eventId,
  ) {
    Color statusColor = status == 'present'
        ? ViroColors.primary
        : (status == 'absent' ? Colors.red : Colors.orange);

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool isCurrentUser = uid == userId;
    String nextStatus() {
      if (status == 'present') return 'absent';
      return 'present';
    }

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
          Expanded(
            child: UserDisplayTile(
              userId: userId,
              firstName: user['firstName'] as String?,
              lastName: user['lastName'] as String?,
              avatarUrl: effectiveAvatarUrl(user),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: isCurrentUser
                ? () =>
                      _toggleAttendance(context, clubId, eventId, nextStatus())
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: isCurrentUser
                    ? Border.all(color: statusColor.withValues(alpha: 0.5))
                    : null,
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
          ),
        ],
      ),
    );
  }
}
