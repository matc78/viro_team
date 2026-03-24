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
import 'admin_home_page.dart';
import 'admin_planning_page.dart';
import 'admin_equipment_page.dart';
import 'admin_club_communication_page.dart';
import 'admin_coach_mode_page.dart';

// Données statiques des onglets
const _tabs = [
  _TabData(label: 'Équipement', icon: Icons.inventory_2_outlined,        selectedIcon: Icons.inventory_2_rounded),
  _TabData(label: 'Communiquer', icon: Icons.campaign_outlined,           selectedIcon: Icons.campaign_rounded),
  _TabData(label: 'Accueil',     icon: Icons.home_outlined,               selectedIcon: Icons.home_rounded),
  _TabData(label: 'Coach',       icon: Icons.sports_score_outlined,       selectedIcon: Icons.sports_score),
  _TabData(label: 'Planning',    icon: Icons.calendar_month_outlined,     selectedIcon: Icons.calendar_month_rounded),
];

class _TabData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabData({required this.label, required this.icon, required this.selectedIcon});
}

// ─────────────────────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TickerProviderStateMixin {
  int _currentIndex = 2; // Accueil par défaut
  String? _clubId;
  List<Widget>? _pages;

  // Animation de transition de page : fade + léger slide vertical
  late final AnimationController _pageCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _pageSlide;

  // Pastilles de notification
  bool _badgeEquipement = false;
  bool _badgePlanning = false;

  Set<String> _coachedTeamNames = {};
  List<Map<String, dynamic>> _todayEvents = [];
  final List<StreamSubscription> _badgeSubs = [];

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
    final newClubId = Provider.of<UserSession>(context, listen: false).currentClubId;
    if (newClubId != null && newClubId != _clubId) {
      _clubId = newClubId;
      _pages = _buildPages(newClubId);
      _setupBadgeStreams(newClubId);
    }
  }

  @override
  void dispose() {
    for (final sub in _badgeSubs) {
      sub.cancel();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  void _setupBadgeStreams(String clubId) {
    for (final sub in _badgeSubs) {
      sub.cancel();
    }
    _badgeSubs.clear();
    _coachedTeamNames = {};
    _todayEvents = [];

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final todayId = _todayId();

    // Stream 1 : équipes où l'utilisateur est coach
    _badgeSubs.add(
      appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .where('coachIds', arrayContains: uid)
          .snapshots()
          .listen((snap) {
        _coachedTeamNames = snap.docs
            .map((d) => (d.data()['name'] as String?) ?? '')
            .where((n) => n.isNotEmpty)
            .toSet();
        _recomputeEventBadges();
      }),
    );

    // Stream 2 : événements aujourd'hui
    _badgeSubs.add(
      appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.events)
          .where('dateId', isEqualTo: todayId)
          .snapshots()
          .listen((snap) {
        _todayEvents = snap.docs.map((d) => d.data()).toList();
        _recomputeEventBadges();
      }),
    );

    // Stream 3 : prêts actifs dont le retour est aujourd'hui
    _badgeSubs.add(
      appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen((snap) {
        _recomputeEquipementBadge(snap.docs, null);
      }),
    );

    // Stream 4 : demandes de prêt acceptées dont le retrait est aujourd'hui
    _badgeSubs.add(
      appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snap) {
        _recomputeEquipementBadge(null, snap.docs);
      }),
    );
  }

  // Garde le résultat des deux streams d'équipement pour combiner
  bool _hasLoanReturn = false;
  bool _hasLoanPickup = false;

  void _recomputeEquipementBadge(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? loanDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? requestDocs,
  ) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    if (loanDocs != null) {
      _hasLoanReturn = loanDocs.any((d) {
        final dueAt = (d.data()['dueAt'] as Timestamp?)?.toDate();
        if (dueAt == null) return false;
        return !dueAt.isBefore(startOfToday) && dueAt.isBefore(endOfToday);
      });
    }
    if (requestDocs != null) {
      _hasLoanPickup = requestDocs.any((d) {
        final pickup = (d.data()['requestedPickupDate'] as Timestamp?)?.toDate();
        if (pickup == null) return false;
        return !pickup.isBefore(startOfToday) && pickup.isBefore(endOfToday);
      });
    }
    if (mounted) setState(() => _badgeEquipement = _hasLoanReturn || _hasLoanPickup);
  }

  void _recomputeEventBadges() {
    bool planning = false;

    for (final event in _todayEvents) {
      final type = (event['type'] as String?) ?? '';
      final isTrainingOrMatch = type == 'Entraînement' || type == 'Match';

      if (isTrainingOrMatch) {
        final teamName = event['teamName'] as String?;
        final teamNames = (event['teamNames'] as List?)
            ?.map((e) => e.toString())
            .toList();
        final eventTeams = <String>{
          if (teamName != null && teamName.isNotEmpty) teamName,
          ...?teamNames,
        };
        if (eventTeams.any(_coachedTeamNames.contains)) {
          planning = true;
        }
      } else {
        planning = true;
      }
    }

    if (mounted) {
      setState(() {
        _badgePlanning = planning;
      });
    }
  }

  // sport est optionnel dans les deux pages qui en ont besoin — elles le
  // récupèrent elles-mêmes depuis Firestore si non fourni.
  List<Widget> _buildPages(String clubId) => [
    AdminEquipmentPage(clubId: clubId),
    AdminClubCommunicationPage(clubId: clubId),
    const AdminHomePage(),
    AdminCoachModePage(clubId: clubId),
    AdminPlanningPage(clubId: clubId),
  ];

  Future<void> _switchTab(int index) async {
    if (index == _currentIndex) return;
    await _pageCtrl.reverse();
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _pageCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final clubId = Provider.of<UserSession>(context).currentClubId;

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
      bottomNavigationBar: _AdminNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        badges: [_badgeEquipement, false, false, false, _badgePlanning],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre de navigation custom
// ─────────────────────────────────────────────────────────────────────────────

class _AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<bool> badges;

  const _AdminNavBar({
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

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
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

    // L'onglet central (Accueil) a un bouton surélevé
    if (widget.isCenter) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: isSelected ? _scaleAnim.value : 1.0,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.grey.shade200,
                        ViroColors.primary,
                        _pillAnim.value,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ViroColors.primary.withValues(
                            alpha: _pillAnim.value * 0.35,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isSelected ? widget.tab.selectedIcon : widget.tab.icon,
                      size: 24,
                      color: Color.lerp(
                        Colors.grey[500],
                        Colors.white,
                        _pillAnim.value,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
              final iconSize = 22.0 + _pillAnim.value * 6.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
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
