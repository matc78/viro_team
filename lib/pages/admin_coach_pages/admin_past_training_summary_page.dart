import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
import '../../models/training_session_attendance.dart';
import '../../services/event_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/avatar_moderation.dart';
import '../../utils/event_attendance_stats.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firestore_instance.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';

/// Récapitulatif lecture seule d'un entraînement passé : réponses avant séance,
/// présences réelles, notes coach (sans section notifications).
class AdminPastTrainingSummaryPage extends StatefulWidget {
  final String clubId;
  final String eventId;

  const AdminPastTrainingSummaryPage({
    super.key,
    required this.clubId,
    required this.eventId,
  });

  @override
  State<AdminPastTrainingSummaryPage> createState() =>
      _AdminPastTrainingSummaryPageState();
}

class _AdminPastTrainingSummaryPageState
    extends State<AdminPastTrainingSummaryPage> {
  static final EventService _eventService = EventService();

  String? _playerDataSignature;
  Future<Map<String, dynamic>>? _playerDataFuture;

  Future<List<String>> _pendingIdsForTeam(String teamName) async {
    if (teamName.isEmpty) return [];
    final snap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.teams)
        .where('name', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return [];
    final list = snap.docs.first.data()['pendingPlayerIds'] as List?;
    return list?.whereType<String>().toList() ?? [];
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _fetchPendingDocs(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final refs = ids
        .map(
          (id) => appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(widget.clubId)
              .collection(FirebaseCollections.pendingMembers)
              .doc(id),
        )
        .toList();
    final snaps = await Future.wait(refs.map((r) => r.get()));
    return snaps.cast<DocumentSnapshot<Map<String, dynamic>>>().toList();
  }

  Future<Map<String, dynamic>> _loadPlayerData(Map<String, dynamic> event) async {
    final teamName = event['teamName'] as String? ?? '';
    final pendingTeamIds = await _pendingIdsForTeam(teamName);
    final attendance = Map<String, dynamic>.from(event['attendance'] ?? {});
    final teamMembers =
        (event['teamMemberIds'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    final userDocs = await fetchUsersBatch(teamMembers);
    final uMap = <String, Map<String, dynamic>>{
      for (final d in userDocs) d.id: d.data() as Map<String, dynamic>,
    };
    final pendingIds =
        teamMembers.where((id) => (uMap[id] ?? {}).isEmpty).toList();
    final pendingSnaps = await _fetchPendingDocs(pendingIds);
    final pMap = <String, Map<String, dynamic>>{};
    for (var i = 0; i < pendingIds.length && i < pendingSnaps.length; i++) {
      final data = pendingSnaps[i].data();
      if (data != null && data.isNotEmpty) pMap[pendingIds[i]] = data;
    }
    return {
      'pendingTeamIds': pendingTeamIds,
      'attendance': attendance,
      'teamMembers': teamMembers,
      'userMap': uMap,
      'pendingMap': pMap,
    };
  }

  void _ensurePlayerFuture(Map<String, dynamic> event) {
    final teamMembers =
        (event['teamMemberIds'] as List?)?.map((e) => e.toString()).join(',') ??
            '';
    final att = (event['attendance'] ?? {}).toString();
    final sig = '$teamMembers|$att';
    if (_playerDataSignature != sig) {
      _playerDataSignature = sig;
      _playerDataFuture = _loadPlayerData(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Entraînement passé'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: _eventService.watchEvent(widget.clubId, widget.eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 56));
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('Événement introuvable'));
          }
          final event = doc.data() as Map<String, dynamic>;
          final teamName = event['teamName'] as String? ?? '';
          final timestamp = event['date'] as Timestamp?;
          final date = timestamp?.toDate();
          final title = (event['title'] ?? 'Entraînement').toString();
          final location = event['location'] as String? ?? '';

          _ensurePlayerFuture(event);

          return FutureBuilder<Map<String, dynamic>>(
            future: _playerDataFuture,
            builder: (context, loaded) {
              if (!loaded.hasData) {
                return const Center(child: ViroLoader(size: 48));
              }
              final pendingTeamIds =
                  loaded.data!['pendingTeamIds'] as List<String>;
              final attendance =
                  loaded.data!['attendance'] as Map<String, dynamic>;
              final teamMembers =
                  loaded.data!['teamMembers'] as List<String>;
              final userMap =
                  loaded.data!['userMap'] as Map<String, Map<String, dynamic>>;
              final pendingMap =
                  loaded.data!['pendingMap'] as Map<String, Map<String, dynamic>>;

              final sessionAttendance = Map<String, dynamic>.from(
                event['sessionAttendance'] ?? {},
              );
              final sessionNotes = event['sessionNotes'] as String?;

              final pendingSet = pendingTeamIds.toSet();
              final preRsvp = computeRsvpSummaryExcludingPendingMembers(
                attendance: attendance,
                teamMemberIds: teamMembers,
                teamPendingPlayerIds: pendingSet,
              );
              final prePresent = preRsvp.present;
              final preAbsent = preRsvp.absent;
              final noResponse = preRsvp.sansReponse;

              final eligibleSessionIds = teamMembers
                  .where((id) => !pendingSet.contains(id))
                  .toList();
              int presentN = 0, lateN = 0, absentN = 0;
              for (final id in eligibleSessionIds) {
                final v = sessionAttendance[id];
                if (v is! Map) continue;
                final st = (v['status'] as String?) ?? '';
                if (st == 'present') {
                  presentN++;
                } else if (st == 'late') {
                  lateN++;
                } else if (st == 'absent') {
                  absentN++;
                }
              }
              final convocatedEligible = eligibleSessionIds.length;
              final unmarked =
                  convocatedEligible - presentN - lateN - absentN;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerCard(
                      title: title,
                      date: date,
                      teamName: teamName,
                      location: location,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'RÉPONSES AVANT L\'ENTRAÎNEMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _badgeRow(
                      [
                        _Badge('PRÉSENTS', prePresent, ViroColors.primary),
                        _Badge('ABSENTS', preAbsent, Colors.redAccent),
                        _Badge('SANS RÉP.', noResponse, Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _playerListPre(
                      teamMembers: teamMembers,
                      attendance: attendance,
                      userMap: userMap,
                      pendingMap: pendingMap,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'PRÉSENCE SUR LA SÉANCE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _badgeRow(
                      [
                        _Badge('PRÉSENTS', presentN, ViroColors.primary),
                        _Badge('RETARDS', lateN, Colors.orange),
                        _Badge('ABSENTS', absentN, Colors.redAccent),
                        _Badge('NON POINTÉS', unmarked, Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _playerListSession(
                      teamMembers: teamMembers,
                      sessionAttendance: sessionAttendance,
                      userMap: userMap,
                      pendingMap: pendingMap,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'NOTES DU COACH',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ViroColors.borderColor),
                      ),
                      child: Text(
                        (sessionNotes != null && sessionNotes.trim().isNotEmpty)
                            ? sessionNotes.trim()
                            : 'Aucune note pour cette séance.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: sessionNotes != null &&
                                  sessionNotes.trim().isNotEmpty
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _headerCard({
    required String title,
    required DateTime? date,
    required String teamName,
    required String location,
  }) {
    final dateStr = date != null
        ? DateFormat("EEEE d MMMM yyyy 'à' HH:mm", 'fr_FR').format(date)
        : '—';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (teamName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Équipe : $teamName',
                style: const TextStyle(fontSize: 13)),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Lieu : $location',
                style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _badgeRow(List<_Badge> badges) {
    return Row(
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _badgeTile(badges[i])),
        ],
      ],
    );
  }

  Widget _badgeTile(_Badge b) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: b.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: b.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            '${b.count}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: b.color,
            ),
          ),
          Text(
            b.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: b.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerListPre({
    required List<String> teamMembers,
    required Map<String, dynamic> attendance,
    required Map<String, Map<String, dynamic>> userMap,
    required Map<String, Map<String, dynamic>> pendingMap,
  }) {
    final rows = <Widget>[];
    for (final id in teamMembers) {
      final raw = attendance[id];
      final label = raw == 'present'
          ? 'Présent'
          : raw == 'absent'
              ? 'Absent'
              : 'Sans réponse';
      rows.add(
        _readOnlyPlayerRow(
          playerId: id,
          userMap: userMap,
          pendingMap: pendingMap,
          statusLabel: label,
          statusColor: raw == 'present'
              ? ViroColors.primary
              : raw == 'absent'
                  ? Colors.redAccent
                  : Colors.orange,
        ),
      );
    }
    if (rows.isEmpty) {
      return const Text(
        'Aucun joueur convoqué.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      children: List.generate(rows.length * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(height: 8);
        return rows[i ~/ 2];
      }),
    );
  }

  Widget _playerListSession({
    required List<String> teamMembers,
    required Map<String, dynamic> sessionAttendance,
    required Map<String, Map<String, dynamic>> userMap,
    required Map<String, Map<String, dynamic>> pendingMap,
  }) {
    final rows = <Widget>[];
    for (final id in teamMembers) {
      final raw = sessionAttendance[id];
      SessionStatus? st;
      int? lateMin;
      if (raw is Map) {
        st = SessionStatusLabel.fromString(raw['status'] as String?);
        lateMin = raw['lateMinutes'] as int?;
      }
      String label;
      Color color;
      if (st == null) {
        label = 'Non pointé';
        color = Colors.grey;
      } else {
        label = st.label + (st == SessionStatus.late && lateMin != null
            ? ' +${lateMin}min'
            : '');
        color = st == SessionStatus.present
            ? ViroColors.primary
            : st == SessionStatus.late
                ? Colors.orange
                : Colors.redAccent;
      }
      rows.add(
        _readOnlyPlayerRow(
          playerId: id,
          userMap: userMap,
          pendingMap: pendingMap,
          statusLabel: label,
          statusColor: color,
        ),
      );
    }
    if (rows.isEmpty) {
      return const Text(
        'Aucun joueur convoqué.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      children: List.generate(rows.length * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(height: 8);
        return rows[i ~/ 2];
      }),
    );
  }

  Widget _readOnlyPlayerRow({
    required String playerId,
    required Map<String, Map<String, dynamic>> userMap,
    required Map<String, Map<String, dynamic>> pendingMap,
    required String statusLabel,
    required Color statusColor,
  }) {
    final user = userMap[playerId];
    final pending = pendingMap[playerId];
    final hasUser = user != null && user.isNotEmpty;
    final hasPending = pending != null && pending.isNotEmpty;

    String firstName = '';
    String lastName = '';
    String? avatarUrl;

    if (hasUser) {
      firstName = user['firstName'] as String? ?? '';
      lastName = user['lastName'] as String? ?? '';
      avatarUrl = effectiveAvatarUrl(user);
    } else if (hasPending) {
      firstName = pending['firstName'] as String? ?? '';
      lastName = pending['lastName'] as String? ?? '';
    }

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
            child: hasUser
                ? UserDisplayTile(
                    userId: playerId,
                    firstName: firstName,
                    lastName: lastName,
                    avatarUrl: avatarUrl,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    navigateOnTap: false,
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            ViroColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person_outline,
                          color: ViroColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          '$firstName $lastName'.trim().isEmpty
                              ? 'Compte en attente'
                              : '$firstName $lastName'.trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
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
  }
}

class _Badge {
  final String label;
  final int count;
  final Color color;
  _Badge(this.label, this.count, this.color);
}
