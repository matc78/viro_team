import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/user_display_tile.dart';
import '../profil_display_page.dart';

class AdminMembersPage extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? currentViewerRole;

  const AdminMembersPage({
    super.key,
    required this.clubId,
    required this.clubName,
    this.currentViewerRole,
  });

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  String _search = "";
  String? _selectedCategory;
  String? _selectedTeam;
  bool _editMode = false;
  bool _isRemoving = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFilters =
        _selectedCategory != null ||
        _selectedTeam != null ||
        _search.isNotEmpty;
    final bool canEdit = widget.currentViewerRole == 'admin' ||
        widget.currentViewerRole == 'admin_fondateur';

    return Scaffold(
      appBar: AppBar(
        title: Text("Membres • ${widget.clubName}"),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(
                _editMode ? Icons.edit_off : Icons.edit,
                color: _editMode ? ViroColors.primary : null,
              ),
              tooltip: _editMode ? "Quitter le mode édition" : "Mode édition",
              onPressed: _isRemoving ? null : () => setState(() => _editMode = !_editMode),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Rechercher par nom ou email",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      setState(() => _search = val.trim().toLowerCase()),
                ),
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('teams')
                    .snapshots(),
                builder: (context, snapshot) {
                  final categories = <String>{};
                  final teams = <String>{};
                  if (snapshot.hasData) {
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data();
                      final cat = data['category'] as String?;
                      final team = data['name'] as String?;
                      if (cat != null && cat.isNotEmpty) categories.add(cat);
                      if (team != null && team.isNotEmpty) teams.add(team);
                    }
                  }
                  final catList = categories.toList()..sort();
                  final teamList = teams.toList()..sort();
                  if (_selectedCategory != null &&
                      !catList.contains(_selectedCategory)) {
                    _selectedCategory = null;
                  }
                  if (_selectedTeam != null &&
                      !teamList.contains(_selectedTeam)) {
                    _selectedTeam = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: "Catégorie",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            hint: const Text("Catégorie"),
                            items:
                                catList
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList()
                                  ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text("Catégorie"),
                                    ),
                                  ),
                            onChanged: (val) =>
                                setState(() => _selectedCategory = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedTeam,
                            decoration: const InputDecoration(
                              labelText: "Équipe",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            hint: const Text("Équipe"),
                            items:
                                teamList
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList()
                                  ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text("Équipe"),
                                    ),
                                  ),
                            onChanged: (val) =>
                                setState(() => _selectedTeam = val),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // Récupérer tous les utilisateurs et filtrer côté client
                  // car la nouvelle structure utilise roles/activeContext
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Erreur de chargement des membres."),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    // Filtrer les utilisateurs qui appartiennent au club
                    final clubMembers = filterUsersByClub(
                      allDocs,
                      widget.clubId,
                    );

                    // Créer une liste d'entrées avec doc et role pour gérer les utilisateurs multi-rôles
                    final entries = <Map<String, dynamic>>[];

                    for (final doc in clubMembers) {
                      final data = doc.data();
                      if (data == null) continue;

                      // Obtenir tous les rôles de cet utilisateur dans ce club
                      final roles = getAllUserRolesInClub(data, widget.clubId);

                      // Si l'utilisateur est joueur ET admin/coach, créer deux entrées
                      // Sinon, créer une entrée par rôle
                      for (final role in roles) {
                        entries.add({'doc': doc, 'role': role});
                      }
                    }

                    // Filtrer les entrées selon les critères de recherche
                    final filtered =
                        entries.where((entry) {
                          final doc = entry['doc'] as DocumentSnapshot;
                          final role = entry['role'] as String;
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return false;

                          final first = (data['firstName'] as String? ?? "")
                              .toLowerCase();
                          final last = (data['lastName'] as String? ?? "")
                              .toLowerCase();
                          final email = (data['email'] as String? ?? "")
                              .toLowerCase();
                          final userCat = data['category'] as String? ?? "";
                          final userCats =
                              (data['categories'] as List?)
                                  ?.whereType<String>()
                                  .toList() ??
                              [];
                          final userTeams =
                              (data['teamNames'] as List?)
                                  ?.whereType<String>()
                                  .toList() ??
                              [];
                          final userTeam = data['teamName'] as String?;

                          // Pour les filtres de catégorie et équipe, on ne filtre que les joueurs
                          // Les admins/coachs ne sont pas filtrés par catégorie/équipe
                          final isPlayer = role == 'player';
                          final catOk =
                              !isPlayer ||
                              _selectedCategory == null ||
                              _normalize(userCat) ==
                                  _normalize(_selectedCategory!) ||
                              userCats.any(
                                (c) =>
                                    _normalize(c) ==
                                    _normalize(_selectedCategory!),
                              );
                          final teamOk =
                              !isPlayer ||
                              _selectedTeam == null ||
                              _normalize(userTeam ?? "") ==
                                  _normalize(_selectedTeam!) ||
                              userTeams.any(
                                (t) =>
                                    _normalize(t) == _normalize(_selectedTeam!),
                              );

                          final matchesSearch =
                              _search.isEmpty ||
                              first.contains(_search) ||
                              last.contains(_search) ||
                              email.contains(_search);
                          return matchesSearch && catOk && teamOk;
                        }).toList()..sort((a, b) {
                          final aDoc = a['doc'] as DocumentSnapshot;
                          final bDoc = b['doc'] as DocumentSnapshot;
                          final aRole = a['role'] as String;
                          final bRole = b['role'] as String;
                          final aData = aDoc.data() as Map<String, dynamic>?;
                          final bData = bDoc.data() as Map<String, dynamic>?;

                          // Déterminer si ce sont des staff (admin/coach) ou des players (licenciés)
                          final aIsStaff =
                              aRole == 'admin_fondateur' ||
                              aRole == 'coach' ||
                              aRole == 'admin';
                          final bIsStaff =
                              bRole == 'admin_fondateur' ||
                              bRole == 'coach' ||
                              bRole == 'admin';

                          // D'abord, séparer les staff (en haut) des players (en bas)
                          if (aIsStaff && !bIsStaff) {
                            return -1; // a est staff, b est player -> a en premier
                          }
                          if (!aIsStaff && bIsStaff) {
                            return 1; // a est player, b est staff -> b en premier
                          }

                          // Si même type (tous les deux staff ou tous les deux players), trier par prénom
                          final aFirst = (aData?['firstName'] as String? ?? "")
                              .toLowerCase();
                          final bFirst = (bData?['firstName'] as String? ?? "")
                              .toLowerCase();
                          return aFirst.compareTo(bFirst);
                        });

                    if (filtered.isEmpty) {
                      return const Center(child: Text("Aucun membre trouvé."));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 140),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) {
                        // Afficher un séparateur uniquement à la transition entre staff et players
                        if (index < filtered.length - 1) {
                          final currentEntry = filtered[index];
                          final nextEntry = filtered[index + 1];
                          final currentRole = currentEntry['role'] as String;
                          final nextRole = nextEntry['role'] as String;

                          final currentIsStaff =
                              currentRole == 'admin_fondateur' ||
                              currentRole == 'coach' ||
                              currentRole == 'admin';
                          final nextIsPlayer = nextRole == 'player';

                          // Si l'élément actuel est staff et le suivant est player, afficher le séparateur
                          if (currentIsStaff && nextIsPlayer) {
                            return const Divider(
                              height: 1,
                              color: Colors.black,
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final doc = entry['doc'] as DocumentSnapshot;
                        final role = entry['role'] as String;
                        final rawData = doc.data();
                        final data = rawData as Map<String, dynamic>?;
                        if (data == null) return const SizedBox.shrink();

                        final userId = doc.id;
                        final firstName = data['firstName'] as String? ?? "";
                        final lastName = data['lastName'] as String? ?? "";
                        final avatarUrl = data['avatarUrl'] as String?;

                        // Pour les joueurs, afficher la catégorie
                        // Pour les admins/coachs, ne pas afficher de catégorie
                        final isPlayer = role == 'player';
                        final categories =
                            (data['categories'] as List?)
                                ?.whereType<String>()
                                .toList() ??
                            [];
                        final category = isPlayer
                            ? (categories.isNotEmpty
                                  ? categories.join(", ")
                                  : (data['category'] as String? ?? ""))
                            : "";

                        // Déterminer le label du rôle à afficher
                        final isStaff =
                            role == 'admin_fondateur' ||
                            role == 'coach' ||
                            role == 'admin';
                        final roleLabel = role
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((word) {
                              if (word.isEmpty) return word;
                              return word[0].toUpperCase() + word.substring(1);
                            })
                            .join(' ');

                        final bool showDelete = canEdit &&
                            _editMode &&
                            role != 'admin_fondateur' &&
                            (widget.currentViewerRole == 'admin_fondateur' ||
                                (widget.currentViewerRole == 'admin' &&
                                    (role == 'player' || role == 'coach')));
                        final bool showPasserAdmin = canEdit &&
                            _editMode &&
                            widget.currentViewerRole == 'admin_fondateur' &&
                            role == 'coach';
                        final bool showPasserCoach = canEdit &&
                            _editMode &&
                            widget.currentViewerRole == 'admin_fondateur' &&
                            role == 'admin';

                        return ListTile(
                          leading: null,
                          title: UserDisplayTile(
                            userId: userId,
                            firstName: firstName,
                            lastName: lastName,
                            avatarUrl: avatarUrl,
                            navigateOnTap: false,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: isPlayer
                              ? Text(
                                  category.isNotEmpty
                                      ? category
                                      : "Sans catégorie",
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : null,
                          trailing: _editMode && (showDelete || showPasserAdmin || showPasserCoach)
                              ? _buildEditTrailing(
                                  roleLabel: roleLabel,
                                  isPlayer: isPlayer,
                                  data: data,
                                  showDelete: showDelete,
                                  showPasserAdmin: showPasserAdmin,
                                  showPasserCoach: showPasserCoach,
                                  userId: userId,
                                  role: role,
                                  firstName: firstName,
                                  lastName: lastName,
                                )
                              : (isStaff
                                  ? Text(
                                      roleLabel,
                                      style: const TextStyle(color: Colors.grey),
                                    )
                                  : Text(
                                      playerHasLicense(data, widget.clubId)
                                          ? "Licencié"
                                          : "Non Licencié",
                                      style: const TextStyle(color: Colors.grey),
                                    )),
                          onTap: () {
                            if (!_editMode) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfilDisplayPage(userId: userId),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: hasFilters
                    ? SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black87,
                                side: const BorderSide(
                                  color: ViroColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => setState(() {
                                _selectedCategory = null;
                                _selectedTeam = null;
                                _search = "";
                                _searchController.clear();
                              }),
                              child: const Text("Enlever les filtres"),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // Logo en footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      'assets/logo/logo_long.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTrailing({
    required String roleLabel,
    required bool isPlayer,
    required Map<String, dynamic> data,
    required bool showDelete,
    required bool showPasserAdmin,
    required bool showPasserCoach,
    required String userId,
    required String role,
    required String firstName,
    required String lastName,
  }) {
    final List<PopupMenuEntry<String>> items = [];
    if (showDelete) {
      items.add(
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red, size: 22),
              SizedBox(width: 12),
              Text("Retirer du club"),
            ],
          ),
        ),
      );
    }
    if (showPasserAdmin) {
      items.add(
        const PopupMenuItem<String>(
          value: 'to_admin',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 22),
              SizedBox(width: 12),
              Text("Passer en administrateur"),
            ],
          ),
        ),
      );
    }
    if (showPasserCoach) {
      items.add(
        const PopupMenuItem<String>(
          value: 'to_coach',
          child: Row(
            children: [
              Icon(Icons.sports, size: 22),
              SizedBox(width: 12),
              Text("Passer en coach"),
            ],
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPlayer
              ? (playerHasLicense(data, widget.clubId) ? "Licencié" : "Non Licencié")
              : roleLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          enabled: !_isRemoving,
          onSelected: (value) async {
            if (value == 'remove') {
              await _confirmAndRemove(userId, role, data, firstName, lastName);
            } else if (value == 'to_admin') {
              await _confirmAndChangeRole(userId, data, toAdmin: true);
            } else if (value == 'to_coach') {
              await _confirmAndChangeRole(userId, data, toAdmin: false);
            }
          },
          itemBuilder: (_) => items,
        ),
      ],
    );
  }

  Future<void> _confirmAndRemove(
    String userId,
    String role,
    Map<String, dynamic> data,
    String firstName,
    String lastName,
  ) async {
    final name = '$firstName $lastName'.trim();
    final roleLabel = role == 'player'
        ? 'membre'
        : (role == 'coach' ? 'coach' : 'administrateur');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Retirer du club"),
        content: Text(
          "Retirer $name du club en tant que $roleLabel ? Cette action peut être annulée en réintégrant la personne.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Retirer"),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _removeFromClub(userId, role, data, firstName, lastName);
    }
  }

  Future<void> _confirmAndChangeRole(
    String userId,
    Map<String, dynamic> data, {
    required bool toAdmin,
  }) async {
    final label = toAdmin ? "administrateur" : "coach";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Changer le rôle"),
        content: Text("Passer cette personne en $label ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _changeRole(userId, data, toAdmin: toAdmin);
    }
  }

  Future<bool> _checkRemovalQuota() async {
    // L'admin fondateur n'est pas limité : il peut retirer autant de personnes qu'il veut par jour
    if (widget.currentViewerRole == 'admin_fondateur') return true;
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return false;
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final startOfDayMs = startOfDay.millisecondsSinceEpoch;
    // Une seule clause where pour éviter l'index composite ; filtre par date côté client
    final snap = await FirebaseFirestore.instance
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.memberRemovals)
        .where('adminId', isEqualTo: adminId)
        .get();
    final hasRemovalToday = snap.docs.any((doc) {
      final removedAt = doc.data()['removedAt'];
      if (removedAt == null) return false;
      final ts = removedAt is Timestamp ? removedAt : null;
      return ts != null && ts.millisecondsSinceEpoch >= startOfDayMs;
    });
    return !hasRemovalToday;
  }

  Future<void> _recordRemoval(String adminId, String removedUserId, String role) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.memberRemovals)
          .add({
        'adminId': adminId,
        'removedUserId': removedUserId,
        'role': role,
        'removedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.instance.error(
        'Erreur enregistrement retrait (quota)',
        error: e,
        context: {'clubId': widget.clubId, 'removedUserId': removedUserId},
      );
    }
  }

  Future<void> _removeFromClub(
    String userId,
    String role,
    Map<String, dynamic> data,
    String firstName,
    String lastName,
  ) async {
    if (role == 'admin_fondateur') return;
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    if (role == 'player' || role == 'coach') {
      final canRemove = await _checkRemovalQuota();
      if (!canRemove && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous ne pouvez retirer qu'un seul membre ou coach par jour. Réessayez demain.",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isRemoving = true);
    try {
      final firestore = FirebaseFirestore.instance;

      if (role == 'player') {
        await _removePlayerFromClub(firestore, userId, data);
        await _recordRemoval(adminId, userId, 'player');
      } else if (role == 'coach') {
        await _removeCoachFromClub(firestore, userId, data);
        await _recordRemoval(adminId, userId, 'coach');
      } else if (role == 'admin') {
        await _removeAdminFromClub(firestore, userId, data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Personne retirée du club.")),
        );
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur retrait du club',
        error: e,
        context: {'clubId': widget.clubId, 'userId': userId, 'role': role},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de retirer : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  Future<void> _removePlayerFromClub(
    FirebaseFirestore firestore,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final clubId = widget.clubId;
    // 1. Events
    final eventsSnap = await firestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.events)
        .get();
    for (final doc in eventsSnap.docs) {
      final eventData = doc.data();
      final memberIds =
          (eventData['teamMemberIds'] as List<dynamic>?)?.whereType<String>();
      if (memberIds != null && memberIds.contains(uid)) {
        await doc.reference.update({
          'teamMemberIds': FieldValue.arrayRemove([uid]),
          'attendance.$uid': FieldValue.delete(),
        });
      }
    }
    // 2. Teams
    final teamsSnap = await firestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .get();
    for (final doc in teamsSnap.docs) {
      final teamData = doc.data();
      final playerIds =
          (teamData['playerIds'] as List<dynamic>?)?.whereType<String>();
      if (playerIds != null && playerIds.contains(uid)) {
        await doc.reference.update({
          'playerIds': FieldValue.arrayRemove([uid]),
        });
      }
    }
    // 3. Club members : retirer seulement si pas d'autre rôle (coach, admin) dans ce club
    final roles = data['roles'] as Map<String, dynamic>? ?? {};
    bool hasOtherRoleInClub = false;
    if (roles['coach'] is List) {
      for (var c in (roles['coach'] as List)) {
        if (c is Map && c['clubId'] == clubId) {
          hasOtherRoleInClub = true;
          break;
        }
      }
    }
    if (!hasOtherRoleInClub &&
        (roles['admin'] is List) &&
        (roles['admin'] as List).contains(clubId)) {
      hasOtherRoleInClub = true;
    }
    if (!hasOtherRoleInClub) {
      await firestore.collection(FirebaseCollections.clubs).doc(clubId).update({
        'members': FieldValue.arrayRemove([uid]),
      });
      try {
        await firestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.memberLeaves)
            .add({
          'userId': uid,
          'firstName': (data['firstName'] as String?)?.trim() ?? '',
          'lastName': (data['lastName'] as String?)?.trim() ?? '',
          'role': 'player',
          'leftAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        AppLogger.instance.error(
          'Erreur member_leaves',
          error: e,
          context: {'clubId': clubId, 'userId': uid},
        );
      }
    }
    // 4. User roles + activeContext
    final rolesData = Map<String, dynamic>.from(roles);
    final playerData = rolesData['player'] as Map?;
    List<dynamic> newPlayerClubs = [];
    if (playerData != null && playerData['clubs'] is List) {
      final clubs = (playerData['clubs'] as List).whereType<Map>().toList();
      newPlayerClubs =
          clubs.where((c) => (c['clubId'] as String?) != clubId).toList();
    }
    if (newPlayerClubs.isEmpty) {
      rolesData.remove('player');
    } else {
      rolesData['player'] = {'clubs': newPlayerClubs};
    }
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId && activeRole == 'player') {
      if (newPlayerClubs.isEmpty) {
        newActiveContext = null;
      } else {
        final first = newPlayerClubs.first as Map<String, dynamic>;
        newActiveContext = {
          'role': 'player',
          'clubId': first['clubId'],
        };
      }
    }
    final updates = <String, dynamic>{};
    updates['roles'] = rolesData;
    if (newPlayerClubs.isEmpty) {
      updates['roles.player'] = FieldValue.delete();
    }
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
      updates['clubId'] = FieldValue.delete();
      updates['clubName'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
      if (activeClubId == clubId) {
        final newClubId = newActiveContext['clubId'] as String?;
        updates['clubId'] = newClubId;
        if (newClubId != null) {
          final clubDoc = await firestore
              .collection(FirebaseCollections.clubs)
              .doc(newClubId)
              .get();
          updates['clubName'] = clubDoc.data()?['name'] ?? '';
        } else {
          updates['clubName'] = FieldValue.delete();
        }
      }
    }
    await firestore.collection(FirebaseCollections.users).doc(uid).update(updates);
  }

  Future<void> _removeCoachFromClub(
    FirebaseFirestore firestore,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final clubId = widget.clubId;
    await firestore.collection(FirebaseCollections.clubs).doc(clubId).update({
      'coaches': FieldValue.arrayRemove([uid]),
    });
    final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
    final coachList = (roles['coach'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final newCoachList = coachList.where((c) => c['clubId'] != clubId).toList();
    if (newCoachList.isEmpty) {
      roles.remove('coach');
    } else {
      roles['coach'] = newCoachList;
    }
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId && activeRole == 'coach') {
      if (newCoachList.isEmpty) {
        newActiveContext = null;
      } else {
        final first = newCoachList.first;
        newActiveContext = {'role': 'coach', 'clubId': first['clubId']};
      }
    }
    final updates = <String, dynamic>{'roles': roles};
    if (newCoachList.isEmpty) {
      updates['roles.coach'] = FieldValue.delete();
    }
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
      updates['clubId'] = FieldValue.delete();
      updates['clubName'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
      if (activeClubId == clubId) {
        final newClubId = newActiveContext['clubId'] as String?;
        updates['clubId'] = newClubId;
        if (newClubId != null) {
          final clubDoc = await firestore
              .collection(FirebaseCollections.clubs)
              .doc(newClubId)
              .get();
          updates['clubName'] = clubDoc.data()?['name'] ?? '';
        } else {
          updates['clubName'] = FieldValue.delete();
        }
      }
    }
    await firestore.collection(FirebaseCollections.users).doc(uid).update(updates);
  }

  Future<void> _removeAdminFromClub(
    FirebaseFirestore firestore,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final clubId = widget.clubId;
    await firestore.collection(FirebaseCollections.clubs).doc(clubId).update({
      'coaches': FieldValue.arrayRemove([uid]),
    });
    final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
    final adminList = (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
    final newAdminList = adminList.where((id) => id != clubId).toList();
    if (newAdminList.isEmpty) {
      roles.remove('admin');
    } else {
      roles['admin'] = newAdminList;
    }
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId && (activeRole == 'admin' || activeRole == 'admin_fondateur')) {
      if (newAdminList.isEmpty) {
        newActiveContext = null;
      } else {
        newActiveContext = {'role': 'admin', 'clubId': newAdminList.first};
      }
    }
    final updates = <String, dynamic>{'roles': roles};
    if (newAdminList.isEmpty) {
      updates['roles.admin'] = FieldValue.delete();
    }
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
      updates['clubId'] = FieldValue.delete();
      updates['clubName'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
      if (activeClubId == clubId) {
        final newClubId = newActiveContext['clubId'] as String?;
        updates['clubId'] = newClubId;
        if (newClubId != null) {
          final clubDoc = await firestore
              .collection(FirebaseCollections.clubs)
              .doc(newClubId)
              .get();
          updates['clubName'] = clubDoc.data()?['name'] ?? '';
        } else {
          updates['clubName'] = FieldValue.delete();
        }
      }
    }
    await firestore.collection(FirebaseCollections.users).doc(uid).update(updates);
  }

  Future<void> _changeRole(String userId, Map<String, dynamic> data, {required bool toAdmin}) async {
    setState(() => _isRemoving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final clubId = widget.clubId;
      final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});

      if (toAdmin) {
        // Coach -> Admin : retirer de roles.coach, ajouter à roles.admin
        final coachList = (roles['coach'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final newCoachList = coachList.where((c) => c['clubId'] != clubId).toList();
        if (newCoachList.isEmpty) {
          roles.remove('coach');
        } else {
          roles['coach'] = newCoachList;
        }
        final adminList = (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
        if (!adminList.contains(clubId)) {
          adminList.add(clubId);
          roles['admin'] = adminList;
        }
      } else {
        // Admin -> Coach : retirer de roles.admin, ajouter à roles.coach
        final adminList = (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
        final newAdminList = adminList.where((id) => id != clubId).toList();
        if (newAdminList.isEmpty) {
          roles.remove('admin');
        } else {
          roles['admin'] = newAdminList;
        }
        final coachList = (roles['coach'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        if (!coachList.any((c) => c['clubId'] == clubId)) {
          coachList.add({'clubId': clubId, 'teams': []});
          roles['coach'] = coachList;
        }
      }

      final activeContext = data['activeContext'] as Map<String, dynamic>?;
      final activeClubId = activeContext?['clubId'] as String?;
      Map<String, dynamic>? newActiveContext;
      if (activeClubId == clubId) {
        newActiveContext = {
          'role': toAdmin ? 'admin' : 'coach',
          'clubId': clubId,
        };
      }

      final updates = <String, dynamic>{
        'roles': roles,
        if (newActiveContext != null) 'activeContext': newActiveContext,
      };
      await firestore.collection(FirebaseCollections.users).doc(userId).update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toAdmin ? "Personne passée en administrateur." : "Personne passée en coach.",
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur changement de rôle',
        error: e,
        context: {'clubId': widget.clubId, 'userId': userId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de changer le rôle : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  String _normalize(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[ûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .trim();
  }
}
