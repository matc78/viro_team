import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/firebase_collections.dart';
import '../../services/user_session.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firestore_instance.dart';
import '../../widget/viro_loader.dart';
import 'player_home_page.dart';
import 'player_planning_page.dart';
import 'player_teams_page.dart';
import 'player_infos_page.dart';
import 'player_loan_catalog_page.dart';

// Données statiques des onglets
const _tabs = [
  _TabData(label: 'Équipes',   icon: Icons.groups_outlined,             selectedIcon: Icons.groups_rounded),
  _TabData(label: 'Catalogue', icon: Icons.inventory_2_outlined,        selectedIcon: Icons.inventory_2_rounded),
  _TabData(label: 'Accueil',   icon: Icons.home_outlined,               selectedIcon: Icons.home_rounded),
  _TabData(label: 'Infos',     icon: Icons.notifications_none_outlined, selectedIcon: Icons.notifications_rounded),
  _TabData(label: 'Planning',  icon: Icons.calendar_month_outlined,     selectedIcon: Icons.calendar_month_rounded),
];

class _TabData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabData({required this.label, required this.icon, required this.selectedIcon});
}

// ─────────────────────────────────────────────────────────────────────────────

class PlayerShell extends StatefulWidget {
  const PlayerShell({super.key});

  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell>
    with TickerProviderStateMixin {
  int _currentIndex = 2; // Accueil par défaut
  String? _clubId;
  List<Widget>? _pages;

  // Animation de transition de page : fade + léger slide vertical
  late final AnimationController _pageCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _pageSlide;

  // Pastille Planning
  bool _badgePlanning = false;
  StreamSubscription<QuerySnapshot>? _badgeSubMember;
  StreamSubscription<QuerySnapshot>? _badgeSubToday;
  // Résultats intermédiaires des deux streams
  bool _badgeFromMember = false;
  bool _badgeFromToday = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pageOpacity = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = Provider.of<UserSession>(context, listen: false);
    final newClubId = session.currentClubId;
    if (newClubId != null && newClubId != _clubId) {
      _clubId = newClubId;
      _pages = _buildPages(newClubId);
      _setupBadgeStream(session.playerClubIds.isNotEmpty
          ? session.playerClubIds
          : [newClubId]);
    }
  }

  @override
  void dispose() {
    _badgeSubMember?.cancel();
    _badgeSubToday?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  void _setupBadgeStream(List<String> clubIds) {
    _badgeSubMember?.cancel();
    _badgeSubToday?.cancel();
    _badgeFromMember = false;
    _badgeFromToday = false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || clubIds.isEmpty) return;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayId = _todayId();

    // Pour chaque club, on accumule les snapshots et on recompute
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> memberSnapsByClub = {};
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> todaySnapsByClub = {};

    void recomputeMember() {
      final allDocs = memberSnapsByClub.values.expand((d) => d).toList();
      _badgeFromMember = allDocs.any((doc) {
        final data = doc.data();
        if (data['canceled'] == true) return false;
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(startOfToday)) return false;
        final attendance = (data['attendance'] as Map<String, dynamic>?) ?? {};
        final myStatus = attendance[uid] as String?;
        final hasResponded = myStatus == 'present' || myStatus == 'absent';
        final isToday = (data['dateId'] as String?) == todayId;
        return !hasResponded || isToday;
      });
      if (mounted) setState(() => _badgePlanning = _badgeFromMember || _badgeFromToday);
    }

    void recomputeToday() {
      final allDocs = todaySnapsByClub.values.expand((d) => d).toList();
      _badgeFromToday = allDocs.any((doc) {
        final data = doc.data();
        if (data['canceled'] == true) return false;
        final memberIds = (data['teamMemberIds'] as List?) ?? [];
        if (memberIds.contains(uid)) return false; // géré par stream member
        if (memberIds.isNotEmpty) return false;
        final attendance = (data['attendance'] as Map<String, dynamic>?) ?? {};
        final myStatus = attendance[uid] as String?;
        return myStatus != 'present' && myStatus != 'absent';
      });
      if (mounted) setState(() => _badgePlanning = _badgeFromMember || _badgeFromToday);
    }

    for (final cid in clubIds) {
      memberSnapsByClub[cid] = [];
      todaySnapsByClub[cid] = [];

      // Stream 1 : teamMemberIds contient le joueur
      _badgeSubMember = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(cid)
          .collection(FirebaseCollections.events)
          .where('teamMemberIds', arrayContains: uid)
          .snapshots()
          .listen((snap) {
        memberSnapsByClub[cid] = snap.docs;
        recomputeMember();
      });

      // Stream 2 : events du jour (teamMemberIds vide = event global)
      _badgeSubToday = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(cid)
          .collection(FirebaseCollections.events)
          .where('dateId', isEqualTo: todayId)
          .snapshots()
          .listen((snap) {
        todaySnapsByClub[cid] = snap.docs;
        recomputeToday();
      });
    }
  }

  List<Widget> _buildPages(String clubId) => [
    PlayerTeamsPage(clubId: clubId),
    PlayerLoanCatalogPage(clubId: clubId),
    PlayerHomePage(onSwitchToPlanning: () => _switchTab(4)),
    PlayerInfosPage(clubId: clubId),
    PlayerPlanningPage(clubId: clubId),
  ];

  Future<void> _switchTab(int index) async {
    if (index == _currentIndex) return;
    // Fondu sortant
    await _pageCtrl.reverse();
    if (!mounted) return;
    setState(() => _currentIndex = index);
    // Fondu entrant avec slide depuis le bas (subtil)
    _pageCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<UserSession>(context);
    final clubId = session.currentClubId;

    if (clubId == null || _pages == null) {
      return const Scaffold(body: Center(child: ViroLoader(size: 60)));
    }

    if (clubId != _clubId) {
      _clubId = clubId;
      _pages = _buildPages(clubId);
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _pageOpacity,
        child: SlideTransition(
          position: _pageSlide,
          child: IndexedStack(index: _currentIndex, children: _pages!),
        ),
      ),
      bottomNavigationBar: _PlayerNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        badges: [false, false, false, false, _badgePlanning],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre de navigation custom
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<bool> badges;

  const _PlayerNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (int i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: _tabs[i],
                    isSelected: i == currentIndex,
                    isCenter: i == 2,
                    hasBadge: i < badges.length && badges[i],
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item de navigation individuel avec animations
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final _TabData tab;
  final bool isSelected;
  final bool isCenter;
  final bool hasBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.isCenter,
    required this.hasBadge,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pillAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    // Bounce : légère surtension à 1.15 puis retour à 1.1
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.10), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _pillAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _ctrl.forward(from: 0);
    } else if (!widget.isSelected && old.isSelected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    if (widget.isCenter) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: isSelected ? _scaleAnim.value : 1.0,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.grey.shade200, ViroColors.primary, _pillAnim.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ViroColors.primary.withValues(alpha: _pillAnim.value * 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSelected ? widget.tab.selectedIcon : widget.tab.icon,
                    size: 24,
                    color: Color.lerp(Colors.grey[500], Colors.white, _pillAnim.value),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              // Icône : grandit quand sélectionné (22 → 28), rétrécit sinon
              final iconSize = 22.0 + _pillAnim.value * 6.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isSelected ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: ViroColors.primary.withValues(
                            alpha: _pillAnim.value * 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Transform.scale(
                          scale: isSelected ? _scaleAnim.value : 1.0,
                          child: Icon(
                            isSelected ? widget.tab.selectedIcon : widget.tab.icon,
                            size: iconSize,
                            color: Color.lerp(
                              Colors.grey[400],
                              ViroColors.primary,
                              _pillAnim.value,
                            ),
                          ),
                        ),
                      ),
                      if (widget.hasBadge)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Label : disparaît quand sélectionné
                  SizedBox(
                    height: 16,
                    child: Opacity(
                      opacity: (1.0 - _pillAnim.value).clamp(0.0, 1.0),
                      child: Text(
                        widget.tab.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
