import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';

class PlayerInfosPage extends StatefulWidget {
  final String clubId;

  const PlayerInfosPage({super.key, required this.clubId});

  @override
  State<PlayerInfosPage> createState() => _PlayerInfosPageState();
}

class _PlayerInfosPageState extends State<PlayerInfosPage>
    with SingleTickerProviderStateMixin {
  String? _selectedClubId;
  bool _initialized = false;
  Map<String, String> _clubNamesCache = {};
  Map<String, String> _clubSportsCache = {};
  late final TabController _tabController;
  String _tabLabel = "Mon Club";

  Future<void> _loadClubNames(List<String> clubIds) async {
    if (clubIds.isEmpty) return;
    final Map<String, String> names = {};
    final Map<String, String> sports = {};
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.sublist(i, math.min(i + 10, clubIds.length));
      try {
        final snapshot = await appFirestore
            .collection(FirebaseCollections.clubs)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          names[doc.id] = data['name'] as String? ?? doc.id;
          final sport = data['sport'] as String?;
          if (sport != null && sport.isNotEmpty) sports[doc.id] = sport;
        }
      } catch (e) {
        AppLogger.instance.error('loadClubNames batch failed',
            error: e, context: {'batchSize': batch.length});
        for (var id in batch) {
          names[id] = id;
        }
      }
    }
    if (mounted) {
      setState(() {
        _clubNamesCache = names;
        _clubSportsCache = sports;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _ensureInitialized(List<String> allClubIds) {
    if (_initialized || allClubIds.isEmpty) return;
    _initialized = true;
    final sel = allClubIds.contains(widget.clubId)
        ? widget.clubId
        : allClubIds.first;
    setState(() {
      _selectedClubId = sel;
      _tabLabel = allClubIds.length > 1 ? "Mes Clubs" : "Mon Club";
    });
    _loadClubNames(allClubIds);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Infos & Actualités"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: "Actualités"),
            Tab(text: _tabLabel),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appFirestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader());
          }

          final userData = userSnapshot.data?.data();
          if (userData == null) {
            return const Center(child: Text("Erreur de chargement"));
          }

          final Set<String> clubIdsSet = {};
          final activeContext =
              userData['activeContext'] as Map<String, dynamic>?;
          final activeClubId = activeContext?['clubId'] as String?;
          if (activeClubId != null && activeClubId.isNotEmpty) {
            clubIdsSet.add(activeClubId);
          }
          final summaries =
              (userData['profileSummaries'] as List?)
                  ?.whereType<Map>()
                  .toList() ??
              [];
          for (final e in summaries) {
            final cid = e['clubId'] as String?;
            if (cid != null && cid.isNotEmpty) clubIdsSet.add(cid);
          }
          final legacyClubId = userData['clubId'] as String?;
          if (legacyClubId != null) clubIdsSet.add(legacyClubId);
          clubIdsSet.add(widget.clubId);

          final allClubIds = clubIdsSet.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          if (allClubIds.isEmpty) {
            return const Center(child: Text("Aucun club trouvé"));
          }

          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensureInitialized(allClubIds);
            });
          }

          final selectedClubId = _selectedClubId ?? allClubIds.first;

          return TabBarView(
            controller: _tabController,
            children: [
              _ClubAnnouncementsList(
                clubIds: allClubIds,
                userId: userId,
                hasMultipleClubs: allClubIds.length > 1,
                clubNames: _clubNamesCache,
                clubSports: _clubSportsCache,
              ),
              _ClubInfoTab(
                allClubIds: allClubIds,
                selectedClubId: selectedClubId,
                onClubChanged: (id) => setState(() => _selectedClubId = id),
                clubNamesCache: _clubNamesCache,
                clubSportsCache: _clubSportsCache,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Couleur déterministe par club (cohérente avec les annonces et la home page).
Color _clubColor(String clubId) {
  final index = clubId.hashCode.abs() % ViroColors.clubPalette.length;
  return ViroColors.clubPalette[index];
}

// --- ONGLET 2 : INFOS DU CLUB SÉLECTIONNÉ ---
class _ClubInfoTab extends StatelessWidget {
  final List<String> allClubIds;
  final String selectedClubId;
  final ValueChanged<String> onClubChanged;
  final Map<String, String> clubNamesCache;
  final Map<String, String> clubSportsCache;

  const _ClubInfoTab({
    required this.allClubIds,
    required this.selectedClubId,
    required this.onClubChanged,
    required this.clubNamesCache,
    required this.clubSportsCache,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ClubChipsBar(
          allClubIds: allClubIds,
          selectedClubId: selectedClubId,
          onClubChanged: onClubChanged,
          clubNamesCache: clubNamesCache,
          clubSportsCache: clubSportsCache,
        ),
        Expanded(
          child: _ClubInfoContent(
            selectedClubId: selectedClubId,
          ),
        ),
      ],
    );
  }
}

class _ClubChipsBar extends StatefulWidget {
  final List<String> allClubIds;
  final String selectedClubId;
  final ValueChanged<String> onClubChanged;
  final Map<String, String> clubNamesCache;
  final Map<String, String> clubSportsCache;

  const _ClubChipsBar({
    required this.allClubIds,
    required this.selectedClubId,
    required this.onClubChanged,
    required this.clubNamesCache,
    required this.clubSportsCache,
  });

  @override
  State<_ClubChipsBar> createState() => _ClubChipsBarState();
}

class _ClubChipsBarState extends State<_ClubChipsBar> {
  final ScrollController _chipScrollController = ScrollController();
  final Map<String, GlobalKey> _chipKeys = {};
  final GlobalKey _chipsViewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToChip(widget.selectedClubId);
    });
  }

  @override
  void didUpdateWidget(covariant _ClubChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clubsChanged =
        oldWidget.allClubIds.length != widget.allClubIds.length ||
            oldWidget.allClubIds
                .any((id) => !widget.allClubIds.contains(id));
    if (oldWidget.selectedClubId != widget.selectedClubId || clubsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToChip(widget.selectedClubId);
      });
    }
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  void _scrollToChip(String clubId) {
    if (!_chipScrollController.hasClients) return;
    final targetContext = _chipKeys[clubId]?.currentContext;
    final viewportContext = _chipsViewportKey.currentContext;
    if (targetContext == null || viewportContext == null) return;

    final chipBox = targetContext.findRenderObject() as RenderBox?;
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (chipBox == null || viewportBox == null) return;

    final chipOffset = chipBox.localToGlobal(Offset.zero, ancestor: viewportBox);
    final currentOffset = _chipScrollController.offset;
    final chipCenter = chipOffset.dx + (chipBox.size.width / 2);
    final viewportCenter = viewportBox.size.width / 2;
    final targetOffset = currentOffset + (chipCenter - viewportCenter);
    final maxOffset = _chipScrollController.position.maxScrollExtent;

    _chipScrollController.animateTo(
      targetOffset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allClubIds.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      key: _chipsViewportKey,
      height: 52,
      child: ListView.builder(
        key: const PageStorageKey<String>('clubs_chips_bar'),
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: widget.allClubIds.length,
        itemBuilder: (context, index) {
          final id = widget.allClubIds[index];
          final isSelected = id == widget.selectedClubId;
          final color = _clubColor(id);
          final chipKey = _chipKeys.putIfAbsent(id, () => GlobalKey());
          final label = formatClubNameWithEmoji(
            widget.clubNamesCache[id] ?? id,
            widget.clubSportsCache[id],
          );
          return GestureDetector(
            key: chipKey,
            onTap: () {
              if (isSelected) return;
              widget.onClubChanged(id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.35),
                  width: isSelected ? 0 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClubInfoContent extends StatefulWidget {
  final String selectedClubId;

  const _ClubInfoContent({required this.selectedClubId});

  @override
  State<_ClubInfoContent> createState() => _ClubInfoContentState();
}

class _ClubInfoContentState extends State<_ClubInfoContent> {
  Map<String, dynamic>? _clubStats;
  String? _loadedForClubId;
  final Map<String, Map<String, dynamic>> _statsCache = {};
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats(widget.selectedClubId);
  }

  @override
  void didUpdateWidget(covariant _ClubInfoContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedClubId != widget.selectedClubId) {
      _loadStats(widget.selectedClubId);
    }
  }

  Future<void> _loadStats(String clubId) async {
    final cached = _statsCache[clubId];
    if (_loadedForClubId == clubId && cached != null) return;
    setState(() {
      _loadedForClubId = clubId;
      _isLoadingStats = true;
      _clubStats = cached ?? _clubStats;
    });
    final result = await _fetchClubStats(clubId);
    if (mounted && _loadedForClubId == clubId) {
      setState(() {
        _statsCache[clubId] = result;
        _clubStats = result;
        _isLoadingStats = false;
      });
    }
  }

  static Future<Map<String, dynamic>> _fetchClubStats(String clubId) async {
    final db = appFirestore;

    final clubDoc =
        await db.collection(FirebaseCollections.clubs).doc(clubId).get();
    final clubData = clubDoc.data();

    final adminId = clubData?['adminId'] as String?;
    final adminsList =
        (clubData?['admins'] as List?)?.whereType<String>().toList() ?? [];
    final coachesList =
        (clubData?['coaches'] as List?)?.whereType<String>().toList() ?? [];
    final adminsCount = {
      ...{if (adminId != null) adminId},
      ...adminsList,
    }.length;
    final coachsCount = coachesList.length;

    final playersCountSnap = await db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .where('roles', arrayContains: 'player')
        .count()
        .get();
    final playersCount = playersCountSnap.count ?? 0;

    final teamsQuery = await db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .count()
        .get();

    String founderName = "Non défini";
    if (adminId != null && adminId.isNotEmpty) {
      try {
        final founderDoc = await db
            .collection(FirebaseCollections.users)
            .doc(adminId)
            .get();
        final data = founderDoc.data();
        if (data != null) {
          final firstName = data['firstName'] as String? ?? '';
          final lastName = data['lastName'] as String? ?? '';
          founderName = '$firstName $lastName'.trim();
          if (founderName.isEmpty) founderName = 'Non défini';
        }
      } catch (e) {
        AppLogger.instance.error('_fetchFounder failed',
            error: e, context: {'adminId': adminId});
      }
    }

    return {
      'data': clubData,
      'players': playersCount,
      'coachs': coachsCount,
      'admins': adminsCount,
      'teams': teamsQuery.count,
      'founder': founderName,
    };
  }

  static String _postalCodeCityLine(Map<String, dynamic>? clubData) {
    if (clubData == null) return '';
    final pc = clubData['postalCode']?.toString().trim();
    final city = clubData['city']?.toString().trim();
    final hasPc = pc != null && pc.isNotEmpty;
    final hasCity = city != null && city.isNotEmpty;
    if (!hasPc && !hasCity) return '';
    if (hasPc && hasCity) return '$pc $city';
    if (hasPc) return pc;
    return city ?? '';
  }

  int _staffRoleOrder(Map<String, dynamic> data) {
    final roles = (data['roles'] as List?)?.whereType<String>().toList() ?? [];
    final isFounder = data['isFounderAdmin'] == true ||
        roles.contains('admin_fondateur');
    if (isFounder) return 0;
    if (roles.contains('admin')) return 1;
    if (roles.contains('coach')) return 2;
    return 3;
  }

  String _staffRoleKey(Map<String, dynamic> data) {
    final order = _staffRoleOrder(data);
    if (order == 0) return 'founder';
    if (order == 1) return 'admin';
    if (order == 2) return 'coach';
    return 'member';
  }

  String _roleValueFromKey(String roleKey) {
    if (roleKey == 'founder') return 'admin_fondateur';
    if (roleKey == 'admin') return 'admin';
    if (roleKey == 'coach') return 'coach';
    return 'member';
  }

  Widget _buildStaffTilesSection(
      BuildContext context, String clubId, Color accentColor) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.members)
          .where('roles', arrayContainsAny: ['coach', 'admin', 'admin_fondateur'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ViroColors.borderColor),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(child: ViroLoader(size: 28)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final staffDocs = docs
            .where((d) => _staffRoleOrder(d.data()) <= 2)
            .toList()
          ..sort((a, b) {
            final byRole = _staffRoleOrder(a.data()) - _staffRoleOrder(b.data());
            if (byRole != 0) return byRole;
            final snapA = a.data()['snapshot'] as Map<String, dynamic>? ?? {};
            final snapB = b.data()['snapshot'] as Map<String, dynamic>? ?? {};
            final nameA = (snapA['displayName'] as String? ?? '').toLowerCase();
            final nameB = (snapB['displayName'] as String? ?? '').toLowerCase();
            return nameA.compareTo(nameB);
          });

        if (staffDocs.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ViroColors.borderColor),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: staffDocs.length,
            separatorBuilder: (context, index) {
              final currentRole = _staffRoleKey(staffDocs[index].data());
              final nextRole = _staffRoleKey(staffDocs[index + 1].data());
              if (currentRole != nextRole) {
                return const SizedBox(height: 10);
              }
              return const Divider(height: 1, indent: 16, endIndent: 16);
            },
            itemBuilder: (context, index) {
              final doc = staffDocs[index];
              final data = doc.data();
              final snapshot = data['snapshot'] as Map<String, dynamic>? ?? {};
              final displayName = snapshot['displayName'] as String? ?? '';
              final parts = displayName.trim().split(' ');
              final firstName = parts.isNotEmpty ? parts.first : null;
              final lastName = parts.length > 1 ? parts.skip(1).join(' ') : null;
              final avatarUrl = snapshot['avatarUrl'] as String?;
              final roleKey = _staffRoleKey(data);
              final roleValue = _roleValueFromKey(roleKey);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: UserDisplayTile(
                  userId: doc.id,
                  firstName: firstName,
                  lastName: lastName,
                  avatarUrl: avatarUrl,
                  navigateOnTap: false,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: _AnimatedRoleBadge(role: roleValue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilDisplayPage(userId: doc.id),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _clubStats == null
              ? const Center(child: ViroLoader())
              : KeyedSubtree(
                  key: ValueKey(widget.selectedClubId),
                  child: _buildContent(context, _clubStats!),
                ),
        ),
        if (_isLoadingStats)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final clubData = data['data'] as Map<String, dynamic>?;
    final logoUrl = clubData?['logoUrl'] as String?;
    final clubName = clubData?['name'] as String? ?? 'Club Inconnu';
    final sport = clubData?['sport'] as String?;
    final address = clubData?['address'] as String?;
    final description = clubData?['description']?.toString().trim();
    final postalLine = _postalCodeCityLine(clubData);
    final clubAccentColor = _clubColor(widget.selectedClubId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Carte identité du club ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ViroColors.borderColor),
            ),
            child: Column(
              children: [
                // Bandeau coloré en haut (couleur du club)
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: clubAccentColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: clubAccentColor.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: clubAccentColor,
                          backgroundImage: (logoUrl != null &&
                                  logoUrl.isNotEmpty)
                              ? CachedNetworkImageProvider(logoUrl)
                              : null,
                          child: (logoUrl == null || logoUrl.isEmpty)
                              ? Text(
                                  clubName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Nom + infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatClubNameWithEmoji(clubName, sport),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (address != null && address.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      postalLine.isNotEmpty
                                          ? '$address, $postalLine'
                                          : address,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (description != null && description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  height: 1.35,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Carte stats ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ViroColors.borderColor),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _StatItem(
                    label: "Joueurs",
                    count: data['players'].toString(),
                    icon: Icons.sports_handball_rounded,
                  ),
                  const VerticalDivider(
                      width: 1, thickness: 1, indent: 4, endIndent: 4),
                  _StatItem(
                    label: "Équipes",
                    count: data['teams'].toString(),
                    icon: Icons.groups_rounded,
                  ),
                  const VerticalDivider(
                      width: 1, thickness: 1, indent: 4, endIndent: 4),
                  _StatItem(
                    label: "Coachs",
                    count: data['coachs'].toString(),
                    icon: Icons.sports_rounded,
                  ),
                  const VerticalDivider(
                      width: 1, thickness: 1, indent: 4, endIndent: 4),
                  _StatItem(
                    label: "Admins",
                    count: data['admins'].toString(),
                    icon: Icons.shield_outlined,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildStaffTilesSection(context, widget.selectedClubId, clubAccentColor),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ViroColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: ViroColors.primary, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

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
    _shimmer = Tween<double>(begin: -0.8, end: 0.8)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);
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

// --- PAGE 2 : LISTE CONTACTS / STAFF ---
class _StaffListPage extends StatefulWidget {
  final String clubId;
  const _StaffListPage({required this.clubId});

  @override
  State<_StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<_StaffListPage> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _staffDocs = [];
  Map<String, String?> _phones = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.members)
        .where('roles', arrayContainsAny: ['coach', 'admin', 'admin_fondateur'])
        .snapshots()
        .listen(_onMembersUpdate);
  }

  Future<void> _onMembersUpdate(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final docs = snap.docs;
    final uids = docs.map((d) => d.id).toList();
    final phones = <String, String?>{};

    // Batch-fetch user docs pour récupérer les numéros de téléphone
    for (var i = 0; i < uids.length; i += 10) {
      final batch = uids.sublist(i, math.min(i + 10, uids.length));
      try {
        final userSnap = await appFirestore
            .collection(FirebaseCollections.users)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final d in userSnap.docs) {
          phones[d.id] = d.data()['phone'] as String?;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _staffDocs = docs;
        _phones = phones;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Staff & Contacts"),
        backgroundColor: ViroColors.background,
      ),
      body: _loading
          ? const Center(child: ViroLoader())
          : _staffDocs.isEmpty
              ? const Center(child: Text("Aucun contact trouvé"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staffDocs.length,
                  itemBuilder: (context, index) {
                    final doc = _staffDocs[index];
                    final data = doc.data();
                    final uid = doc.id;

                    final roles = (data['roles'] as List?)
                            ?.whereType<String>()
                            .toList() ??
                        [];
                    final isFounder = data['isFounderAdmin'] == true;

                    final String role = isFounder
                        ? 'admin_fondateur'
                        : roles.contains('admin')
                            ? 'admin'
                            : roles.contains('coach')
                                ? 'coach'
                                : 'user';

                    String roleLabel = "Coach";
                    Color roleColor = Colors.blue;
                    if (role == 'admin_fondateur') {
                      roleLabel = "Fondateur";
                      roleColor = Colors.orange;
                    } else if (role == 'admin') {
                      roleLabel = "Admin";
                      roleColor = Colors.orange;
                    }

                    final snapshot =
                        data['snapshot'] as Map<String, dynamic>? ?? {};
                    final displayName =
                        snapshot['displayName'] as String? ?? '';
                    final avatarUrl = snapshot['avatarUrl'] as String?;
                    final email = snapshot['email'] as String? ?? '';
                    final phone = _phones[uid];

                    // Extraire prénom/nom depuis displayName
                    final nameParts = displayName.split(' ');
                    final firstName =
                        nameParts.isNotEmpty ? nameParts.first : '';
                    final lastName = nameParts.length > 1
                        ? nameParts.sublist(1).join(' ')
                        : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: UserDisplayTile(
                          userId: uid,
                          firstName:
                              firstName.isNotEmpty ? firstName : null,
                          lastName: lastName.isNotEmpty ? lastName : null,
                          avatarUrl: avatarUrl,
                          navigateOnTap: false,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (email.isNotEmpty)
                              Text(email,
                                  style: const TextStyle(fontSize: 12)),
                            if (phone != null && phone.isNotEmpty)
                              GestureDetector(
                                onTap: () => _callPhone(phone),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined,
                                        size: 12,
                                        color: ViroColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ViroColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilDisplayPage(userId: uid),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// --- WIDGET LISTE DES ANNONCES DU CLUB ---
class _ClubAnnouncementsList extends StatefulWidget {
  final List<String> clubIds;
  final String userId;
  final bool hasMultipleClubs;
  final Map<String, String>? clubNames;
  final Map<String, String>? clubSports;

  const _ClubAnnouncementsList({
    required this.clubIds,
    required this.userId,
    this.hasMultipleClubs = false,
    this.clubNames,
    this.clubSports,
  });

  @override
  State<_ClubAnnouncementsList> createState() =>
      _ClubAnnouncementsListState();
}

class _ClubAnnouncementsListState extends State<_ClubAnnouncementsList> {
  int _limit = 20;
  final Map<String, List<QueryDocumentSnapshot>> _snapsByClub = {};
  final List<StreamSubscription> _subs = [];
  final Map<String, String> _teamNamesCache = {};
  Map<String, Map<String, dynamic>>? _clubsInfo;

  List<String> get clubIds => widget.clubIds;
  String get userId => widget.userId;
  bool get hasMultipleClubs => widget.hasMultipleClubs;
  Map<String, String>? get clubNames => widget.clubNames;
  Map<String, String>? get clubSports => widget.clubSports;

  @override
  void initState() {
    super.initState();
    _subscribeAll();
    _loadUserClubsInfo();
  }

  @override
  void didUpdateWidget(_ClubAnnouncementsList old) {
    super.didUpdateWidget(old);
    final sameClubs = old.clubIds.length == widget.clubIds.length &&
        old.clubIds.every((id) => widget.clubIds.contains(id));
    if (!sameClubs) {
      _cancelAll();
      _subscribeAll();
      _loadUserClubsInfo();
    }
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _snapsByClub.clear();
  }

  void _subscribeAll() {
    for (final clubId in clubIds) {
      final sub = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.announcements)
          .orderBy('createdAt', descending: true)
          .limit(_limit)
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() => _snapsByClub[clubId] = snap.docs);
        }
      });
      _subs.add(sub);

      appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .get()
          .then((snap) {
        if (!mounted) return;
        setState(() {
          for (final doc in snap.docs) {
            _teamNamesCache[doc.id] =
                (doc.data()['name'] as String?) ?? doc.id;
          }
        });
      });
    }
  }

  void _loadMore() {
    setState(() => _limit += 20);
    _cancelAll();
    _subscribeAll();
    _loadUserClubsInfo();
  }

  Future<void> _loadUserClubsInfo() async {
    final result = await _getUserClubsInfo();
    if (mounted) setState(() => _clubsInfo = result);
  }

  // Récupère les teamIds et catégories de l'utilisateur pour tous ses clubs
  Future<Map<String, Map<String, dynamic>>> _getUserClubsInfo() async {
    try {
      final userDoc = await appFirestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final Map<String, Map<String, dynamic>> clubsInfo = {};
      final summaries =
          (userData['profileSummaries'] as List?)?.whereType<Map>().toList() ??
              [];
      final playerSummaries =
          summaries.where((e) => e['role'] == 'player').toList();

      for (final e in playerSummaries) {
        final clubIdFromClub = e['clubId'] as String?;
        if (clubIdFromClub == null) continue;

        final member =
            await getMemberData(appFirestore, userId, clubIdFromClub);
        final player = member?['player'] as Map<String, dynamic>?;
        final teamIds =
            (player?['teamIds'] as List?)?.whereType<String>().toList() ?? [];
        List<String> categories =
            (player?['categories'] as List?)?.whereType<String>().toList() ??
                [];
        if (categories.isEmpty && teamIds.isNotEmpty) {
          final teamsSnapshot = await appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(clubIdFromClub)
              .collection(FirebaseCollections.teams)
              .get();
          for (var teamDoc in teamsSnapshot.docs) {
            if (teamIds.contains(teamDoc.id)) {
              final category = teamDoc.data()['category'] as String?;
              if (category != null && category.isNotEmpty) {
                categories.add(category);
              }
            }
          }
        }
        if (categories.isEmpty) {
          final userCategory = userData['category'] as String?;
          if (userCategory != null && userCategory.isNotEmpty) {
            categories.add(userCategory);
          }
        }

        clubsInfo[clubIdFromClub] = {
          'teamIds': teamIds,
          'categories': categories,
        };
      }

      return clubsInfo;
    } catch (e) {
      return {};
    }
  }

  bool _isMessageForUser(
    Map<String, dynamic> announcementData,
    Map<String, dynamic> userClubInfo,
  ) {
    final targetType = announcementData['targetType'] as String? ?? '';
    final targetIds =
        (announcementData['targetIds'] as List?)?.whereType<String>().toList() ??
            [];

    switch (targetType) {
      case 'Tous les membres':
        return true;
      case 'Équipes':
        final userTeamIds =
            (userClubInfo['teamIds'] as List?)?.whereType<String>().toList() ??
                [];
        return targetIds.any((id) => userTeamIds.contains(id));
      case 'Catégories':
        final userCategories =
            (userClubInfo['categories'] as List?)
                ?.whereType<String>()
                .toList() ??
                [];
        return targetIds.any((id) => userCategories.contains(id));
      case 'Joueurs':
        return targetIds.contains(userId);
      default:
        return false;
    }
  }

  String _getTimeRemaining(Timestamp? createdAt, int durationDays) {
    if (createdAt == null) return '';
    final created = createdAt.toDate();
    final expiresAt = created.add(Duration(days: durationDays));
    final now = DateTime.now();

    if (now.isAfter(expiresAt)) return 'Expiré';

    final remaining = expiresAt.difference(now);
    if (remaining.inDays > 0) {
      return '${remaining.inDays}j restant${remaining.inDays > 1 ? 's' : ''}';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h restante${remaining.inHours > 1 ? 's' : ''}';
    } else {
      return 'Expire bientôt';
    }
  }

  String _formatPublishedDate(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final date = createdAt.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return "Il y a ${diff.inMinutes} min";
    }
    if (diff.inHours < 24) {
      return "Il y a ${diff.inHours}h";
    }
    if (diff.inDays == 1) {
      return "Hier à ${DateFormat('HH:mm').format(date)}";
    }
    return DateFormat('d MMM', 'fr_FR').format(date);
  }


  Widget _buildLegend(List<String> clubIdsInAnnouncements) {
    final distinctIds = clubIdsInAnnouncements.toSet().toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final cid in distinctIds)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _clubColor(cid),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatClubNameWithEmoji(
                    clubNames?[cid] ?? cid,
                    clubSports?[cid],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTargetName(String targetType, List<String> targetIds) {
    if (targetIds.isEmpty) return 'Tous les membres';

    switch (targetType) {
      case 'Équipes':
        if (targetIds.length == 1) {
          return 'Équipe : ${_teamNamesCache[targetIds.first] ?? targetIds.first}';
        }
        return '${targetIds.length} équipes';
      case 'Catégories':
        if (targetIds.length == 1) return 'Catégorie : ${targetIds.first}';
        return '${targetIds.length} catégories';
      case 'Joueurs':
        if (targetIds.length == 1) return 'Joueur spécifique';
        return '${targetIds.length} joueurs';
      default:
        return 'Membres du club';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (clubIds.isEmpty) {
      return const Center(child: Text("Aucun club trouvé"));
    }

    // Attendre que tous les clubs aient chargé au moins une fois
    final allLoaded = clubIds.every((id) => _snapsByClub.containsKey(id));
    if (!allLoaded) {
      return const Center(child: ViroLoader());
    }

    if (_clubsInfo == null) return const Center(child: ViroLoader());
    return _buildAnnouncementsFromState(_clubsInfo!);
  }

  Widget _buildAnnouncementsFromState(
      Map<String, Map<String, dynamic>> clubsInfo) {
    final validAnnouncements = <({QueryDocumentSnapshot doc, String clubId})>[];
    int totalRawDocs = 0;

    for (final clubId in clubIds) {
      final docs = _snapsByClub[clubId] ?? [];
      totalRawDocs += docs.length;
      final userClubInfo =
          clubsInfo[clubId] ?? {'teamIds': [], 'categories': []};

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        final durationDays = data['durationDays'] as int? ?? 7;

        if (createdAt != null) {
          final expiresAt =
              createdAt.toDate().add(Duration(days: durationDays));
          if (DateTime.now().isAfter(expiresAt)) continue;
        }

        final targetIds =
            (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
        if (targetIds.isNotEmpty) {
          if (!_isMessageForUser(data, userClubInfo)) continue;
        }

        validAnnouncements.add((doc: doc, clubId: clubId));
      }
    }

    // Trier par date de création (plus récent en premier)
    validAnnouncements.sort((a, b) {
      final aCreated =
          (a.doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bCreated =
          (b.doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      return bCreated.compareTo(aCreated);
    });

    if (validAnnouncements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucune actualité pour le moment",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final showLoadMore = totalRawDocs >= _limit;
    final clubIdsInAnnouncements =
        validAnnouncements.map((a) => a.clubId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMultipleClubs && clubIdsInAnnouncements.toSet().length > 1)
          _buildLegend(clubIdsInAnnouncements),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                validAnnouncements.length + (showLoadMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == validAnnouncements.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text("Charger plus"),
                    ),
                  ),
                );
              }

              final item = validAnnouncements[index];
              final data = item.doc.data() as Map<String, dynamic>;
              final clubId = item.clubId;

              final message = data['message'] as String? ?? '';
              final targetType = data['targetType'] as String? ?? '';
              final targetIds =
                  (data['targetIds'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                      [];
              final createdAt = data['createdAt'] as Timestamp?;
              final durationDays = data['durationDays'] as int? ?? 7;
              final senderFirstName =
                  data['senderFirstName'] as String? ?? '';
              final senderLastName =
                  data['senderLastName'] as String? ?? '';

              final targetName = _formatTargetName(targetType, targetIds);
              final timeRemaining =
                  _getTimeRemaining(createdAt, durationDays);
              final publishedDate = _formatPublishedDate(createdAt);

              final isExpiringSoon = createdAt != null &&
                  createdAt
                          .toDate()
                          .add(Duration(days: durationDays))
                          .difference(DateTime.now())
                          .inDays <
                      2;

              final isNew = createdAt != null &&
                  DateTime.now()
                          .difference(createdAt.toDate())
                          .inHours <
                      24;

              final clubColor = _clubColor(clubId);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isExpiringSoon
                        ? Colors.orange.withValues(alpha: 0.5)
                        : clubColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : expéditeur + badge nouveau + temps restant
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.campaign_rounded,
                                  size: 16,
                                  color: clubColor,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: UserDisplayTile(
                                    userId: data['senderId'] as String?,
                                    firstName: senderFirstName.isNotEmpty
                                        ? senderFirstName
                                        : null,
                                    lastName: senderLastName.isNotEmpty
                                        ? senderLastName
                                        : null,
                                    compact: true,
                                    fallback: 'Administration',
                                    textStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isNew) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Nouveau",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isExpiringSoon
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : clubColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeRemaining,
                              style: TextStyle(
                                fontSize: 10,
                                color: isExpiringSoon
                                    ? Colors.orange[800]
                                    : clubColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pied de carte : cible + date de publication
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: clubColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: clubColor.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 14, color: clubColor),
                                const SizedBox(width: 6),
                                Text(
                                  targetName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: clubColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (publishedDate.isNotEmpty)
                            Text(
                              publishedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
