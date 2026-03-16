import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/firebase_collections.dart';
import '../../models/training_session_attendance.dart';
import '../../services/event_service.dart';
import '../../services/user_session.dart';
import '../../theme/viro_theme.dart';
import '../../utils/avatar_moderation.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firestore_instance.dart';
import '../../utils/whistle_sound.dart';
import '../../widget/coach_countdown_widget.dart';
import '../../widget/coach_notes_widget.dart';
import '../../widget/coach_zapata_widget.dart';
import '../../widget/sport_score_widget.dart';
import '../../widget/sport_timer_widget.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';

const _defaultOrder = ['timer', 'countdown', 'zapata', 'score', 'notes'];

class AdminTrainingSessionPage extends StatefulWidget {
  final String clubId;
  final String eventId;
  final String teamName;
  final DateTime eventDate;
  final String? sport;

  const AdminTrainingSessionPage({
    super.key,
    required this.clubId,
    required this.eventId,
    required this.teamName,
    required this.eventDate,
    this.sport,
  });

  @override
  State<AdminTrainingSessionPage> createState() =>
      _AdminTrainingSessionPageState();
}

class _AdminTrainingSessionPageState extends State<AdminTrainingSessionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Mode Coach state ---
  final ValueNotifier<int> _resetTrigger = ValueNotifier(0);
  List<String> _orderedIds = List.from(_defaultOrder);
  bool _isCoachModeInitialized = false;

  // --- Présences state ---
  final EventService _eventService = EventService();
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCoachWidgetOrder();
    _ensureSessionStarted();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resetTrigger.dispose();
    super.dispose();
  }

  Future<void> _ensureSessionStarted() async {
    final coachUid = UserSession().currentUser?.uid;
    if (coachUid == null) return;

    // Vérifie si la session est déjà démarrée dans Firestore
    final doc = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events)
        .doc(widget.eventId)
        .get();

    if (doc.exists && doc.data()?['sessionStartedAt'] == null) {
      await _eventService.startTrainingSession(
        widget.clubId,
        widget.eventId,
        coachUid,
      );
    }
    if (mounted) setState(() => _sessionStarted = true);
  }

  // ── Mode Coach : gestion de l'ordre des widgets ──────────────────────────

  Future<void> _loadCoachWidgetOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'coach_widget_order_${widget.clubId}_${widget.sport ?? 'default'}';
    final saved = prefs.getStringList(key);
    if (mounted && saved != null && saved.length == _defaultOrder.length) {
      final valid = saved.every((id) => _defaultOrder.contains(id));
      if (valid) setState(() => _orderedIds = List.from(saved));
    }
    if (mounted) setState(() => _isCoachModeInitialized = true);
  }

  Future<void> _saveCoachWidgetOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'coach_widget_order_${widget.clubId}_${widget.sport ?? 'default'}';
    await prefs.setStringList(key, _orderedIds);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final id = _orderedIds.removeAt(oldIndex);
      _orderedIds.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, id);
    });
    _saveCoachWidgetOrder();
  }

  Widget _buildCoachWidget(String id, {bool includeBottomSpacing = true}) {
    final child = switch (id) {
      'timer' => SportTimerWidget(
        clubId: widget.clubId,
        sport: widget.sport,
        resetTrigger: _resetTrigger,
      ),
      'countdown' => CoachCountdownWidget(
        clubId: widget.clubId,
        sport: widget.sport,
        resetTrigger: _resetTrigger,
      ),
      'zapata' => CoachZapataWidget(
        clubId: widget.clubId,
        sport: widget.sport,
        resetTrigger: _resetTrigger,
      ),
      'score' => SportScoreWidget(
        sport: widget.sport,
        clubId: widget.clubId,
        resetTrigger: _resetTrigger,
      ),
      'notes' => CoachNotesWidget(
        clubId: widget.clubId,
        sport: widget.sport,
        resetTrigger: _resetTrigger,
        eventId: widget.eventId,
      ),
      _ => const SizedBox.shrink(),
    };
    if (!includeBottomSpacing) return child;
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: child);
  }

  // ── Présences : marquage ─────────────────────────────────────────────────

  Future<void> _setAttendance(
    String playerId,
    SessionStatus newStatus,
    Map<String, dynamic> sessionAttendance,
  ) async {
    final coachUid = UserSession().currentUser?.uid;
    if (coachUid == null) return;

    final existingRaw = sessionAttendance[playerId];
    final existing = existingRaw is Map
        ? Map<String, dynamic>.from(existingRaw)
        : null;
    final previousStatus = existing != null
        ? SessionStatusLabel.fromString(existing['status'] as String?)
        : null;

    // Aucun changement : on ignore le tap pour éviter une corruption des stats
    if (previousStatus == newStatus) return;

    if (newStatus == SessionStatus.late) {
      final minutes = await _showLateDialog();
      if (!mounted) return;
      // L'utilisateur a annulé le dialogue : on n'enregistre rien
      if (minutes == null) return;
      await _eventService.setSessionAttendance(
        clubId: widget.clubId,
        eventId: widget.eventId,
        playerId: playerId,
        status: newStatus,
        coachUid: coachUid,
        eventDate: widget.eventDate,
        teamName: widget.teamName,
        lateMinutes: minutes,
        previousStatus: previousStatus,
      );
    } else {
      await _eventService.setSessionAttendance(
        clubId: widget.clubId,
        eventId: widget.eventId,
        playerId: playerId,
        status: newStatus,
        coachUid: coachUid,
        eventDate: widget.eventDate,
        teamName: widget.teamName,
        previousStatus: previousStatus,
      );
    }
  }

  Future<int?> _showLateDialog() async {
    int minutes = 5;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Minutes de retard'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: minutes > 1
                    ? () => setDialogState(() => minutes--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$minutes min',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setDialogState(() => minutes++),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, minutes),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 249, 250),
      appBar: AppBar(
        title: const Text('Entraînement en cours'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ViroColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ViroColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.checklist_rounded), text: 'Présences'),
            Tab(icon: Icon(Icons.sports), text: 'Mode Coach'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset chrono',
            onPressed: () => _resetTrigger.value++,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildCoachModeTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: WhistleSound.play,
        backgroundColor: ViroColors.primary,
        tooltip: 'Sifflet',
        child: Image.asset(
          'assets/icons/icon_sifflet.png',
          width: 28,
          height: 28,
          color: Colors.white,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── Onglet Présences ──────────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    return StreamBuilder<DocumentSnapshot?>(
      stream: _eventService.watchEvent(widget.clubId, widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !_sessionStarted) {
          return const Center(child: ViroLoader(size: 48));
        }

        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return const Center(child: Text('Événement introuvable'));
        }

        final event = doc.data() as Map<String, dynamic>;
        final List<dynamic> teamMemberIds = event['teamMemberIds'] ?? [];
        final Map<String, dynamic> sessionAttendance =
            Map<String, dynamic>.from(event['sessionAttendance'] ?? {});

        if (teamMemberIds.isEmpty) {
          return const Center(
            child: Text(
              'Aucun joueur convoqué pour cet entraînement.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final playerIds = teamMemberIds.map((e) => e.toString()).toList();

        return FutureBuilder<Map<String, dynamic>>(
          future: _loadPlayerData(playerIds),
          builder: (context, dataSnap) {
            if (!dataSnap.hasData) {
              return const Center(child: ViroLoader(size: 48));
            }

            final userMap = dataSnap.data!['userMap']
                as Map<String, Map<String, dynamic>>;
            final pendingMap = dataSnap.data!['pendingMap']
                as Map<String, Map<String, dynamic>>;

            final presentCount = sessionAttendance.values
                .where((v) =>
                    (v as Map<String, dynamic>?)?['status'] == 'present')
                .length;
            final lateCount = sessionAttendance.values
                .where(
                    (v) => (v as Map<String, dynamic>?)?['status'] == 'late')
                .length;
            final absentCount = sessionAttendance.values
                .where(
                    (v) => (v as Map<String, dynamic>?)?['status'] == 'absent')
                .length;

            return Column(
              children: [
                _buildAttendanceSummaryBar(
                  present: presentCount,
                  late: lateCount,
                  absent: absentCount,
                  total: playerIds.length,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: playerIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final id = playerIds[index];
                      final user = userMap[id];
                      final pending = pendingMap[id];
                      final existing =
                          sessionAttendance[id] as Map<String, dynamic>?;
                      final currentStatus = existing != null
                          ? SessionStatusLabel.fromString(
                              existing['status'] as String?)
                          : null;
                      final lateMinutes = existing?['lateMinutes'] as int?;

                      return _buildPlayerAttendanceTile(
                        playerId: id,
                        user: user,
                        pending: pending,
                        currentStatus: currentStatus,
                        lateMinutes: lateMinutes,
                        sessionAttendance: sessionAttendance,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadPlayerData(List<String> playerIds) async {
    final userDocs = await fetchUsersBatch(playerIds);
    final uMap = <String, Map<String, dynamic>>{
      for (final doc in userDocs)
        doc.id: doc.data() as Map<String, dynamic>,
    };

    final pendingIds =
        playerIds.where((id) => (uMap[id] ?? {}).isEmpty).toList();
    final pendingDocs = <String, Map<String, dynamic>>{};
    if (pendingIds.isNotEmpty) {
      final snaps = await Future.wait(
        pendingIds.map(
          (id) => appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(widget.clubId)
              .collection(FirebaseCollections.pendingMembers)
              .doc(id)
              .get(),
        ),
      );
      for (var i = 0; i < pendingIds.length; i++) {
        final data = snaps[i].data();
        if (data != null && data.isNotEmpty) pendingDocs[pendingIds[i]] = data;
      }
    }

    return {'userMap': uMap, 'pendingMap': pendingDocs};
  }

  Widget _buildAttendanceSummaryBar({
    required int present,
    required int late,
    required int absent,
    required int total,
  }) {
    final noMark = total - present - late - absent;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _summaryChip('Présents', present, ViroColors.primary),
          const SizedBox(width: 8),
          _summaryChip('Retards', late, Colors.orange),
          const SizedBox(width: 8),
          _summaryChip('Absents', absent, Colors.redAccent),
          const SizedBox(width: 8),
          _summaryChip('—', noMark, Colors.grey),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
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

  Widget _buildPlayerAttendanceTile({
    required String playerId,
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? pending,
    required SessionStatus? currentStatus,
    required int? lateMinutes,
    required Map<String, dynamic> sessionAttendance,
  }) {
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
        border: Border.all(
          color: currentStatus == null
              ? ViroColors.borderColor
              : _statusColor(currentStatus).withValues(alpha: 0.4),
          width: currentStatus != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (currentStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(currentStatus)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentStatus.label +
                        (currentStatus == SessionStatus.late &&
                                lateMinutes != null
                            ? ' +${lateMinutes}min'
                            : ''),
                    style: TextStyle(
                      color: _statusColor(currentStatus),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _attendanceChip(
                label: 'Présent',
                icon: Icons.check_circle_outline,
                color: ViroColors.primary,
                selected: currentStatus == SessionStatus.present,
                onTap: () => _setAttendance(
                  playerId,
                  SessionStatus.present,
                  sessionAttendance,
                ),
              ),
              const SizedBox(width: 6),
              _attendanceChip(
                label: 'Retard',
                icon: Icons.schedule_outlined,
                color: Colors.orange,
                selected: currentStatus == SessionStatus.late,
                onTap: () => _setAttendance(
                  playerId,
                  SessionStatus.late,
                  sessionAttendance,
                ),
              ),
              const SizedBox(width: 6),
              _attendanceChip(
                label: 'Absent',
                icon: Icons.cancel_outlined,
                color: Colors.redAccent,
                selected: currentStatus == SessionStatus.absent,
                onTap: () => _setAttendance(
                  playerId,
                  SessionStatus.absent,
                  sessionAttendance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendanceChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.present:
        return ViroColors.primary;
      case SessionStatus.late:
        return Colors.orange;
      case SessionStatus.absent:
        return Colors.redAccent;
    }
  }

  // ── Onglet Mode Coach ─────────────────────────────────────────────────────

  Widget _buildCoachModeTab() {
    if (!_isCoachModeInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ReorderableListView(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 88,
      ),
      buildDefaultDragHandles: false,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: _buildCoachWidget(
          _orderedIds[index],
          includeBottomSpacing: false,
        ),
      ),
      children: [
        for (var i = 0; i < _orderedIds.length; i++)
          ReorderableDelayedDragStartListener(
            key: ValueKey(_orderedIds[i]),
            index: i,
            child: _buildCoachWidget(_orderedIds[i]),
          ),
      ],
    );
  }
}
