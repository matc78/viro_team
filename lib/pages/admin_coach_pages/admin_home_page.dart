import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_club_stats_hub_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_event_details_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_loans_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_members_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_teams_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_fee_season_list_page.dart';
import 'package:viro_team/pages/admin_coach_pages/profil_request_page.dart';
import 'admin_profil_page.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
import '../../services/join_request_service.dart';
import '../../services/notification_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
import '../../widget/profile_menu_dropdown.dart';
import '../../widget/slide_to_confirm.dart';
import '../../widget/user_display_tile.dart';

class AdminHomePage extends StatefulWidget {
  /// Ex. ouverture depuis une notif « demande d’adhésion » : défiler vers la section concernée.
  final bool scrollToJoinRequestsOnOpen;

  const AdminHomePage({
    super.key,
    this.scrollToJoinRequestsOnOpen = false,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _notToMissAnchorKey = GlobalKey();
  bool _showAllRequests = false;
  String? _processingRequestId;
  String? _processingLoanRequestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissionIfNeeded(user?.uid);
    });
    if (widget.scrollToJoinRequestsOnOpen) {
      _scrollToJoinRequestsWhenReady();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Attend que la section « À ne pas manquer » soit rendue (streams Firestore).
  Future<void> _scrollToJoinRequestsWhenReady() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final ctx = _notToMissAnchorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.12,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
        if (!context.mounted) return;
        return;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aucune demande à afficher ici pour le moment (déjà traitée ou accès limité).',
        ),
      ),
    );
  }

  /// Rafraîchit le contenu (scroll vers le bas = pull-to-refresh).
  Future<void> _refreshAdminHome() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: user != null
            ? appFirestore
                  .collection(FirebaseCollections.users)
                  .doc(user!.uid)
                  .snapshots()
            : null,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data();
          final activeContext =
              userData?['activeContext'] as Map<String, dynamic>?;
          final clubId =
              activeContext?['clubId'] as String? ??
              userData?['clubId'] as String?;

          if (clubId == null) {
            return const Center(
              child: Text("Aucun club associé à votre compte"),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(clubId)
                .snapshots(),
            builder: (context, clubSnapshot) {
              if (clubSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final clubData = clubSnapshot.data?.data() ?? {};
              final club = {...clubData, 'id': clubId};
              final clubName = club['name'] as String? ?? "Mon Club";
              final viewerRole = _viewerRoleInClub(
                userSnapshot.data?.data() ?? {},
                clubId,
              );
              final canManageEquipmentAndLoans =
                  viewerRole == 'admin' || viewerRole == 'admin_fondateur';

              return SafeArea(
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Opacity(
                          opacity: 0.10,
                          child: Image.asset(
                            'assets/logo/logo_seul.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _refreshAdminHome,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAdminHeader(
                                userData,
                                clubData,
                                clubId,
                                viewerRole,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTodaySection(clubId),
                                    const SizedBox(height: 28),
                                    _buildQuickAccessRow(
                                      clubId,
                                      clubName,
                                      clubData,
                                      viewerRole,
                                      canManageEquipmentAndLoans,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildClubStatsHubEntry(context, clubId),
                                    const SizedBox(height: 28),
                                    _buildNotToMissSection(
                                      clubId,
                                      clubName,
                                      userSnapshot.data?.data() ?? {},
                                      canManageEquipmentAndLoans,
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminHeader(
    Map<String, dynamic>? userData,
    Map<String, dynamic> clubData,
    String clubId,
    String? viewerRole,
  ) {
    final avatarUrl = effectiveAvatarUrl(userData);
    final firstName = (userData?['firstName'] as String? ?? '').trim();
    final name = firstName.isNotEmpty ? firstName : 'Admin';
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Bonjour'
        : (hour < 18 ? 'Bon après-midi' : 'Bonsoir');
    const clubColor = ViroColors.primary;

    final clubName = clubData['name'] as String? ?? 'Mon Club';
    final sport = clubData['sport'] as String?;
    final logoUrl = clubData['logoUrl'] as String?;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      greeting,
                      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: ViroColors.primary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => showProfileDropdown(
                    ctx,
                    settingsPage: const AdminProfilPage(),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: clubColor.withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                    ),
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            imageBuilder: (_, imageProvider) => CircleAvatar(
                              radius: 22,
                              backgroundImage: imageProvider,
                            ),
                            placeholder: (_, __) => CircleAvatar(
                              radius: 22,
                              backgroundColor: clubColor.withValues(alpha: 0.1),
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => CircleAvatar(
                              radius: 22,
                              backgroundColor: clubColor.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.person,
                                color: ViroColors.primary,
                              ),
                            ),
                            memCacheWidth: 88,
                            memCacheHeight: 88,
                          )
                        : CircleAvatar(
                            radius: 22,
                            backgroundColor: clubColor.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.person,
                              color: ViroColors.primary,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Club + rôle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ViroColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ViroColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: hasLogo
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.groups_rounded,
                                  color: ViroColors.primary,
                                  size: 16,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.groups_rounded,
                              color: ViroColors.primary,
                              size: 16,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatClubNameWithEmoji(clubName, sport),
                      style: const TextStyle(
                        color: ViroColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AnimatedRoleBadge(role: viewerRole),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Rôle effectif du viewer dans le club (admin_fondateur > admin > coach).
  String? _viewerRoleInClub(Map<String, dynamic> userData, String clubId) {
    final rolesInClub = getAllUserRolesInClub(userData, clubId);
    if (rolesInClub.contains('admin_fondateur')) return 'admin_fondateur';
    if (rolesInClub.contains('admin')) return 'admin';
    if (rolesInClub.contains('coach')) return 'coach';
    return null;
  }

  /// True si le viewer peut accepter/refuser cette demande (admin fondateur: tout; admin: joueur uniquement; coach: jamais).
  bool _canRespondToJoinRequest(String? viewerRole, String? roleRequested) {
    if (viewerRole == null) return false;
    if (viewerRole == 'coach') return false;
    if (viewerRole == 'admin_fondateur') return true;
    if (viewerRole == 'admin') {
      final r = roleRequested ?? 'player';
      return r == 'player';
    }
    return false;
  }

  Widget _buildTodaySection(String clubId) {
    final todayId = DateFormat('yyyyMMdd').format(DateTime.now());
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .where('dateId', isEqualTo: todayId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snap.data?.docs ?? [];
        final events = docs.where((d) => d.data()['canceled'] != true).toList();
        // Tri par heure de début
        events.sort((a, b) {
          final ta = a.data()['startTime']?.toString() ?? '';
          final tb = b.data()['startTime']?.toString() ?? '';
          return ta.compareTo(tb);
        });
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aujourd'hui",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ViroColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...events.map(
              (doc) => _buildTodayEventCard(clubId, doc.id, doc.data()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTodayEventCard(
    String clubId,
    String eventId,
    Map<String, dynamic> data,
  ) {
    final bool isMatch = data['type'] == 'Match';
    final bool isAllDay = data['startTime'] == null && data['endTime'] == null;
    final String title = (data['title'] ?? data['type'] ?? 'Événement')
        .toString();
    final String time = isAllDay
        ? 'Toute la journée'
        : (isMatch
              ? (data['meetingTime']?.toString() ??
                    data['startTime']?.toString() ??
                    '--:--')
              : (data['startTime']?.toString() ?? '--:--'));
    final String? endTime = data['endTime']?.toString();
    final String location = isMatch
        ? (data['meetingLocation']?.toString().trim().isNotEmpty == true
              ? data['meetingLocation'].toString().trim()
              : (data['location']?.toString() ?? ''))
        : (data['location']?.toString() ?? '');
    final teamNames =
        (data['teamNames'] as List?)?.whereType<String>().toList() ??
        (data['teamName'] != null ? [data['teamName'].toString()] : <String>[]);
    final String teamLabel = teamNames.isEmpty ? '' : teamNames.join(', ');

    final String category = (data['category'] as String?)?.trim() ?? '';
    final Color color = category.isNotEmpty
        ? ViroColors.getCategoryColor(category)
        : (isMatch ? Colors.orange.shade700 : ViroColors.primary);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AdminEventDetailsPage(clubId: clubId, eventId: eventId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Barre colorée à gauche
            Container(
              width: 5,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Icône
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(
                isMatch ? Icons.sports_soccer : Icons.fitness_center,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Titre + équipe + lieu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (teamLabel.isNotEmpty)
                    Text(
                      teamLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Heure
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  if (endTime != null && endTime.isNotEmpty)
                    Text(
                      endTime,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessRow(
    String clubId,
    String clubName,
    Map<String, dynamic> clubData,
    String? viewerRole,
    bool canManageEquipmentAndLoans,
  ) {
    final clubSport = clubData['sport'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            "Gérer",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ViroColors.primary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.group_outlined,
                label: "Membres",
                color: ViroColors.accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminMembersPage(
                      clubId: clubId,
                      clubName: clubName,
                      clubSport: clubSport,
                      currentViewerRole: viewerRole,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.groups_rounded,
                label: "Équipes",
                color: ViroColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminTeamsPage(clubId: clubId),
                  ),
                ),
              ),
            ),
            if (canManageEquipmentAndLoans) ...[
              const SizedBox(width: 14),
              Expanded(
                child: _QuickAccessButton(
                  icon: Icons.handshake_outlined,
                  label: "Prêts",
                  color: ViroColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminLoansPage(clubId: clubId),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.payments_outlined,
                label: "Cotisations",
                color: ViroColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminFeeSeasonListPage(clubId: clubId),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClubStatsHubEntry(BuildContext context, String clubId) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminClubStatsHubPage(clubId: clubId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: ViroColors.primary, size: 26),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiques du club',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Effectif, événements, moyennes et classements',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotToMissSection(
    String clubId,
    String clubName,
    Map<String, dynamic> userData,
    bool canManageEquipmentAndLoans,
  ) {
    final cutoff24h = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: appFirestore
          .collection(FirebaseCollections.joinRequests)
          .where('clubId', isEqualTo: clubId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, joinSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .collection(FirebaseCollections.memberLeaves)
              .where('leftAt', isGreaterThanOrEqualTo: cutoff24h)
              .snapshots(),
          builder: (context, leavesSnap) {
            final hasJoin = (joinSnap.data?.docs ?? []).isNotEmpty;
            final hasLeaves = (leavesSnap.data?.docs ?? []).isNotEmpty;

            if (!canManageEquipmentAndLoans) {
              final hasContent = hasJoin || hasLeaves;
              return _buildNotToMissContent(
                clubId,
                clubName,
                userData,
                canManageEquipmentAndLoans,
                hasContent,
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: appFirestore
                  .collection(FirebaseCollections.clubs)
                  .doc(clubId)
                  .collection(FirebaseCollections.equipmentLoanRequests)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, loanReqSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: appFirestore
                      .collection(FirebaseCollections.clubs)
                      .doc(clubId)
                      .collection(FirebaseCollections.equipmentLoans)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, loansSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: appFirestore
                          .collection(FirebaseCollections.clubs)
                          .doc(clubId)
                          .collection(FirebaseCollections.equipmentLoanRequests)
                          .where('status', isEqualTo: 'accepted')
                          .snapshots(),
                      builder: (context, acceptedSnap) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final tomorrow = today.add(const Duration(days: 1));
                        final hasLoanReqs =
                            (loanReqSnap.data?.docs ?? []).isNotEmpty;
                        final hasLoans =
                            (loansSnap.data?.docs ?? []).isNotEmpty;
                        final hasUpcomingLoans = (acceptedSnap.data?.docs ?? [])
                            .any((doc) {
                              final ts =
                                  doc.data()['requestedPickupDate']
                                      as Timestamp?;
                              if (ts == null) return false;
                              final d = ts.toDate();
                              final day = DateTime(d.year, d.month, d.day);
                              return !day.isBefore(today) &&
                                  !day.isAfter(tomorrow);
                            });
                        final hasContent =
                            hasJoin ||
                            hasLeaves ||
                            hasLoanReqs ||
                            hasLoans ||
                            hasUpcomingLoans;
                        return _buildNotToMissContent(
                          clubId,
                          clubName,
                          userData,
                          canManageEquipmentAndLoans,
                          hasContent,
                        );
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

  Widget _buildNotToMissContent(
    String clubId,
    String clubName,
    Map<String, dynamic> userData,
    bool canManageEquipmentAndLoans,
    bool hasContent,
  ) {
    if (!hasContent) return const SizedBox.shrink();

    return Column(
      key: _notToMissAnchorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "À ne pas manquer",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _buildJoinRequestsSection(clubId, clubName, userData),
        const SizedBox(height: 12),
        _buildMemberLeavesSection(clubId),
        const SizedBox(height: 12),
        if (canManageEquipmentAndLoans) ...[
          _buildLoanRequestsSection(clubId),
          _buildLoanChangeRequestsSection(clubId),
          _buildActiveLoans(clubId),
          _buildPickupToConfirmSection(clubId),
          _buildUpcomingLoans(clubId),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildJoinRequestsSection(
    String clubId,
    String clubName,
    Map<String, dynamic> userData,
  ) {
    final viewerRole = _viewerRoleInClub(userData, clubId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.joinRequests)
          .where('clubId', isEqualTo: clubId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InfoCard(
            child: const Text(
              "Erreur de chargement des demandes.",
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InfoCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        // tri côté client pour éviter d'imposer un index Firestore
        docs.sort((a, b) {
          final ta = a.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          final tb = b.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          return tb.compareTo(ta); // plus récent en premier
        });

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final toShow = _showAllRequests ? docs : docs.take(2).toList();
        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...toShow.map((doc) {
                final data = doc.data();
                final role = data['roleRequested'] ?? "player";
                final message = data['message'] ?? "";
                final createdAt = data['createdAt'] as Timestamp?;
                final dateText = createdAt != null
                    ? "${createdAt.toDate().day}/${createdAt.toDate().month}"
                    : "";
                final canRespond = _canRespondToJoinRequest(
                  viewerRole,
                  data['roleRequested'],
                );
                final roleLabel = role == 'coach'
                    ? "Entraîneur"
                    : (role == 'admin' || role == 'admin_fondateur'
                          ? "Administrateur"
                          : "Membre");
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfilRequestPage(
                          requestId: doc.id,
                          userId: data['userId'],
                          clubId: clubId,
                          clubName: clubName,
                          roleRequested: data['roleRequested'],
                          message: message,
                          firstName: data['firstName'],
                          lastName: data['lastName'],
                          canRespond: canRespond,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ViroColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: UserDisplayTile(
                                userId: data['userId'] as String?,
                                firstName: data['firstName'] as String?,
                                lastName: data['lastName'] as String?,
                                fallback: data['userId'] ?? "Membre",
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              roleLabel,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                        if (dateText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Reçue le $dateText",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (canRespond)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _processingRequestId == doc.id
                                      ? null
                                      : () => _handleRequest(
                                          doc.id,
                                          data['userId'],
                                          accept: false,
                                        ),
                                  child: const Text("Refuser"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _processingRequestId == doc.id
                                      ? null
                                      : () => _handleRequest(
                                          doc.id,
                                          data['userId'],
                                          accept: true,
                                          clubId: clubId,
                                          clubName: clubName,
                                          role: data['roleRequested'],
                                        ),
                                  child: _processingRequestId == doc.id
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text("Accepter"),
                                ),
                              ),
                            ],
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              viewerRole == 'coach'
                                  ? "Seul un administrateur peut accepter ou refuser."
                                  : "Réservé à l'administrateur fondateur.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              if (docs.length > 2)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _showAllRequests = !_showAllRequests;
                    }),
                    icon: Icon(
                      _showAllRequests
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    label: Text(
                      _showAllRequests
                          ? "Voir moins"
                          : "Voir toutes les demandes (${docs.length})",
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberLeavesSection(String clubId) {
    final cutoff24h = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.memberLeaves)
          .where('leftAt', isGreaterThanOrEqualTo: cutoff24h)
          .orderBy('leftAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final roleLabels = <String, String>{
          'player': 'Membre',
          'coach': 'Coach',
          'admin': 'Admin',
        };
        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_off_rounded, color: ViroColors.error),
                  const SizedBox(width: 8),
                  const Text(
                    "Départs du club",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${docs.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data();
                final firstName = (data['firstName'] as String?)?.trim() ?? '';
                final lastName = (data['lastName'] as String?)?.trim() ?? '';
                final role = data['role'] as String? ?? 'player';
                final leftAt = data['leftAt'] as Timestamp?;
                final roleLabel = roleLabels[role] ?? role;
                final displayName = firstName.isNotEmpty || lastName.isNotEmpty
                    ? '$firstName $lastName'.trim()
                    : 'Un utilisateur';
                String timeAgo = '';
                if (leftAt != null) {
                  final diff = DateTime.now().difference(leftAt.toDate());
                  if (diff.inMinutes < 60) {
                    timeAgo = 'Il y a ${diff.inMinutes} min';
                  } else if (diff.inHours < 24) {
                    timeAgo = 'Il y a ${diff.inHours} h';
                  } else {
                    timeAgo = DateFormat(
                      'dd/MM HH:mm',
                      'fr_FR',
                    ).format(leftAt.toDate());
                  }
                }
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ViroColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ViroColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$displayName ($roleLabel) a quitté le club.",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (timeAgo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  Future<void> _handleRequest(
    String requestId,
    String? userId, {
    required bool accept,
    String? clubId,
    String? clubName,
    String? role,
  }) async {
    if (userId == null) return;
    setState(() => _processingRequestId = requestId);
    try {
      if (accept) {
        await JoinRequestService.instance.acceptRequest(
          requestId: requestId,
          userId: userId,
          clubId: clubId ?? '',
          role: role ?? 'player',
        );
      } else {
        await JoinRequestService.instance.refuseRequest(
          requestId: requestId,
          userId: userId,
          clubId: clubId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _processingRequestId = null);
    }
  }

  Widget _buildLoanRequestsSection(String clubId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final errorStr = error.toString();
          // Vérifier si c'est une erreur d'index manquant
          if (errorStr.contains('index') ||
              errorStr.contains('requires an index')) {
            return _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Données temporairement indisponibles",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Un réglage technique est en cours. Réessayez plus tard ou contactez l'administrateur du club.",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            );
          }
          return _InfoCard(
            child: Text(
              FirebaseErrorHandler.getErrorMessage(error),
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InfoCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trier côté client par createdAt (descendant)
        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descendant
          });

        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.request_quote, color: ViroColors.warning),
                  const SizedBox(width: 8),
                  const Text(
                    "Demandes de prêt",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${docs.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sortedDocs.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final playerName = data['playerName'] as String? ?? 'Joueur';
                final playerId = data['playerId'] as String?;
                final quantity = data['quantity'] as int? ?? 1;
                final duration = data['duration'] as int? ?? 0;
                final durationUnit = data['durationUnit'] as String? ?? 'jour';
                final reason = data['reason'] as String? ?? '';
                final requestedPickupDate =
                    data['requestedPickupDate'] as Timestamp?;
                final createdAt = data['createdAt'] as Timestamp?;

                String durationUnitLabel(String unit) {
                  switch (unit) {
                    case 'jour':
                      return 'jour(s)';
                    case 'semaine':
                      return 'semaine(s)';
                    case 'mois':
                      return 'mois';
                    default:
                      return unit;
                  }
                }

                final dateText = createdAt != null
                    ? "${createdAt.toDate().day}/${createdAt.toDate().month}"
                    : "";

                return InkWell(
                  onTap: () {
                    // Optionnel : navigation vers une page de détail
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ViroColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                equipmentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Chip(
                              label: const Text(
                                "En attente",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: ViroColors.warning,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "Demandé par ",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            UserDisplayTile(
                              userId: playerId,
                              fallback: playerName,
                              compact: true,
                              textStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Quantité: $quantity • Durée: $duration ${durationUnitLabel(durationUnit)}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (requestedPickupDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Récupération: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(requestedPickupDate.toDate())}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Raison:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (dateText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Reçue le $dateText",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _processingLoanRequestId == doc.id
                                    ? null
                                    : () => _handleLoanRequest(
                                        doc.id,
                                        clubId,
                                        data,
                                        accept: false,
                                      ),
                                child: const Text("Refuser"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _processingLoanRequestId == doc.id
                                    ? null
                                    : () => _handleLoanRequest(
                                        doc.id,
                                        clubId,
                                        data,
                                        accept: true,
                                      ),
                                child: _processingLoanRequestId == doc.id
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text("Accepter"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanChangeRequestsSection(String clubId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanChangeRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InfoCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return aCreated.compareTo(bCreated);
          });
        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_calendar, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Demandes de modification / annulation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      "${docs.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.orange.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sortedDocs.map((doc) {
                final data = doc.data();
                final type = data['type'] as String? ?? '';
                final reason = data['reason'] as String? ?? '';
                final playerName = data['playerName'] as String? ?? 'Joueur';
                final playerId = data['requestedBy'] as String?;
                final typeLabel = type == 'cancellation'
                    ? 'Annulation'
                    : 'Modification';
                final reasonPreview = reason.length > 60
                    ? '${reason.substring(0, 60)}...'
                    : reason;
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminLoansPage(clubId: clubId, initialTabIndex: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(
                                typeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: type == 'cancellation'
                                  ? ViroColors.error
                                  : ViroColors.primary,
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        UserDisplayTile(
                          userId: playerId,
                          fallback: playerName,
                          compact: true,
                          textStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (reasonPreview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            reasonPreview,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminLoansPage(clubId: clubId, initialTabIndex: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text("Voir toutes les demandes (Prêts)"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLoanRequest(
    String requestId,
    String clubId,
    Map<String, dynamic> requestData, {
    required bool accept,
  }) async {
    setState(() => _processingLoanRequestId = requestId);
    try {
      if (accept) {
        await _acceptLoanRequest(requestId, clubId, requestData);
      } else {
        await _refuseLoanRequest(requestId, clubId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _processingLoanRequestId = null);
    }
  }

  Future<void> _acceptLoanRequest(
    String requestId,
    String clubId,
    Map<String, dynamic> requestData,
  ) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Accepter la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous accepter cette demande de prêt ?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Message (optionnel)",
                hintText: "Message pour le joueur",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Accepter"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _processingLoanRequestId = null);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final requestedPickupDate =
          requestData['requestedPickupDate'] as Timestamp?;
      final duration = requestData['duration'] as int? ?? 0;
      final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
      final equipmentId = requestData['equipmentId'] as String? ?? '';
      final equipmentName =
          requestData['equipmentName'] as String? ?? 'Équipement';
      final quantity = requestData['quantity'] as int? ?? 1;
      final playerId = requestData['playerId'] as String? ?? '';
      final playerName = requestData['playerName'] as String? ?? 'Joueur';

      if (requestedPickupDate == null) {
        throw Exception("Date de récupération manquante");
      }

      // Calculer la date de retour
      final pickupDate = requestedPickupDate.toDate();
      int durationDays = duration;
      if (durationUnit == 'semaine') {
        durationDays = duration * 7;
      } else if (durationUnit == 'mois') {
        durationDays = duration * 30;
      }
      final returnDate = pickupDate.add(Duration(days: durationDays));
      final totalPrice = requestData['totalPrice'] as num?;
      final caution = requestData['caution'] as num?;

      // Créer le prêt actif (remise non encore confirmée)
      final loanRef = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .add({
            'equipmentId': equipmentId,
            'equipmentName': equipmentName,
            'quantity': quantity,
            'borrowerId': playerId,
            'borrowerName': playerName,
            'lentAt': requestedPickupDate,
            'dueAt': Timestamp.fromDate(returnDate),
            'status': 'active',
            'pickupConfirmed': false,
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
            if (totalPrice != null) 'totalPrice': totalPrice,
            if (caution != null) 'caution': caution,
          });

      // Mettre à jour la demande (avec loanId pour annulation des prêts à venir)
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'accepted',
            'loanId': loanRef.id,
            'adminResponse': responseController.text.trim().isNotEmpty
                ? responseController.text.trim()
                : null,
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande acceptée et prêt créé avec succès !"),
            backgroundColor: ViroColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _refuseLoanRequest(String requestId, String clubId) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Refuser la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous refuser cette demande de prêt ?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Raison du refus *",
                hintText: "Expliquez pourquoi la demande est refusée",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: responseController.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ViroColors.error),
            child: const Text("Refuser"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _processingLoanRequestId = null);
      return;
    }

    if (responseController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez indiquer une raison de refus."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      setState(() => _processingLoanRequestId = null);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'refused',
            'adminResponse': responseController.text.trim(),
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande refusée."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _markLoanReturned(String clubId, String loanId) async {
    try {
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .doc(loanId)
          .update({
            'status': 'returned',
            'returnedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Prêt marqué comme retourné."),
            backgroundColor: ViroColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }

  Widget _buildActiveLoans(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        final allLoans = docs
            .map((d) => {'id': d.id, ...d.data()})
            .cast<Map<String, dynamic>>()
            .toList();
        final activeLoans = allLoans.where((loan) {
          if (loan['pickupConfirmed'] == false) return false;
          final lentAt = loan['lentAt'] as Timestamp?;
          final dueAt = loan['dueAt'] as Timestamp?;
          if (lentAt == null || dueAt == null) return false;
          final lentDate = lentAt.toDate();
          final lentDay = DateTime(lentDate.year, lentDate.month, lentDate.day);
          return !lentDay.isAfter(today);
        }).toList();
        if (activeLoans.isEmpty) {
          return const SizedBox.shrink();
        }
        activeLoans.sort((a, b) {
          final aDue = a['dueAt'] as Timestamp?;
          final bDue = b['dueAt'] as Timestamp?;
          if (aDue == null && bDue == null) return 0;
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: ViroColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    "Prêts en cours",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${activeLoans.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...activeLoans.map((loan) {
                final equipmentName =
                    loan['equipmentName'] as String? ?? 'Équipement';
                final quantity = loan['quantity'] as int? ?? 1;
                final borrowerName =
                    loan['borrowerName'] as String? ?? 'Joueur';
                final borrowerId = loan['borrowerId'] as String?;
                final dueAt = loan['dueAt'] as Timestamp?;
                final dueDate = dueAt?.toDate();
                final dueDay = dueDate != null
                    ? DateTime(dueDate.year, dueDate.month, dueDate.day)
                    : null;
                final isOverdue = dueDay != null && dueDay.isBefore(today);
                final isDueToday = dueDay != null && dueDay == today;
                final statusColor = isOverdue
                    ? ViroColors.error
                    : isDueToday
                    ? ViroColors.primary
                    : ViroColors.success;
                final statusIcon = isOverdue
                    ? Icons.error_outline
                    : isDueToday
                    ? Icons.schedule
                    : Icons.check_circle_outline;
                final cardColor = statusColor.withValues(alpha: 0.08);
                final borderColor = statusColor.withValues(alpha: 0.35);
                return Padding(
                  key: ValueKey(loan['id']),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminLoansPage(
                            clubId: clubId,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$equipmentName (x$quantity)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          UserDisplayTile(
                            userId: borrowerId,
                            fallback: borrowerName,
                            compact: true,
                            textStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (dueDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Retour le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SlideToConfirm(
                            label: "Confirmer retour",
                            color: statusColor,
                            icon: statusIcon,
                            onConfirmed: () =>
                                _markLoanReturned(clubId, loan['id'] as String),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickupToConfirmSection(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        final allLoans = docs
            .map((d) => {'id': d.id, ...d.data()})
            .cast<Map<String, dynamic>>()
            .toList();
        final toConfirm = allLoans.where((loan) {
          if (loan['pickupConfirmed'] != false) return false;
          final lentAt = loan['lentAt'] as Timestamp?;
          final dueAt = loan['dueAt'] as Timestamp?;
          if (lentAt == null || dueAt == null) return false;
          final lentDay = DateTime(
            lentAt.toDate().year,
            lentAt.toDate().month,
            lentAt.toDate().day,
          );
          final dueDay = DateTime(
            dueAt.toDate().year,
            dueAt.toDate().month,
            dueAt.toDate().day,
          );
          return !lentDay.isAfter(today) && !dueDay.isBefore(today);
        }).toList();
        if (toConfirm.isEmpty) {
          return const SizedBox.shrink();
        }
        toConfirm.sort((a, b) {
          final aDue = (a['dueAt'] as Timestamp?)?.toDate();
          final bDue = (b['dueAt'] as Timestamp?)?.toDate();
          if (aDue == null && bDue == null) return 0;
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
        final displayList = toConfirm.take(5).toList();
        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.handshake_outlined, color: ViroColors.warning),
                  const SizedBox(width: 8),
                  const Text(
                    "À confirmer remise",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${toConfirm.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...displayList.map((loan) {
                final equipmentName =
                    loan['equipmentName'] as String? ?? 'Équipement';
                final quantity = loan['quantity'] as int? ?? 1;
                final borrowerName =
                    loan['borrowerName'] as String? ?? 'Joueur';
                final borrowerId = loan['borrowerId'] as String?;
                final dueAt = loan['dueAt'] as Timestamp?;
                final dueDate = dueAt?.toDate();
                final loanId = loan['id'] as String;
                return Padding(
                  key: ValueKey(loanId),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ViroColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: ViroColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$equipmentName (x$quantity)",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        UserDisplayTile(
                          userId: borrowerId,
                          fallback: borrowerName,
                          compact: true,
                          textStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (dueDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Retour le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SlideToConfirm(
                          label: "Confirmer remise",
                          color: ViroColors.warning,
                          icon: Icons.handshake_outlined,
                          onConfirmed: () async {
                            try {
                              await appFirestore
                                  .collection(FirebaseCollections.clubs)
                                  .doc(clubId)
                                  .collection(
                                    FirebaseCollections.equipmentLoans,
                                  )
                                  .doc(loanId)
                                  .update({'pickupConfirmed': true});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Remise confirmée."),
                                    backgroundColor: ViroColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      FirebaseErrorHandler.getErrorMessage(e),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (toConfirm.length > 5) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminLoansPage(
                            clubId: clubId,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text("Voir les prêts"),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingLoans(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;

        // Afficher à partir de J-1 : pickupDay >= aujourd'hui - 1 jour
        final yesterday = today.subtract(const Duration(days: 1));
        final upcomingLoans = requests.where((doc) {
          final data = doc.data();
          final requestedPickupDate = data['requestedPickupDate'] as Timestamp?;
          if (requestedPickupDate == null) return false;
          final pickupDate = requestedPickupDate.toDate();
          final pickupDay = DateTime(
            pickupDate.year,
            pickupDate.month,
            pickupDate.day,
          );
          return !pickupDay.isBefore(yesterday);
        }).toList();

        if (upcomingLoans.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trier par date de récupération (ascendant)
        upcomingLoans.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = (aData['requestedPickupDate'] as Timestamp?)?.toDate();
          final bDate = (bData['requestedPickupDate'] as Timestamp?)?.toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

        return _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: ViroColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    "Prochains prêts",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...upcomingLoans.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final quantity = data['quantity'] as int? ?? 1;
                final borrowerName = data['playerName'] as String? ?? 'Joueur';
                final playerId = data['playerId'] as String?;
                final requestedPickupDate =
                    data['requestedPickupDate'] as Timestamp?;
                final duration = data['duration'] as int? ?? 0;
                final durationUnit = data['durationUnit'] as String? ?? 'jour';

                String durationUnitLabel(String unit) {
                  switch (unit) {
                    case 'jour':
                      return 'jour(s)';
                    case 'semaine':
                      return 'semaine(s)';
                    case 'mois':
                      return 'mois';
                    default:
                      return unit;
                  }
                }

                final pickupDate = requestedPickupDate?.toDate();
                final daysUntilPickup = pickupDate?.difference(today).inDays;

                return Padding(
                  key: ValueKey(doc.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminLoansPage(
                            clubId: clubId,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ViroColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: ViroColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$equipmentName (x$quantity)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          UserDisplayTile(
                            userId: playerId,
                            fallback: borrowerName,
                            compact: true,
                            textStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (pickupDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Récupération: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(pickupDate)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (daysUntilPickup != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              daysUntilPickup == 1
                                  ? "Dans 1 jour"
                                  : "Dans $daysUntilPickup jours",
                              style: TextStyle(
                                fontSize: 12,
                                color: ViroColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            "Durée: $duration ${durationUnitLabel(durationUnit)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: child,
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge de rôle animé (shimmer métallique)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedRoleBadge extends StatefulWidget {
  final String? role;
  const _AnimatedRoleBadge({required this.role});

  @override
  State<_AnimatedRoleBadge> createState() => _AnimatedRoleBadgeState();
}

class _AnimatedRoleBadgeState extends State<_AnimatedRoleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(
      begin: -0.8,
      end: 0.8,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, base, shine, textColor) = switch (widget.role) {
      'admin_fondateur' => (
        'Fondateur',
        const Color(0xFFB8860B),
        const Color(0xFFFFF0A0),
        Colors.white,
      ),
      'admin' => (
        'Administrateur',
        const Color(0xFF7A7A7A),
        const Color(0xFFE8E8E8),
        Colors.white,
      ),
      'coach' => (
        'Entraîneur',
        const Color(0xFF7B4F2E),
        const Color(0xFFE8B27A),
        Colors.white,
      ),
      _ => (
        'Membre',
        const Color(0xFF9E9E9E),
        const Color(0xFFE0E0E0),
        Colors.white,
      ),
    };

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final pos = _shimmer.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(pos - 1.5, -0.5),
              end: Alignment(pos + 1.5, 0.5),
              colors: [base, base, shine, base, base],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
