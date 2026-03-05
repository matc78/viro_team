import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
import '../../widget/user_display_tile.dart';
import '../profil_display_page.dart';

class AdminMembersPage extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? clubSport;
  final String? currentViewerRole;

  const AdminMembersPage({
    super.key,
    required this.clubId,
    required this.clubName,
    this.clubSport,
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
    final bool canEdit =
        widget.currentViewerRole == 'admin' ||
        widget.currentViewerRole == 'admin_fondateur';
    final bool canSendInviteLink =
        canEdit || widget.currentViewerRole == 'coach';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Membres • ${formatClubNameWithEmoji(widget.clubName, widget.clubSport)}",
        ),
        centerTitle: true,
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(
                _editMode ? Icons.edit_off : Icons.edit,
                color: _editMode ? ViroColors.primary : null,
              ),
              tooltip: _editMode ? "Quitter le mode édition" : "Mode édition",
              onPressed: _isRemoving
                  ? null
                  : () => setState(() => _editMode = !_editMode),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appFirestore.collection(FirebaseCollections.users).snapshots(),
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: appFirestore
                      .collection(FirebaseCollections.clubs)
                      .doc(widget.clubId)
                      .collection(FirebaseCollections.teams)
                      .snapshots(),
                  builder: (context, teamsSnapshot) {
                    final categories = <String>{};
                    final allTeamsByCategory = <String, List<String>>{};
                    if (teamsSnapshot.hasData) {
                      for (final doc in teamsSnapshot.data!.docs) {
                        final data = doc.data();
                        final cat = (data['category'] as String?)?.trim() ?? '';
                        final team = (data['name'] as String?)?.trim() ?? '';
                        if (cat.isNotEmpty) categories.add(cat);
                        if (team.isNotEmpty) {
                          allTeamsByCategory
                              .putIfAbsent(cat, () => [])
                              .add(team);
                        }
                      }
                    }
                    final catList = categories.toList()..sort();
                    final List<String> teamList = _selectedCategory != null
                        ? List<String>.from(
                            allTeamsByCategory[_selectedCategory] ?? [],
                          )
                        : allTeamsByCategory.values
                              .expand((l) => l)
                              .toSet()
                              .toList();
                    teamList.sort();
                    if (_selectedCategory != null &&
                        !catList.contains(_selectedCategory)) {
                      _selectedCategory = null;
                    }
                    if (_selectedTeam != null &&
                        !teamList.contains(_selectedTeam)) {
                      _selectedTeam = null;
                    }
                    final hasFilters =
                        _selectedCategory != null ||
                        _selectedTeam != null ||
                        _search.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: ViroColors.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Filtres",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (hasFilters)
                                    IconButton(
                                      onPressed: () => setState(() {
                                        _selectedCategory = null;
                                        _selectedTeam = null;
                                        _search = "";
                                        _searchController.clear();
                                      }),
                                      icon: Icon(
                                        Icons.filter_alt_off,
                                        color: ViroColors.primary,
                                        size: 22,
                                      ),
                                      tooltip: "Effacer les filtres",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: "Rechercher par nom ou email",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (val) => setState(
                                  () => _search = val.trim().toLowerCase(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SizedBox(
                                          width: constraints.maxWidth,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _selectedCategory,
                                            decoration: const InputDecoration(
                                              labelText: "Catégorie",
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                            ),
                                            hint: const Text("Catégorie"),
                                            isExpanded: true,
                                            selectedItemBuilder: (context) {
                                              return [
                                                const Text("Catégorie"),
                                                ...catList.map(
                                                  (c) => Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              ViroColors.getCategoryColor(
                                                                c,
                                                              ),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            width: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          c,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ];
                                            },
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text("Catégorie"),
                                              ),
                                              ...catList.map(
                                                (c) => DropdownMenuItem<String>(
                                                  value: c,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              ViroColors.getCategoryColor(
                                                                c,
                                                              ),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            width: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(c),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setState(
                                              () => _selectedCategory = val,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SizedBox(
                                          width: constraints.maxWidth,
                                          child:
                                              DropdownButtonFormField<String>(
                                                initialValue: _selectedTeam,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: "Équipe",
                                                      border:
                                                          OutlineInputBorder(),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                    ),
                                                hint: const Text("Équipe"),
                                                items:
                                                    teamList
                                                        .map(
                                                          (t) =>
                                                              DropdownMenuItem<
                                                                String
                                                              >(
                                                                value: t,
                                                                child: Text(t),
                                                              ),
                                                        )
                                                        .toList()
                                                      ..insert(
                                                        0,
                                                        const DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: null,
                                                          child: Text("Équipe"),
                                                        ),
                                                      ),
                                                onChanged: (val) => setState(
                                                  () => _selectedTeam = val,
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildMembersSliver(snapshot),
              if (canEdit)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    child: _buildBottomCardContent(
                      canEdit: canEdit,
                      canSendInviteLink: canSendInviteLink,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
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
          );
        },
      ),
    );
  }

  /// Sliver pour la liste des membres (loading, vide ou liste avec séparateurs).
  Widget _buildMembersSliver(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: const SizedBox(
          height: 200,
          child: Center(child: Text("Erreur de chargement des membres.")),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final allDocs = snapshot.data?.docs ?? [];
    final clubMembers = filterUsersByClub(allDocs, widget.clubId);
    final entries = <Map<String, dynamic>>[];
    for (final doc in clubMembers) {
      final data = doc.data();
      if (data == null) continue;
      final roles = getAllUserRolesInClub(data, widget.clubId);
      for (final role in roles) {
        entries.add({'doc': doc, 'role': role});
      }
    }
    final filtered =
        entries.where((entry) {
          final doc = entry['doc'] as DocumentSnapshot;
          final role = entry['role'] as String;
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final first = (data['firstName'] as String? ?? "").toLowerCase();
          final last = (data['lastName'] as String? ?? "").toLowerCase();
          final email = (data['email'] as String? ?? "").toLowerCase();
          final userCats = getUserCategories(data);
          final userTeams = getUserTeamNames(data);
          final isPlayer = role == 'player';
          final catOk =
              !isPlayer ||
              _selectedCategory == null ||
              userCats.any(
                (c) => _normalize(c) == _normalize(_selectedCategory!),
              );
          final teamOk =
              !isPlayer ||
              _selectedTeam == null ||
              userTeams.any((t) => _normalize(t) == _normalize(_selectedTeam!));
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
          final aIsStaff =
              aRole == 'admin_fondateur' ||
              aRole == 'coach' ||
              aRole == 'admin';
          final bIsStaff =
              bRole == 'admin_fondateur' ||
              bRole == 'coach' ||
              bRole == 'admin';
          if (aIsStaff && !bIsStaff) return -1;
          if (!aIsStaff && bIsStaff) return 1;
          final aFirst = (aData?['firstName'] as String? ?? "").toLowerCase();
          final bFirst = (bData?['firstName'] as String? ?? "").toLowerCase();
          return aFirst.compareTo(bFirst);
        });
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: const SizedBox(
          height: 120,
          child: Center(child: Text("Aucun membre trouvé.")),
        ),
      );
    }
    final bool canEdit =
        widget.currentViewerRole == 'admin' ||
        widget.currentViewerRole == 'admin_fondateur';
    final List<int> slots = [];
    for (int i = 0; i < filtered.length; i++) {
      if (i > 0) {
        final prevRole = filtered[i - 1]['role'] as String;
        final currRole = filtered[i]['role'] as String;
        final prevStaff =
            prevRole == 'admin_fondateur' ||
            prevRole == 'coach' ||
            prevRole == 'admin';
        final currPlayer = currRole == 'player';
        if (prevStaff && currPlayer) slots.add(-1);
      }
      slots.add(i);
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (slots[index] == -1) {
          return const Divider(
            height: 1,
            color: Colors.black,
            indent: 50,
            endIndent: 50,
          );
        }
        final entryIndex = slots[index];
        final entry = filtered[entryIndex];
        final doc = entry['doc'] as DocumentSnapshot;
        final role = entry['role'] as String;
        final rawData = doc.data();
        final data = rawData as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        final userId = doc.id;
        final firstName = data['firstName'] as String? ?? "";
        final lastName = data['lastName'] as String? ?? "";
        final avatarUrl = effectiveAvatarUrl(data);
        final isPlayer = role == 'player';
        final userCategories = getUserCategories(data);
        final isStaff =
            role == 'admin_fondateur' || role == 'coach' || role == 'admin';
        final roleLabel = role
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1);
            })
            .join(' ');
        final bool showDelete =
            canEdit &&
            _editMode &&
            role != 'admin_fondateur' &&
            (widget.currentViewerRole == 'admin_fondateur' ||
                (widget.currentViewerRole == 'admin' &&
                    (role == 'player' || role == 'coach')));
        final bool showPasserAdmin =
            canEdit &&
            _editMode &&
            widget.currentViewerRole == 'admin_fondateur' &&
            role == 'coach';
        final bool showPasserCoach =
            canEdit &&
            _editMode &&
            widget.currentViewerRole == 'admin_fondateur' &&
            role == 'admin';
        final trailing =
            _editMode && (showDelete || showPasserAdmin || showPasserCoach)
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
            : const SizedBox.shrink();
        return _MemberTile(
          userId: userId,
          firstName: firstName,
          lastName: lastName,
          avatarUrl: avatarUrl,
          roleLabel: roleLabel,
          isPlayer: isPlayer,
          isStaff: isStaff,
          categories: userCategories,
          teamNames: getUserTeamNames(data),
          hasLicense: playerHasLicense(data, widget.clubId),
          trailing: trailing,
          onTap: () {
            if (!_editMode) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilDisplayPage(userId: userId),
                ),
              );
            }
          },
        );
      }, childCount: slots.length),
    );
  }

  /// Contenu de la carte "En attente" (sans Positioned, pour le scroll).
  Widget _buildBottomCardContent({
    required bool canEdit,
    required bool canSendInviteLink,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  "En attente de création de compte",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canEdit)
                  IconButton(
                    onPressed: _isRemoving
                        ? null
                        : () => _showAddMemberEmailDialog(context),
                    icon: const Icon(Icons.person_add),
                    color: ViroColors.accent,
                    tooltip: "Ajouter joueur",
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPendingMembersSection(
              canEdit: canEdit,
              canSendInviteLink: canSendInviteLink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingMembersSection({
    required bool canEdit,
    required bool canSendInviteLink,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.pendingMembers)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun membre en attente.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          );
        }

        final list = docs.map((doc) {
          final d = doc.data();
          return {'doc': doc, 'data': d};
        }).toList();

        list.sort((a, b) {
          final aLast = ((a['data'] as Map)['lastName'] as String? ?? '')
              .toLowerCase();
          final bLast = ((b['data'] as Map)['lastName'] as String? ?? '')
              .toLowerCase();
          final cmp = aLast.compareTo(bLast);
          if (cmp != 0) return cmp;
          final aFirst = ((a['data'] as Map)['firstName'] as String? ?? '')
              .toLowerCase();
          final bFirst = ((b['data'] as Map)['firstName'] as String? ?? '')
              .toLowerCase();
          return aFirst.compareTo(bFirst);
        });

        final filtered = _search.isEmpty
            ? list
            : list.where((e) {
                final data = e['data'] as Map<String, dynamic>;
                final first = (data['firstName'] as String? ?? '')
                    .toLowerCase();
                final last = (data['lastName'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return first.contains(_search) ||
                    last.contains(_search) ||
                    email.contains(_search);
              }).toList();

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun membre en attente.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final e = filtered[index];
              final doc = e['doc'] as DocumentSnapshot<Map<String, dynamic>>;
              final data = e['data'] as Map<String, dynamic>;
              final firstName = data['firstName'] as String? ?? '';
              final lastName = data['lastName'] as String? ?? '';
              final email = data['email'] as String? ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '$firstName $lastName'.trim().isEmpty
                      ? email
                      : '$firstName $lastName'.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: (canEdit || canSendInviteLink)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canSendInviteLink)
                            IconButton(
                              onPressed: () => _sendInviteLink(
                                context,
                                doc.id,
                                firstName,
                                lastName,
                                email,
                              ),
                              icon: const Icon(Icons.link),
                              color: ViroColors.primary,
                              tooltip: "Envoyer lien de connexion",
                            ),
                          if (canEdit)
                            IconButton(
                              onPressed: () => _showEditPendingMemberDialog(
                                context,
                                doc.reference,
                                firstName,
                                lastName,
                                email,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              color: ViroColors.accent,
                              tooltip: "Éditer",
                            ),
                          if (canEdit)
                            IconButton(
                              onPressed: () => _confirmRemovePendingMember(
                                context,
                                doc.reference,
                                '$firstName $lastName'.trim(),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: "Supprimer",
                            ),
                        ],
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showEditPendingMemberDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    String currentFirstName,
    String currentLastName,
    String currentEmail,
  ) async {
    final firstNameController = TextEditingController(text: currentFirstName);
    final lastNameController = TextEditingController(text: currentLastName);
    final emailController = TextEditingController(text: currentEmail);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Modifier le membre en attente"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Saisissez le prénom.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: "Nom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Saisissez le nom.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Saisissez un email.";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();
              final email = emailController.text.trim().toLowerCase();
              Navigator.pop(dialogContext);
              await _updatePendingMember(
                context,
                docRef,
                firstName: firstName,
                lastName: lastName,
                email: email,
              );
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
  }

  Future<void> _updatePendingMember(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef, {
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      await docRef.update({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Membre en attente mis à jour.")),
        );
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur mise à jour membre en attente',
        error: e,
        context: {'clubId': widget.clubId},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    }
  }

  /// Génère un token unique et URL-safe pour un lien d'invite (utilisé comme ID de document).
  String _generateInviteToken() {
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(
      bytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  Future<void> _sendInviteLink(
    BuildContext context,
    String pendingMemberId,
    String firstName,
    String lastName,
    String email,
  ) async {
    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email manquant pour ce membre.")),
      );
      return;
    }
    try {
      final clubId = widget.clubId;
      final teamsSnap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.teams)
          .get();
      final List<Map<String, dynamic>> teams = [];
      for (final teamDoc in teamsSnap.docs) {
        final data = teamDoc.data();
        final pendingIds = List<String>.from(data['pendingPlayerIds'] ?? []);
        if (pendingIds.contains(pendingMemberId)) {
          teams.add({
            'teamId': teamDoc.id,
            'teamName': data['name'] as String? ?? '',
            'category': data['category'] as String? ?? '',
          });
        }
      }
      final token = _generateInviteToken();
      final expiresAt = DateTime.now().add(const Duration(days: 7));
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(token)
          .set({
            'token': token,
            'pendingMemberId': pendingMemberId,
            'email': email.trim().toLowerCase(),
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'expiresAt': Timestamp.fromDate(expiresAt),
            'teams': teams,
          });
      final inviteUrl = 'viroteam://invite?t=$token&c=$clubId';
      final toAddress = email.trim().toLowerCase();
      final subject = 'Invitation ViroTeam - Créer votre compte';
      final bodyLong =
          'Bonjour $firstName,\n\n'
          'Votre club vous invite à rejoindre ViroTeam. Téléchargez l\'application puis ouvrez ce lien pour créer votre compte :\n\n'
          '$inviteUrl\n\n'
          'Ce lien est valide 7 jours.';
      await Clipboard.setData(ClipboardData(text: bodyLong));
      // Corps court dans l'URI pour limiter la longueur (destinataire + corps pré-remplis)
      final bodyShort =
          'Bonjour $firstName,\n\n'
          'Ouvrez ce lien pour créer votre compte ViroTeam (valide 7 jours) :\n\n$inviteUrl';
      final subjectEnc = Uri.encodeComponent(subject);
      final bodyEnc = Uri.encodeComponent(bodyShort);
      final mailtoString =
          'mailto:$toAddress?subject=$subjectEnc&body=$bodyEnc';
      final mailto = Uri.parse(mailtoString);
      bool mailOpened = false;
      try {
        if (await canLaunchUrl(mailto)) {
          mailOpened = await launchUrl(
            mailto,
            mode: LaunchMode.externalApplication,
          );
        }
        if (!mailOpened) {
          mailOpened = await launchUrl(
            mailto,
            mode: LaunchMode.platformDefault,
          );
        }
      } catch (_) {
        mailOpened = false;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mailOpened
                  ? "Lien copié. Le client mail s'ouvre avec le message."
                  : "Lien copié. Collez le message depuis le presse-papier si besoin.",
            ),
          ),
        );
      }
      AppLogger.instance.info('Lien d\'invite créé', {
        'clubId': clubId,
        'pendingMemberId': pendingMemberId,
      });
    } catch (e) {
      AppLogger.instance.error(
        'Erreur création lien d\'invite',
        error: e,
        context: {'clubId': widget.clubId, 'pendingMemberId': pendingMemberId},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showAddMemberEmailDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Ajouter un membre"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Saisissez un email.";
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final email = emailController.text.trim();
              Navigator.pop(dialogContext);
              await _checkEmailAndProceed(context, email);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
    // Différer le dispose pour éviter "used after being disposed" pendant la fermeture du dialogue
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emailController.dispose();
      });
    });
  }

  Future<void> _checkEmailAndProceed(
    BuildContext pageContext,
    String email,
  ) async {
    final emailNorm = email.trim().toLowerCase();
    if (emailNorm.isEmpty) return;

    final userSnap = await appFirestore
        .collection(FirebaseCollections.users)
        .where('email', isEqualTo: emailNorm)
        .limit(1)
        .get();

    if (userSnap.docs.isNotEmpty && pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text("Un compte existe déjà pour cet email.")),
      );
      return;
    }

    final pendingSnap = await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.pendingMembers)
        .where('email', isEqualTo: emailNorm)
        .limit(1)
        .get();

    if (pendingSnap.docs.isNotEmpty && pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text("Cet email est déjà en attente de création de compte."),
        ),
      );
      return;
    }

    if (!pageContext.mounted) return;
    _showAddMemberNameDialog(pageContext, emailNorm);
  }

  Future<void> _showAddMemberNameDialog(
    BuildContext context,
    String emailNorm,
  ) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Nom et prénom"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return "Saisissez le prénom.";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: "Nom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Saisissez le nom.";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();
              Navigator.pop(dialogContext);
              await _addPendingMember(context, emailNorm, firstName, lastName);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
    // Différer le dispose pour éviter "used after being disposed" pendant la fermeture du dialogue
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        firstNameController.dispose();
        lastNameController.dispose();
      });
    });
  }

  Future<void> _addPendingMember(
    BuildContext context,
    String emailNorm,
    String firstName,
    String lastName,
  ) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.pendingMembers)
          .add({
            'email': emailNorm,
            'firstName': firstName,
            'lastName': lastName,
            'addedAt': FieldValue.serverTimestamp(),
            if (adminId != null) 'addedBy': adminId,
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Membre ajouté en attente de création de compte."),
          ),
        );
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur ajout membre en attente',
        error: e,
        context: {'clubId': widget.clubId, 'email': emailNorm},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmRemovePendingMember(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Retirer de la liste"),
        content: Text(
          "Retirer $displayName de la liste des membres en attente ?",
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
    if (confirmed == true && context.mounted) {
      try {
        await ref.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Membre retiré de la liste.")),
          );
        }
      } catch (e) {
        AppLogger.instance.error(
          'Erreur suppression membre en attente',
          error: e,
          context: {'clubId': widget.clubId},
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
          );
        }
      }
    }
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
              ? (playerHasLicense(data, widget.clubId)
                    ? "Licencié"
                    : "Non Licencié")
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
        ? 'joueur'
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
    final snap = await appFirestore
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

  Future<void> _recordRemoval(
    String adminId,
    String removedUserId,
    String role,
  ) async {
    try {
      await appFirestore
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
              "Vous ne pouvez retirer qu'un seul joueur ou coach par jour. Réessayez demain.",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isRemoving = true);
    try {
      final firestore = appFirestore;

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
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
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
      final memberIds = (eventData['teamMemberIds'] as List<dynamic>?)
          ?.whereType<String>();
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
      final playerIds = (teamData['playerIds'] as List<dynamic>?)
          ?.whereType<String>();
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
      newPlayerClubs = clubs
          .where((c) => (c['clubId'] as String?) != clubId)
          .toList();
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
        newActiveContext = {'role': 'player', 'clubId': first['clubId']};
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
    updates['_adminClubId'] = clubId;
    await firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .update(updates);
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
    final coachList =
        (roles['coach'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
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
    updates['_adminClubId'] = clubId;
    await firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .update(updates);
  }

  Future<void> _removeAdminFromClub(
    FirebaseFirestore firestore,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final clubId = widget.clubId;
    await firestore.collection(FirebaseCollections.clubs).doc(clubId).update({
      'admins': FieldValue.arrayRemove([uid]),
    });
    final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
    final adminList =
        (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
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
    if (activeClubId == clubId &&
        (activeRole == 'admin' || activeRole == 'admin_fondateur')) {
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
    updates['_adminClubId'] = clubId;
    await firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .update(updates);
  }

  Future<void> _changeRole(
    String userId,
    Map<String, dynamic> data, {
    required bool toAdmin,
  }) async {
    setState(() => _isRemoving = true);
    try {
      final firestore = appFirestore;
      final clubId = widget.clubId;
      final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});

      if (toAdmin) {
        // Coach -> Admin : retirer de roles.coach, ajouter à roles.admin
        final coachList =
            (roles['coach'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        final newCoachList = coachList
            .where((c) => c['clubId'] != clubId)
            .toList();
        if (newCoachList.isEmpty) {
          roles.remove('coach');
        } else {
          roles['coach'] = newCoachList;
        }
        final adminList =
            (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
        if (!adminList.contains(clubId)) {
          adminList.add(clubId);
          roles['admin'] = adminList;
        }
      } else {
        // Admin -> Coach : retirer de roles.admin, ajouter à roles.coach
        final adminList =
            (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
        final newAdminList = adminList.where((id) => id != clubId).toList();
        if (newAdminList.isEmpty) {
          roles.remove('admin');
        } else {
          roles['admin'] = newAdminList;
        }
        final coachList =
            (roles['coach'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
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
        '_adminClubId': clubId,
      };
      await firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toAdmin
                  ? "Personne passée en administrateur."
                  : "Personne passée en coach.",
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
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
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

/// Tuile par membre : carte lisible avec avatar, nom, rôle, et infos joueur (catégories, équipe, licence).
class _MemberTile extends StatelessWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String roleLabel;
  final bool isPlayer;
  final bool isStaff;
  final List<String> categories;
  final List<String> teamNames;
  final bool hasLicense;
  final Widget trailing;
  final VoidCallback onTap;

  const _MemberTile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.roleLabel,
    required this.isPlayer,
    required this.isStaff,
    required this.categories,
    required this.teamNames,
    required this.hasLicense,
    required this.trailing,
    required this.onTap,
  });

  Widget _roleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _categoryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ViroColors.borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserDisplayTile(
                  userId: userId,
                  firstName: firstName,
                  lastName: lastName,
                  avatarUrl: avatarUrl,
                  navigateOnTap: false,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isStaff)
                          _roleBadge(
                            roleLabel,
                            ViroColors.getMemberBadgeColor(roleLabel),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              if (categories.isEmpty)
                                _categoryBadge(
                                  "Sans catégorie",
                                  ViroColors.getMemberBadgeColor(
                                    "Sans catégorie",
                                  ),
                                )
                              else
                                ...categories.map(
                                  (cat) => _categoryBadge(
                                    cat,
                                    ViroColors.getMemberBadgeColor(cat),
                                  ),
                                ),
                            ],
                          ),
                        if (isPlayer) ...[
                          const SizedBox(width: 8),
                          _categoryBadge(
                            hasLicense ? "Licencié" : "Non licencié",
                            ViroColors.getMemberBadgeColor(
                              hasLicense ? "Licencié" : "Non licencié",
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        trailing,
                      ],
                    ),
                    if (isPlayer && teamNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: teamNames
                            .map(
                              (name) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
