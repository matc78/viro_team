import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../constants/firebase_collections.dart';
import '../../../../models/tournament/tournament_model.dart';
import '../../../../models/tournament/tournament_team.dart';
import '../../../../theme/viro_theme.dart';
import '../../../../utils/firestore_instance.dart';
import '../../../../utils/tournament_draft.dart';
import '../../../../widget/user_display_tile.dart';

class Step4Teams extends StatefulWidget {
  final String clubId;
  final TournamentStructure structure;
  final int nbGroups;
  final int playersPerTeam;
  final List<String> selectedPlayerIds;
  final List<TournamentTeam> teams;
  final bool isManualDraft;
  final double driftFactor;
  final Map<String, Map<String, String>> guestPlayers;

  final ValueChanged<List<String>> onPlayersChanged;
  final ValueChanged<List<TournamentTeam>> onTeamsChanged;
  final ValueChanged<bool> onManualDraftChanged;
  final ValueChanged<double> onDriftFactorChanged;
  final ValueChanged<Map<String, Map<String, String>>> onGuestPlayersChanged;

  const Step4Teams({
    super.key,
    required this.clubId,
    required this.structure,
    required this.nbGroups,
    required this.playersPerTeam,
    required this.selectedPlayerIds,
    required this.teams,
    required this.isManualDraft,
    required this.driftFactor,
    required this.guestPlayers,
    required this.onPlayersChanged,
    required this.onTeamsChanged,
    required this.onManualDraftChanged,
    required this.onDriftFactorChanged,
    required this.onGuestPlayersChanged,
  });

  @override
  State<Step4Teams> createState() => _Step4TeamsState();
}

class _Step4TeamsState extends State<Step4Teams> {
  String? _pendingSwapPlayerId;
  String? _pendingSwapTeamId;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;
  String? _filterTeamName;

  static const List<Color> _teamColors = [
    Color(0xFF2F27CE),
    Color(0xFFE91E63),
    Color(0xFF00B8D4),
    Color(0xFFFF6D00),
    Color(0xFF6200EA),
    Color(0xFF00C853),
    Color(0xFFD50000),
    Color(0xFF0091EA),
  ];

  static const List<String> _teamNames = [
    'Équipe A',
    'Équipe B',
    'Équipe C',
    'Équipe D',
    'Équipe E',
    'Équipe F',
    'Équipe G',
    'Équipe H',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _nbTeams {
    switch (widget.structure) {
      case TournamentStructure.championnatSeul:
        return widget.nbGroups == 1 ? 4 : widget.nbGroups * 2;
      case TournamentStructure.tournoiSeul:
        return widget.selectedPlayerIds.isEmpty
            ? 4
            : (widget.selectedPlayerIds.length / widget.playersPerTeam).ceil();
      case TournamentStructure.poulesVersTournoi:
      case TournamentStructure.poulesInterVersTournoi:
        return widget.nbGroups * 2;
    }
  }

  void _generateTeams() {
    if (widget.selectedPlayerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un participant.')),
      );
      return;
    }

    final nbTeams = _nbTeams;
    final distribution = windowDraft(
      widget.selectedPlayerIds,
      nbTeams,
      widget.driftFactor,
    );

    final teams = List.generate(distribution.length, (i) {
      final color = _teamColors[i % _teamColors.length];
      final colorHex =
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      return TournamentTeam(
        id: 'team_$i',
        name: i < _teamNames.length ? _teamNames[i] : 'Équipe ${i + 1}',
        playerIds: distribution[i],
        colorHex: colorHex,
      );
    });

    widget.onTeamsChanged(teams);
  }

  void _onPlayerTap(String playerId, String teamId) {
    if (_pendingSwapPlayerId == null) {
      setState(() {
        _pendingSwapPlayerId = playerId;
        _pendingSwapTeamId = teamId;
      });
    } else if (_pendingSwapTeamId == teamId &&
        _pendingSwapPlayerId == playerId) {
      setState(() {
        _pendingSwapPlayerId = null;
        _pendingSwapTeamId = null;
      });
    } else {
      final fromTeamId = _pendingSwapTeamId!;
      final fromPlayerId = _pendingSwapPlayerId!;
      final toTeamId = teamId;
      final toPlayerId = playerId;

      setState(() {
        _pendingSwapPlayerId = null;
        _pendingSwapTeamId = null;
      });

      _confirmSwap(fromPlayerId, fromTeamId, toPlayerId, toTeamId);
    }
  }

  void _confirmSwap(
    String playerAId,
    String fromTeamId,
    String playerBId,
    String toTeamId,
  ) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l\'échange ?'),
        content: const Text(
          'Ces deux joueurs vont être échangés entre leurs équipes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Échanger'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) return;
      _doLocalSwap(playerAId, fromTeamId, playerBId, toTeamId);
    });
  }

  void _doLocalSwap(
    String playerAId,
    String fromTeamId,
    String playerBId,
    String toTeamId,
  ) {
    final updated = widget.teams.map((team) {
      if (team.id == fromTeamId) {
        final ids = List<String>.from(team.playerIds);
        ids.remove(playerAId);
        ids.add(playerBId);
        return team.copyWith(playerIds: ids);
      } else if (team.id == toTeamId) {
        final ids = List<String>.from(team.playerIds);
        ids.remove(playerBId);
        ids.add(playerAId);
        return team.copyWith(playerIds: ids);
      }
      return team;
    }).toList();
    widget.onTeamsChanged(updated);
  }

  void _togglePlayer(String uid) {
    final updated = List<String>.from(widget.selectedPlayerIds);
    if (updated.contains(uid)) {
      updated.remove(uid);
    } else {
      updated.add(uid);
    }
    widget.onPlayersChanged(updated);
  }

  String _getFirstName(String uid, Map<String, Map<String, dynamic>> memberData) {
    if (uid.startsWith('guest_')) {
      return widget.guestPlayers[uid]?['firstName'] ?? 'Invité';
    }
    final snap = (memberData[uid]?['snapshot'] as Map?) ?? {};
    final first = snap['firstName'] as String?;
    if (first != null && first.isNotEmpty) return first;
    // Fallback : premier mot du displayName
    final display = snap['displayName'] as String? ?? '';
    return display.split(' ').first;
  }

  String _getDisplayName(
    String uid,
    Map<String, Map<String, dynamic>> memberData,
  ) {
    if (uid.startsWith('guest_')) {
      final g = widget.guestPlayers[uid];
      if (g != null) {
        return '${g['firstName'] ?? ''} ${g['lastName'] ?? ''}'.trim();
      }
      return 'Invité';
    }
    final snap = (memberData[uid]?['snapshot'] as Map?) ?? {};
    final first = snap['firstName'] as String? ?? '';
    final last = snap['lastName'] as String? ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    // Fallback : displayName
    return snap['displayName'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.members)
          .snapshots(),
      builder: (context, snap) {
        final memberDocs = snap.data?.docs ?? [];
        final memberData = <String, Map<String, dynamic>>{
          for (final d in memberDocs) d.id: d.data(),
        };

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildParticipantPicker(memberData),
            const SizedBox(height: 12),
            _buildSelectedPlayersList(memberData),
            const SizedBox(height: 20),
            _buildModeToggle(),
            const SizedBox(height: 20),
            if (!widget.isManualDraft) ...[
              _buildRandomSection(),
              const SizedBox(height: 20),
            ],
            if (widget.teams.isNotEmpty) ...[
              const Text(
                'Équipes',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 12),
              ...widget.teams.map((team) => _buildTeamCard(team, memberData)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildParticipantPicker(
    Map<String, Map<String, dynamic>> memberData,
  ) {
    final players = memberData.entries
        .where((e) => (e.value['roles'] as List?)?.contains('player') ?? false)
        .toList();

    // Collect all categories and team names
    final allCategories = <String>{};
    final allTeamNames = <String>{};
    for (final e in players) {
      final playerInfo = e.value['player'] as Map? ?? {};
      final cats =
          (playerInfo['categories'] as List?)?.whereType<String>() ?? [];
      final teams =
          (playerInfo['teamNames'] as List?)?.whereType<String>() ?? [];
      allCategories.addAll(cats);
      allTeamNames.addAll(teams);
    }

    // Filter players based on search + active filters
    var filtered = players;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        final snap = e.value['snapshot'] as Map? ?? {};
        final first = (snap['firstName'] as String? ?? '').toLowerCase();
        final last = (snap['lastName'] as String? ?? '').toLowerCase();
        return first.contains(q) || last.contains(q);
      }).toList();
    }
    if (_filterCategory != null) {
      filtered = filtered.where((e) {
        final info = e.value['player'] as Map? ?? {};
        final cats =
            (info['categories'] as List?)?.whereType<String>() ?? const [];
        return cats.contains(_filterCategory);
      }).toList();
    }
    if (_filterTeamName != null) {
      filtered = filtered.where((e) {
        final info = e.value['player'] as Map? ?? {};
        final teams =
            (info['teamNames'] as List?)?.whereType<String>() ?? const [];
        return teams.contains(_filterTeamName);
      }).toList();
    }

    // Sort by first name
    filtered.sort((a, b) {
      final snapA = a.value['snapshot'] as Map? ?? {};
      final snapB = b.value['snapshot'] as Map? ?? {};
      final fA = (snapA['firstName'] as String? ?? '').toLowerCase();
      final fB = (snapB['firstName'] as String? ?? '').toLowerCase();
      return fA.compareTo(fB);
    });

    final hasActiveFilter =
        _searchQuery.isNotEmpty ||
        _filterCategory != null ||
        _filterTeamName != null;
    final allFilteredSelected =
        filtered.isNotEmpty &&
        filtered.every((e) => widget.selectedPlayerIds.contains(e.key));
    final anyFilteredSelected =
        filtered.any((e) => widget.selectedPlayerIds.contains(e.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Participants',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const Spacer(),
            Text(
              '${widget.selectedPlayerIds.length} sélectionné(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Rechercher un joueur...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ViroColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ViroColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ViroColors.primary),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),

        // Category / Team filters
        if (allCategories.isNotEmpty || allTeamNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (allCategories.isNotEmpty) ...[
                  Text(
                    'Catégorie :',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 6),
                  ...allCategories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _filterCategory == cat,
                        onSelected: (v) => setState(() {
                          _filterCategory = v ? cat : null;
                          _filterTeamName = null; // exclusif
                        }),
                        selectedColor:
                            ViroColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: ViroColors.primary,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
                if (allTeamNames.isNotEmpty) ...[
                  if (allCategories.isNotEmpty) const SizedBox(width: 10),
                  Text(
                    'Équipe :',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 6),
                  ...allTeamNames.map(
                    (tName) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          tName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _filterTeamName == tName,
                        onSelected: (v) => setState(() {
                          _filterTeamName = v ? tName : null;
                          _filterCategory = null; // exclusif
                        }),
                        selectedColor:
                            ViroColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: ViroColors.primary,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Bulk select/deselect row
        if (filtered.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: allFilteredSelected
                    ? null
                    : () {
                        final updated =
                            List<String>.from(widget.selectedPlayerIds);
                        for (final e in filtered) {
                          if (!updated.contains(e.key)) updated.add(e.key);
                        }
                        widget.onPlayersChanged(updated);
                      },
                icon: const Icon(Icons.select_all, size: 16),
                label: Text(
                  hasActiveFilter
                      ? 'Sélectionner le filtre'
                      : 'Tout sélectionner',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: ViroColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (anyFilteredSelected) ...[
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    final keys = filtered.map((e) => e.key).toSet();
                    final updated = widget.selectedPlayerIds
                        .where((id) => !keys.contains(id))
                        .toList();
                    widget.onPlayersChanged(updated);
                  },
                  icon: const Icon(Icons.deselect, size: 16),
                  label: Text(
                    hasActiveFilter
                        ? 'Désélectionner le filtre'
                        : 'Tout désélectionner',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],

        const SizedBox(height: 6),

        // Players list — max 3 lignes visibles, scrollable au-delà
        Container(
          constraints: const BoxConstraints(maxHeight: 3 * 52),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ViroColors.borderColor),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    hasActiveFilter
                        ? 'Aucun joueur trouvé pour ce filtre.'
                        : 'Aucun joueur dans ce club.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    child: Column(
                      children: filtered.map((e) {
                        final uid = e.key;
                        final data = e.value;
                        final snap = data['snapshot'] as Map? ?? {};
                        final selected =
                            widget.selectedPlayerIds.contains(uid);
                        return ListTile(
                          dense: true,
                          title: UserDisplayTile(
                            userId: uid,
                            firstName: snap['firstName'] as String?,
                            lastName: snap['lastName'] as String?,
                            avatarUrl: snap['avatarUrl'] as String?,
                            navigateOnTap: false,
                          ),
                          trailing: Checkbox(
                            value: selected,
                            activeColor: ViroColors.primary,
                            onChanged: (_) => _togglePlayer(uid),
                          ),
                          onTap: () => _togglePlayer(uid),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 8),

        // Add guest player
        OutlinedButton.icon(
          onPressed: _showAddGuestDialog,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Ajouter un joueur hors club'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ViroColors.primary,
            side: const BorderSide(color: ViroColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPlayersList(
    Map<String, Map<String, dynamic>> memberData,
  ) {
    if (widget.selectedPlayerIds.isEmpty) return const SizedBox.shrink();

    // Sort by first name alphabetically
    final sortedIds = List<String>.from(widget.selectedPlayerIds)
      ..sort((a, b) {
        final fA = _getFirstName(a, memberData).toLowerCase();
        final fB = _getFirstName(b, memberData).toLowerCase();
        return fA.compareTo(fB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants sélectionnés (${sortedIds.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sortedIds.map((uid) {
            final name = _getDisplayName(uid, memberData);
            final isGuest = uid.startsWith('guest_');
            return Chip(
              label: Text(
                name,
                style: const TextStyle(fontSize: 12),
              ),
              avatar: isGuest
                  ? const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.orange,
                    )
                  : null,
              backgroundColor: isGuest
                  ? Colors.orange.withValues(alpha: 0.1)
                  : ViroColors.primary.withValues(alpha: 0.08),
              side: BorderSide(
                color: isGuest
                    ? Colors.orange.withValues(alpha: 0.4)
                    : ViroColors.primary.withValues(alpha: 0.2),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                final updated = List<String>.from(widget.selectedPlayerIds)
                  ..remove(uid);
                widget.onPlayersChanged(updated);
                if (isGuest) {
                  final guests =
                      Map<String, Map<String, String>>.from(
                        widget.guestPlayers,
                      )..remove(uid);
                  widget.onGuestPlayersChanged(guests);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAddGuestDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Joueur hors club'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final guestId =
                  'guest_${DateTime.now().millisecondsSinceEpoch}';
              final guests = Map<String, Map<String, String>>.from(
                widget.guestPlayers,
              )..[guestId] = {
                'firstName': firstNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
              };
              widget.onGuestPlayersChanged(guests);
              widget.onPlayersChanged(
                List<String>.from(widget.selectedPlayerIds)..add(guestId),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Aléatoire 🌶️'),
          icon: Icon(Icons.shuffle),
        ),
        ButtonSegment(
          value: true,
          label: Text('Manuel'),
          icon: Icon(Icons.drag_handle),
        ),
      ],
      selected: {widget.isManualDraft},
      onSelectionChanged: (s) => widget.onManualDraftChanged(s.first),
    );
  }

  Widget _buildRandomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Équilibré',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Expanded(
              child: Slider(
                value: widget.driftFactor,
                min: 0,
                max: 1,
                divisions: 10,
                activeColor: ViroColors.primary,
                onChanged: widget.onDriftFactorChanged,
              ),
            ),
            const Text(
              'Aléatoire 🌶️',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generateTeams,
            icon: const Icon(Icons.shuffle),
            label: const Text('Générer les équipes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ViroColors.primary,
              side: const BorderSide(color: ViroColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(
    TournamentTeam team,
    Map<String, Map<String, dynamic>> memberData,
  ) {
    Color teamColor;
    try {
      final hex = team.colorHex.replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = ViroColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  team.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: teamColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${team.playerIds.length} joueur(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Players
          if (widget.isManualDraft)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                final ids = List<String>.from(team.playerIds);
                if (newIndex > oldIndex) newIndex--;
                final item = ids.removeAt(oldIndex);
                ids.insert(newIndex, item);
                final updated = widget.teams.map((t) {
                  if (t.id == team.id) return t.copyWith(playerIds: ids);
                  return t;
                }).toList();
                widget.onTeamsChanged(updated);
              },
              children: team.playerIds.map((uid) {
                final isPending =
                    _pendingSwapPlayerId == uid &&
                    _pendingSwapTeamId == team.id;
                return _buildPlayerTile(
                  key: ValueKey(uid),
                  uid: uid,
                  team: team,
                  memberData: memberData,
                  isPending: isPending,
                );
              }).toList(),
            )
          else
            ...team.playerIds.map((uid) {
              final isPending =
                  _pendingSwapPlayerId == uid && _pendingSwapTeamId == team.id;
              return _buildPlayerTile(
                key: ValueKey(uid),
                uid: uid,
                team: team,
                memberData: memberData,
                isPending: isPending,
              );
            }),

          // Add player button
          TextButton.icon(
            onPressed: () => _showAddPlayerSheet(team, memberData),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Ajouter un joueur'),
            style: TextButton.styleFrom(
              foregroundColor: ViroColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile({
    required Key key,
    required String uid,
    required TournamentTeam team,
    required Map<String, Map<String, dynamic>> memberData,
    required bool isPending,
  }) {
    final isGuest = uid.startsWith('guest_');

    if (isGuest) {
      final g = widget.guestPlayers[uid];
      final name =
          g != null
          ? '${g['firstName'] ?? ''} ${g['lastName'] ?? ''}'.trim()
          : 'Invité';
      return ListTile(
        key: key,
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: const Icon(
            Icons.person_outline,
            size: 16,
            color: Colors.orange,
          ),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14)),
        subtitle: const Text(
          'Hors club',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        ),
        tileColor: isPending
            ? ViroColors.secondary.withValues(alpha: 0.5)
            : null,
        onTap: () => _onPlayerTap(uid, team.id),
        trailing: isPending
            ? const Icon(Icons.swap_horiz, color: ViroColors.primary, size: 18)
            : null,
      );
    }

    final d = memberData[uid] ?? {};
    final snap = d['snapshot'] as Map? ?? {};
    return ListTile(
      key: key,
      dense: true,
      title: UserDisplayTile(
        userId: uid,
        firstName: snap['firstName'] as String?,
        lastName: snap['lastName'] as String?,
        avatarUrl: snap['avatarUrl'] as String?,
        navigateOnTap: false,
      ),
      tileColor: isPending
          ? ViroColors.secondary.withValues(alpha: 0.5)
          : null,
      onTap: () => _onPlayerTap(uid, team.id),
      trailing: isPending
          ? const Icon(Icons.swap_horiz, color: ViroColors.primary, size: 18)
          : null,
    );
  }

  void _showAddPlayerSheet(
    TournamentTeam team,
    Map<String, Map<String, dynamic>> memberData,
  ) {
    final assignedIds = widget.teams.expand((t) => t.playerIds).toSet();
    final available = memberData.entries
        .where(
          (e) =>
              !assignedIds.contains(e.key) &&
              ((e.value['roles'] as List?)?.contains('player') ?? false),
        )
        .toList()
      ..sort((a, b) {
        final snapA = a.value['snapshot'] as Map? ?? {};
        final snapB = b.value['snapshot'] as Map? ?? {};
        final fA = (snapA['firstName'] as String? ?? '').toLowerCase();
        final fB = (snapB['firstName'] as String? ?? '').toLowerCase();
        return fA.compareTo(fB);
      });

    // Guest players not yet assigned
    final availableGuests = widget.guestPlayers.entries
        .where((e) => !assignedIds.contains(e.key))
        .toList()
      ..sort((a, b) {
        final fA = (a.value['firstName'] ?? '').toLowerCase();
        final fB = (b.value['firstName'] ?? '').toLowerCase();
        return fA.compareTo(fB);
      });

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ajouter un joueur',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (available.isEmpty && availableGuests.isEmpty)
            const Text(
              'Aucun joueur disponible.',
              style: TextStyle(color: Colors.grey),
            )
          else ...[
            ...available.map((e) {
              final uid = e.key;
              final snap = e.value['snapshot'] as Map? ?? {};
              return ListTile(
                title: UserDisplayTile(
                  userId: uid,
                  firstName: snap['firstName'] as String?,
                  lastName: snap['lastName'] as String?,
                  avatarUrl: snap['avatarUrl'] as String?,
                  navigateOnTap: false,
                ),
                onTap: () {
                  final updated = widget.teams.map((t) {
                    if (t.id == team.id) {
                      return t.copyWith(
                        playerIds: [...t.playerIds, uid],
                      );
                    }
                    return t;
                  }).toList();
                  widget.onTeamsChanged(updated);
                  if (!widget.selectedPlayerIds.contains(uid)) {
                    widget.onPlayersChanged(
                      List<String>.from(widget.selectedPlayerIds)..add(uid),
                    );
                  }
                  Navigator.pop(context);
                },
              );
            }),
            ...availableGuests.map((e) {
              final uid = e.key;
              final name =
                  '${e.value['firstName'] ?? ''} ${e.value['lastName'] ?? ''}'
                      .trim();
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                title: Text(name),
                subtitle: const Text(
                  'Hors club',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
                onTap: () {
                  final updated = widget.teams.map((t) {
                    if (t.id == team.id) {
                      return t.copyWith(
                        playerIds: [...t.playerIds, uid],
                      );
                    }
                    return t;
                  }).toList();
                  widget.onTeamsChanged(updated);
                  if (!widget.selectedPlayerIds.contains(uid)) {
                    widget.onPlayersChanged(
                      List<String>.from(widget.selectedPlayerIds)..add(uid),
                    );
                  }
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}
