import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/firebase_collections.dart';
import '../../models/club_fee_settings.dart';
import '../../models/member_fee.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/fee_format.dart';
import '../../utils/fee_status_ui.dart';
import '../../utils/firestore_instance.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import 'admin_member_fee_detail_page.dart';
import 'widgets/fee_bulk_action_dialog.dart';
import 'widgets/fee_home_fab.dart';

/// Liste des joueurs avec filtre par statut de cotisation.
class AdminFeeMembersPage extends StatefulWidget {
  final String clubId;
  final String seasonId;

  /// Si défini (ex. depuis le tableau de bord), le filtre est pré-sélectionné.
  final MemberFeeStatus? initialStatusFilter;
  final bool initialPendingOnlyFilter;

  const AdminFeeMembersPage({
    super.key,
    required this.clubId,
    required this.seasonId,
    this.initialStatusFilter,
    this.initialPendingOnlyFilter = false,
  });

  @override
  State<AdminFeeMembersPage> createState() => _AdminFeeMembersPageState();
}

class _AdminFeeMembersPageState extends State<AdminFeeMembersPage> {
  MemberFeeStatus? _filter;
  bool _pendingOnlyFilter = false;
  bool _selectionMode = false;
  final Set<String> _selectedUids = {};

  ClubFeeSettings? _latestSettings;
  Map<String, MemberFee?> _latestFeeMap = {};

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  final Map<String, String> _nameCache = {};
  final Set<String> _loadedUids = {};
  final Set<String> _pendingUids = {}; // membres sans document users/{uid}

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatusFilter;
    _pendingOnlyFilter = widget.initialPendingOnlyFilter;
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Charge les noms des UIDs manquants depuis la collection users.
  void _ensureNamesLoaded(List<String> uids) {
    final missing = uids.where((uid) => !_loadedUids.contains(uid)).toList();
    if (missing.isEmpty) return;
    _loadedUids.addAll(missing);

    Future.wait(
      missing.map(
        (uid) => appFirestore
            .collection(FirebaseCollections.users)
            .doc(uid)
            .get(),
      ),
    ).then((docs) {
      if (!mounted) return;
      final updates = <String, String>{};
      final pending = <String>{};
      for (final doc in docs) {
        if (!doc.exists) {
          pending.add(doc.id);
          continue;
        }
        final d = doc.data() ?? {};
        final first = (d['firstName'] as String? ?? '').trim();
        final last = (d['lastName'] as String? ?? '').trim();
        final name = '$first $last'.trim();
        if (name.isNotEmpty) updates[doc.id] = name;
      }
      setState(() {
        if (updates.isNotEmpty) _nameCache.addAll(updates);
        if (pending.isNotEmpty) _pendingUids.addAll(pending);
      });
    }).catchError((_) {});
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedUids.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fabVisible = _selectionMode && _selectedUids.isNotEmpty;

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedUids.length} sélectionné(s)'
              : 'Cotisations des joueurs',
        ),
        centerTitle: true,
        actions: [
          if (_selectionMode && _selectedUids.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selectedUids.clear),
              child: const Text('Effacer'),
            ),
          IconButton(
            tooltip: _selectionMode ? 'Quitter la sélection' : 'Sélectionner',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist_outlined),
            onPressed: () {
              if (_selectionMode) {
                _exitSelectionMode();
              } else {
                setState(() => _selectionMode = true);
              }
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (fabVisible)
            FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showFeeBulkActionDialog(
                  context: context,
                  clubId: widget.clubId,
                  seasonId: widget.seasonId,
                  settings: _latestSettings,
                  existingByUidForSelected: {
                    for (final id in _selectedUids) id: _latestFeeMap[id],
                  },
                  selectedUserIds: _selectedUids.toList(),
                );
                if (ok == true && mounted) {
                  setState(() {
                    _selectedUids.clear();
                    _selectionMode = false;
                  });
                }
              },
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Actions groupées'),
            ),
          if (fabVisible) const SizedBox(height: 10),
          const FeeHomeFab(),
        ],
      ),
      body: StreamBuilder<ClubFeeSettings?>(
        stream: FeeService.instance.watchFeeSettings(
          widget.clubId,
          widget.seasonId,
        ),
        builder: (context, settingsSnap) {
          final settings = settingsSnap.data;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(widget.clubId)
                .collection(FirebaseCollections.members)
                .snapshots(),
            builder: (context, membersSnap) {
              if (!membersSnap.hasData) {
                return const Center(child: ViroLoader(size: 48));
              }
              final playerEntries = <Map<String, dynamic>>[];
              for (final doc in membersSnap.data!.docs) {
                final roles =
                    (doc.data()['roles'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                if (!roles.contains('player')) continue;
                playerEntries.add({
                  'uid': doc.id,
                  'isPending': false,
                  'firstName': null,
                  'lastName': null,
                  'email': null,
                });
                // Pré-cache le nom si dénormalisé dans le document membre
                final data = doc.data();
                final first = (data['firstName'] as String? ?? '').trim();
                final last = (data['lastName'] as String? ?? '').trim();
                final name = '$first $last'.trim();
                if (name.isNotEmpty && !_nameCache.containsKey(doc.id)) {
                  _nameCache[doc.id] = name;
                  _loadedUids.add(doc.id);
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: appFirestore
                    .collection(FirebaseCollections.clubs)
                    .doc(widget.clubId)
                    .collection(FirebaseCollections.pendingMembers)
                    .snapshots(),
                builder: (context, pendingSnap) {
                  if (!pendingSnap.hasData) {
                    return const Center(child: ViroLoader(size: 48));
                  }
                  final pendingEntries = <Map<String, dynamic>>[];
                  for (final doc in pendingSnap.data!.docs) {
                    final data = doc.data();
                    final status =
                        (data['invitationStatus'] as String?) ??
                        (data['status'] as String?) ??
                        'pending';
                    if (status == 'declined') continue;
                    pendingEntries.add({
                      'uid': doc.id,
                      'isPending': true,
                      'firstName': (data['firstName'] as String? ?? '').trim(),
                      'lastName': (data['lastName'] as String? ?? '').trim(),
                      'email': (data['email'] as String? ?? '').trim(),
                    });
                  }

                  return StreamBuilder<List<MemberFee>>(
                    stream: FeeService.instance.watchAllMemberFees(
                      widget.clubId,
                      widget.seasonId,
                    ),
                    builder: (context, feeSnap) {
                      if (!feeSnap.hasData) {
                        return const Center(child: ViroLoader(size: 48));
                      }
                      final feeMap = {for (final f in feeSnap.data!) f.userId: f};
                      _latestSettings = settings;
                      _latestFeeMap = feeMap;
                      final now = DateTime.now();

                      MemberFeeStatus effectiveStatus(String uid) {
                        final mf = feeMap[uid];
                        final fee =
                            mf ??
                            MemberFee(
                              userId: uid,
                              status: MemberFeeStatus.nonConfigure,
                            );
                        return fee.effectiveDisplayStatus(settings, now);
                      }

                      // Déclenche le chargement des noms (async, met à jour _nameCache)
                      _ensureNamesLoaded(
                        playerEntries.map((e) => e['uid'] as String).toList(),
                      );

                      final allEntries = <Map<String, dynamic>>[
                        ...playerEntries,
                        ...pendingEntries,
                      ];
                      var rows = allEntries;
                      if (_filter != null) {
                        rows = rows
                            .where(
                              (e) =>
                                  effectiveStatus(e['uid'] as String) == _filter,
                            )
                            .toList();
                      }
                      if (_pendingOnlyFilter) {
                        rows = rows
                            .where((e) => e['isPending'] == true)
                            .toList();
                      }
                      if (_search.isNotEmpty) {
                        rows = rows.where((e) {
                          final uid = e['uid'] as String;
                          final isPending = e['isPending'] == true;
                          if (isPending) {
                            final first =
                                (e['firstName'] as String? ?? '').toLowerCase();
                            final last =
                                (e['lastName'] as String? ?? '').toLowerCase();
                            final email =
                                (e['email'] as String? ?? '').toLowerCase();
                            final full = '$first $last'.trim();
                            return full.contains(_search) ||
                                email.contains(_search);
                          }
                          // Nom pas encore chargé → on garde la ligne visible
                          if (!_nameCache.containsKey(uid)) return true;
                          return _nameCache[uid]!
                              .toLowerCase()
                              .contains(_search);
                        }).toList();
                      }

                      rows.sort((a, b) {
                        String labelFor(Map<String, dynamic> e) {
                          final uid = e['uid'] as String;
                          final isPending = e['isPending'] == true;
                          if (isPending) {
                            final first = (e['firstName'] as String? ?? '').trim();
                            final last = (e['lastName'] as String? ?? '').trim();
                            final email = (e['email'] as String? ?? '').trim();
                            final full = '$first $last'.trim();
                            return full.isNotEmpty ? full : (email.isNotEmpty ? email : uid);
                          }
                          return _nameCache[uid] ?? uid;
                        }

                        return labelFor(a).toLowerCase().compareTo(
                          labelFor(b).toLowerCase(),
                        );
                      });

                      return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barre de recherche
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un joueur...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      // Barre de filtres
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Row(
                          children: [
                            _FilterBadge(
                              label: 'Tous',
                              icon: Icons.people_outline,
                              selected: _filter == null && !_pendingOnlyFilter,
                              unselectedBg: Colors.grey.shade200,
                              unselectedFg: Colors.grey.shade700,
                              onTap: () => setState(() {
                                _filter = null;
                                _pendingOnlyFilter = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            for (final s in MemberFeeStatus.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterBadge(
                                  label: s.label,
                                  icon: feeStatusIcon(s),
                                  selected: _filter == s,
                                  unselectedBg: feeStatusColor(s),
                                  unselectedFg: feeStatusTextColor(s),
                                  onTap: () => setState(
                                    () {
                                      _filter = _filter == s ? null : s;
                                      _pendingOnlyFilter = false;
                                    },
                                  ),
                                ),
                              ),
                            _FilterBadge(
                              label: 'Compte non créé',
                              icon: Icons.person_off_outlined,
                              selected: _pendingOnlyFilter,
                              unselectedBg: Colors.orange.shade100,
                              unselectedFg: Colors.orange.shade800,
                              onTap: () => setState(() {
                                _pendingOnlyFilter = !_pendingOnlyFilter;
                                if (_pendingOnlyFilter) {
                                  _filter = null;
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                      if (_selectionMode && rows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _selectedUids
                                  ..clear()
                                  ..addAll(
                                    rows.map((e) => e['uid'] as String),
                                  );
                              }),
                              icon: const Icon(Icons.select_all, size: 20),
                              label: const Text(
                                'Tout sélectionner (filtre actuel)',
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: rows.isEmpty
                            ? _EmptyState(
                                filter: _filter,
                                pendingOnlyFilter: _pendingOnlyFilter,
                                hasPlayers: allEntries.isNotEmpty,
                                onClearFilter: () =>
                                    setState(() {
                                      _filter = null;
                                      _pendingOnlyFilter = false;
                                    }),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  fabVisible ? 88 : 16,
                                ),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: Colors.grey[200]),
                                itemBuilder: (context, i) {
                                  final uid = rows[i]['uid'] as String;
                                  final isPendingRow =
                                      rows[i]['isPending'] == true;
                                  final pendingFirst =
                                      rows[i]['firstName'] as String? ?? '';
                                  final pendingLast =
                                      rows[i]['lastName'] as String? ?? '';
                                  final pendingEmail =
                                      rows[i]['email'] as String? ?? '';
                                  final mf = feeMap[uid];
                                  final status = effectiveStatus(uid);
                                  final due = mf?.amountDueCents(settings) ?? 0;
                                  final paid = mf?.amountPaidCents ?? 0;
                                  final rest =
                                      mf?.remainingCents(settings) ?? 0;
                                  final isLate =
                                      status == MemberFeeStatus.enRetard;
                                  final isPending =
                                      isPendingRow || _pendingUids.contains(uid);

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    color: isLate
                                        ? ViroColors.error.withValues(alpha: 0.04)
                                        : null,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                      leading: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: _selectionMode
                                            ? Checkbox(
                                                key: const ValueKey('cb'),
                                                value: _selectedUids.contains(
                                                  uid,
                                                ),
                                                onChanged: (v) {
                                                  setState(() {
                                                    if (v == true) {
                                                      _selectedUids.add(uid);
                                                    } else {
                                                      _selectedUids.remove(uid);
                                                    }
                                                  });
                                                },
                                              )
                                            : const SizedBox.shrink(
                                                key: ValueKey('empty'),
                                              ),
                                      ),
                                      title: UserDisplayTile(
                                        userId: isPendingRow ? null : uid,
                                        firstName: isPendingRow
                                            ? pendingFirst
                                            : null,
                                        lastName: isPendingRow ? pendingLast : null,
                                        fallback: isPendingRow &&
                                                pendingEmail.isNotEmpty
                                            ? pendingEmail
                                            : 'Membre',
                                        compact: false,
                                        navigateOnTap: false,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dû ${formatEurosFromCents(due)} · Payé ${formatEurosFromCents(paid)} · Reste ${formatEurosFromCents(rest)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          if (isPending)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                  border: Border.all(
                                                    color:
                                                        Colors.orange.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Compte non créé',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.orange.shade800,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: FeeStatusChip(status: status),
                                      onTap: () {
                                        if (_selectionMode) {
                                          setState(() {
                                            if (_selectedUids.contains(uid)) {
                                              _selectedUids.remove(uid);
                                            } else {
                                              _selectedUids.add(uid);
                                            }
                                          });
                                        } else {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  AdminMemberFeeDetailPage(
                                                    clubId: widget.clubId,
                                                    seasonId: widget.seasonId,
                                                    userId: uid,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
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
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final MemberFeeStatus? filter;
  final bool pendingOnlyFilter;
  final bool hasPlayers;
  final VoidCallback onClearFilter;

  const _EmptyState({
    required this.filter,
    required this.pendingOnlyFilter,
    required this.hasPlayers,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;

    if (!hasPlayers) {
      message = 'Aucun joueur dans ce club.';
      icon = Icons.people_outline;
    } else if (pendingOnlyFilter) {
      message = 'Aucun compte non créé pour ce filtre.';
      icon = Icons.person_off_outlined;
    } else if (filter != null) {
      message = 'Aucun joueur avec le statut « ${filter!.label} ».';
      icon = feeStatusIcon(filter!);
    } else {
      message = 'Aucun joueur pour ce filtre.';
      icon = Icons.filter_list_off;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            if (filter != null || pendingOnlyFilter) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.clear),
                label: const Text('Voir tous les joueurs'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color unselectedBg;
  final Color unselectedFg;
  final VoidCallback onTap;

  const _FilterBadge({
    required this.label,
    required this.icon,
    required this.selected,
    required this.unselectedBg,
    required this.unselectedFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? ViroColors.primary : unselectedBg;
    final fg = selected ? Colors.white : unselectedFg;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.10 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: unselectedFg.withValues(alpha: 0.35)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ViroColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
