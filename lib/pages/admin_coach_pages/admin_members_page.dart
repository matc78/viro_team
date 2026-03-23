import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../../constants/firebase_collections.dart';
import '../../services/membership_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
import '../profil_display_page.dart';
import 'widgets/member_tile.dart';
import 'widgets/pending_members_section.dart';

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
  bool _isRemoving = false;
  final TextEditingController _searchController = TextEditingController();

  // Stream club members au lieu de tous les users
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSubscription;
  List<Map<String, dynamic>>? _enrichedEntries;
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _membersSubscription = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.members)
        .snapshots()
        .listen(_onMembersSnapshot, onError: (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    });
  }

  /// Appelé à chaque mise à jour du stream members.
  /// Construit les entrées depuis les docs member (sans requête extra),
  /// puis batch-fetch les profils utilisateurs en une seule passe.
  Future<void> _onMembersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final memberDocs = snap.docs;
    final memberIds = memberDocs.map((d) => d.id).toList();

    // Construire les entrées directement depuis les docs member (0 requête extra)
    final entries = <Map<String, dynamic>>[];
    for (final memberDoc in memberDocs) {
      final data = memberDoc.data();
      final roles =
          (data['roles'] as List?)?.whereType<String>().toList() ?? [];
      final player = data['player'] as Map<String, dynamic>?;
      final teamNames =
          (player?['teamNames'] as List?)?.whereType<String>().toList() ?? [];
      final categories =
          (player?['categories'] as List?)?.whereType<String>().toList() ?? [];
      final license = (player?['license'] as String? ?? '').trim();

      for (final role in roles) {
        entries.add({
          'uid': memberDoc.id,
          'role': role,
          'teamNames': teamNames,
          'categories': categories,
          'hasLicense': license.isNotEmpty,
        });
      }
    }

    // Batch-fetch des profils utilisateurs (groupés en chunks de 10)
    final userMap = <String, Map<String, dynamic>>{};
    if (memberIds.isNotEmpty) {
      final userDocs = await fetchUsersBatch(memberIds);
      for (final doc in userDocs) {
        userMap[doc.id] = doc.data() ?? {};
      }
    }

    // Enrichir avec les données d'affichage utilisateur
    final enrichedEntries = entries
        .map((e) => {...e, 'userData': userMap[e['uid'] as String] ?? {}})
        .toList();

    if (mounted) {
      setState(() {
        _enrichedEntries = enrichedEntries;
        _isLoadingMembers = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _membersSubscription?.cancel();
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
      ),
      body: CustomScrollView(
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
              _buildMembersSliver(),
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
          ),
    );
  }

  /// Sliver pour la liste des membres — lit depuis [_enrichedEntries] (alimenté
  /// par le stream members du club), sans requête Firestore supplémentaire.
  Widget _buildMembersSliver() {
    if (_isLoadingMembers) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final enrichedEntries = _enrichedEntries ?? [];
    final filtered = enrichedEntries.where((entry) {
      final role = entry['role'] as String;
      final data = entry['userData'] as Map<String, dynamic>;
      final first = (data['firstName'] as String? ?? "").toLowerCase();
      final last = (data['lastName'] as String? ?? "").toLowerCase();
      final email = (data['email'] as String? ?? "").toLowerCase();
      final userCats = (entry['categories'] as List<String>?) ?? [];
      final userTeams = (entry['teamNames'] as List<String>?) ?? [];
      final isPlayer = role == 'player';
      final catOk =
          !isPlayer ||
          _selectedCategory == null ||
          userCats.any((c) => _normalize(c) == _normalize(_selectedCategory!));
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
    }).toList()
      ..sort((a, b) {
        final aRole = a['role'] as String;
        final bRole = b['role'] as String;
        final aData = a['userData'] as Map<String, dynamic>;
        final bData = b['userData'] as Map<String, dynamic>;
        final aIsStaff =
            aRole == 'admin_fondateur' || aRole == 'coach' || aRole == 'admin';
        final bIsStaff =
            bRole == 'admin_fondateur' || bRole == 'coach' || bRole == 'admin';
        if (aIsStaff && !bIsStaff) return -1;
        if (!aIsStaff && bIsStaff) return 1;
        final aFirst = (aData['firstName'] as String? ?? "").toLowerCase();
        final bFirst = (bData['firstName'] as String? ?? "").toLowerCase();
        return aFirst.compareTo(bFirst);
      });

    if (filtered.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
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
        final uid = entry['uid'] as String;
        final role = entry['role'] as String;
        final data = entry['userData'] as Map<String, dynamic>;
        if (data.isEmpty) return const SizedBox.shrink();
        final firstName = data['firstName'] as String? ?? "";
        final lastName = data['lastName'] as String? ?? "";
        final avatarUrl = effectiveAvatarUrl(data);
        final isPlayer = role == 'player';
        final userCategories = (entry['categories'] as List<String>?) ?? [];
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
        final bool canDelete =
            canEdit &&
            role != 'admin_fondateur' &&
            (widget.currentViewerRole == 'admin_fondateur' ||
                (widget.currentViewerRole == 'admin' &&
                    (role == 'player' || role == 'coach')));
        final hasLicense = entry['hasLicense'] as bool? ?? false;

        MemberTile buildTile({Animation<double>? animation}) => MemberTile(
          userId: uid,
          firstName: firstName,
          lastName: lastName,
          avatarUrl: avatarUrl,
          roleLabel: roleLabel,
          isPlayer: isPlayer,
          isStaff: isStaff,
          categories: userCategories,
          teamNames: (entry['teamNames'] as List<String>?) ?? [],
          hasLicense: hasLicense,
          trailing: const SizedBox.shrink(),
          slideAnimation: animation,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfilDisplayPage(userId: uid)),
          ),
        );

        // Uniquement l'admin_fondateur peut changer le rôle coach ↔ admin
        final bool canChangeRole =
            widget.currentViewerRole == 'admin_fondateur' &&
            (role == 'coach' || role == 'admin');

        if (!canDelete) return buildTile();
        return _MemberSlidableDeleteTile(
          key: Key('$uid-$role'),
          onDeleteTap: () =>
              _confirmAndRemove(uid, role, data, firstName, lastName),
          onRoleChangeTap: canChangeRole
              ? () => _confirmAndChangeRole(uid, data, toAdmin: role == 'coach')
              : null,
          roleChangeIcon: role == 'coach'
              ? Icons.admin_panel_settings_outlined
              : Icons.sports_outlined,
          builder: (animation) => buildTile(animation: animation),
        );
      }, childCount: slots.length),
    );
  }

  /// Contenu des cartes "En attente de création de compte" et "Refus d'invitation".
  Widget _buildBottomCardContent({
    required bool canEdit,
    required bool canSendInviteLink,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
                PendingMembersSection(
                  clubId: widget.clubId,
                  search: _search,
                  onlyDeclined: false,
                  canEdit: canEdit,
                  canSendInviteLink: canSendInviteLink,
                  onSendInviteLink: (_, id, first, last, email) =>
                      _sendInviteLink(context, id, first, last, email),
                  onEditPendingMember: _showEditPendingMemberDialog,
                  onRemovePendingMember: _confirmRemovePendingMember,
                ),
              ],
            ),
          ),
        ),
        _buildDeclinedInvitationsCard(
          canEdit: canEdit,
          canSendInviteLink: canSendInviteLink,
        ),
      ],
    );
  }

  /// Carte "Refus d'invitation" visible uniquement si au moins un joueur a refusé l'invitation par lien.
  Widget _buildDeclinedInvitationsCard({
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
        if (!snapshot.hasData || snapshot.hasError) return const SizedBox.shrink();
        final hasDeclined = snapshot.data!.docs.any((d) =>
            (d.data()['invitationStatus'] as String? ?? '') == 'declined');
        if (!hasDeclined) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(top: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: ViroColors.error, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Refus d'invitation",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                PendingMembersSection(
                  clubId: widget.clubId,
                  search: _search,
                  onlyDeclined: true,
                  canEdit: canEdit,
                  canSendInviteLink: canSendInviteLink,
                  onSendInviteLink: (_, id, first, last, email) =>
                      _sendInviteLink(context, id, first, last, email),
                  onEditPendingMember: _showEditPendingMemberDialog,
                  onRemovePendingMember: _confirmRemovePendingMember,
                ),
              ],
            ),
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

  /// Crée un invite_link, met à jour le pending_member (invitationSentAt, invitationStatus: pending, supprime declinedAt).
  /// Retourne les infos pour copier/mailto, ou null en cas d'erreur.
  Future<({String inviteUrl, String bodyShort, String bodyLong, String firstName})?> _createInviteLinkAndUpdatePending(
    BuildContext context,
    String pendingMemberId,
    String firstName,
    String lastName,
    String email,
  ) async {
    if (email.trim().isEmpty) return null;
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
      final pendingRef = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.pendingMembers)
          .doc(pendingMemberId);
      await pendingRef.set({
        'invitationStatus': 'pending',
        'invitationSentAt': FieldValue.serverTimestamp(),
        'declinedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      final inviteUrl = 'viroteam://invite?t=$token&c=$clubId';
      final first = firstName.trim();
      final clubName = widget.clubName;
      final bodyLong =
          'Salut $first,\n\n'
          'Ton club $clubName t\'invite à rejoindre ViroTeam. Télécharge l\'application puis ouvre ce lien pour créer ton compte :\n\n'
          '$inviteUrl\n\n'
          'Ce lien est valide 7 jours.';
      final bodyShort =
          'Salut $first,\n\n'
          'Ouvre ce lien pour créer ton compte ViroTeam (valide 7 jours) :\n\n$inviteUrl';
      AppLogger.instance.info('Lien d\'invite créé', {
        'clubId': clubId,
        'pendingMemberId': pendingMemberId,
      });
      return (inviteUrl: inviteUrl, bodyShort: bodyShort, bodyLong: bodyLong, firstName: first);
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
      return null;
    }
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
    final result = await _createInviteLinkAndUpdatePending(
      context,
      pendingMemberId,
      firstName,
      lastName,
      email,
    );
    if (result == null || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: result.bodyLong));
    final toAddress = email.trim().toLowerCase();
    final subject = 'Invitation ViroTeam - Créer votre compte';
    final mailto = Uri(
      scheme: 'mailto',
      query: 'to=${Uri.encodeComponent(toAddress)}&subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(result.bodyLong)}',
    );
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
    if (context.mounted && !mailOpened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir le client mail. Le lien a été copié dans le presse-papier."),
        ),
      );
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

    if (userSnap.docs.isNotEmpty) {
      if (!pageContext.mounted) return;
      final userData = userSnap.docs.first.data();
      final firstName = (userData['firstName'] as String? ?? '').trim();
      final lastName = (userData['lastName'] as String? ?? '').trim();
      final email = (userData['email'] as String? ?? '').trim();
      final displayName = '$firstName $lastName'.trim();
      final avatarUrl = effectiveAvatarUrl(userData);
      final confirmed = await showDialog<bool>(
        context: pageContext,
        builder: (ctx) => AlertDialog(
          title: const Text("Compte existant"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty
                    ? "Un compte existe pour cet email. Confirmer qu'il s'agit de la bonne personne ?"
                    : "C'est bien la bonne personne ?",
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Material(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: ViroColors.borderColor,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: ViroColors.secondary,
                        backgroundImage: avatarUrl != null &&
                                avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                displayName.isEmpty
                                    ? '?'
                                    : (firstName.isNotEmpty
                                            ? firstName[0]
                                            : '') +
                                        (lastName.isNotEmpty
                                            ? lastName[0]
                                            : ''),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ViroColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName.isEmpty ? '—' : displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      if (confirmed != true || !pageContext.mounted) return;
      await _addPendingMemberForExistingUserAndSendInvite(
        pageContext,
        emailNorm,
        firstName.isEmpty ? 'Prénom' : firstName,
        lastName.isEmpty ? 'Nom' : lastName,
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

    if (pendingSnap.docs.isNotEmpty) {
      if (!pageContext.mounted) return;
      final pendingDoc = pendingSnap.docs.first;
      final data = pendingDoc.data();
      final resend = await showDialog<bool>(
        context: pageContext,
        builder: (ctx) => AlertDialog(
          title: const Text("Déjà en attente"),
          content: const Text(
            "Cet email est déjà en attente. Renvoyer l'invitation ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Renvoyer le lien"),
            ),
          ],
        ),
      );
      if (resend != true || !pageContext.mounted) return;
      final firstName = data['firstName'] as String? ?? '';
      final lastName = data['lastName'] as String? ?? '';
      final result = await _createInviteLinkAndUpdatePending(
        pageContext,
        pendingDoc.id,
        firstName,
        lastName,
        emailNorm,
      );
      if (result != null && pageContext.mounted) {
        await Clipboard.setData(ClipboardData(text: result.bodyLong));
        final subject = 'Invitation ViroTeam - Créer votre compte';
        final mailto = Uri(
          scheme: 'mailto',
          query: 'to=${Uri.encodeComponent(emailNorm)}&subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(result.bodyShort)}',
        );
        try {
          if (await canLaunchUrl(mailto)) {
            await launchUrl(mailto, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
        if (pageContext.mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            const SnackBar(content: Text("Lien créé et copié. Invitation renvoyée.")),
          );
        }
      }
      return;
    }

    if (!pageContext.mounted) return;
    _showAddMemberNameDialog(pageContext, emailNorm);
  }

  /// Crée un pending_member pour un utilisateur existant, crée l'invite_link, puis affiche le dialog Copier / Envoyer par email.
  Future<void> _addPendingMemberForExistingUserAndSendInvite(
    BuildContext context,
    String emailNorm,
    String firstName,
    String lastName,
  ) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      final pendingRef = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.pendingMembers)
          .add({
            'email': emailNorm,
            'firstName': firstName,
            'lastName': lastName,
            'invitationStatus': 'pending',
            'addedAt': FieldValue.serverTimestamp(),
            if (adminId != null) 'addedBy': adminId,
          });
      final pendingMemberId = pendingRef.id;
      final result = await _createInviteLinkAndUpdatePending(
        context,
        pendingMemberId,
        firstName,
        lastName,
        emailNorm,
      );
      if (!context.mounted) return;
      if (result == null) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Invitation créée"),
          content: const Text(
            "Le lien d'invitation a été créé. Vous pouvez le copier ou l'envoyer par email.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fermer"),
            ),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.bodyLong));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lien copié dans le presse-papier.")),
                );
              },
              child: const Text("Copier le lien"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: result.bodyLong));
                const subject = 'Invitation ViroTeam - Créer votre compte';
                final mailto = Uri(
                  scheme: 'mailto',
                  query: 'to=${Uri.encodeComponent(emailNorm)}&subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(result.bodyShort)}',
                );
                try {
                  if (await canLaunchUrl(mailto)) {
                    await launchUrl(mailto, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lien copié. Le client mail s'ouvre.")),
                  );
                }
              },
              child: const Text("Envoyer par email"),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.instance.error(
        'Erreur ajout membre existant + invite',
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
            'invitationStatus': 'pending',
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


  Future<bool> _confirmAndRemove(
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
      return true;
    }
    return false;
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

  Future<void> _changeRole(
    String userId,
    Map<String, dynamic> data, {
    required bool toAdmin,
  }) async {
    setState(() => _isRemoving = true);
    try {
      final clubId = widget.clubId;
      if (toAdmin) {
        await MembershipService.instance.removeRoleFromClub(userId, clubId, 'coach');
        await MembershipService.instance.ensureMemberAndProfileSummary(
          uid: userId,
          clubId: clubId,
          role: 'admin',
          userDataOverride: data,
        );
      } else {
        await MembershipService.instance.removeRoleFromClub(userId, clubId, 'admin');
        await MembershipService.instance.removeRoleFromClub(userId, clubId, 'admin_fondateur');
        await MembershipService.instance.ensureMemberAndProfileSummary(
          uid: userId,
          clubId: clubId,
          role: 'coach',
          userDataOverride: data,
        );
      }
      final activeContext = data['activeContext'] as Map<String, dynamic>?;
      final activeClubId = activeContext?['clubId'] as String?;
      final updates = <String, dynamic>{
        if (activeClubId == clubId)
          'activeContext': {'role': toAdmin ? 'admin' : 'coach', 'clubId': clubId},
        '_adminClubId': clubId,
      };
      await appFirestore
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
    final summaries = (data['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
    bool hasOtherRoleInClub = summaries.any((e) =>
        (e['clubId'] == clubId) &&
        ((e['role'] == 'coach') || (e['role'] == 'admin') || (e['role'] == 'admin_fondateur')));
    if (!hasOtherRoleInClub) {
      await firestore.collection(FirebaseCollections.clubs).doc(clubId).update({
        'members': FieldValue.arrayRemove([uid]),
      });
      try {
        final memberSnap = await firestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.members)
            .doc(uid)
            .get();
        final memberData = memberSnap.data();
        final player = memberData?['player'] as Map<String, dynamic>?;
        final teamIds = (player?['teamIds'] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];
        final teamNames = (player?['teamNames'] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];
        final joinedAt = player?['joinedAt'];
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
              if (teamIds.isNotEmpty) 'teamIds': teamIds,
              if (teamNames.isNotEmpty) 'teamNames': teamNames,
              if (joinedAt != null) 'joinedAt': joinedAt,
            });
      } catch (e) {
        AppLogger.instance.error(
          'Erreur member_leaves',
          error: e,
          context: {'clubId': clubId, 'userId': uid},
        );
      }
    }
    // 4. User : activeContext uniquement (profileSummaries/member gérés par removeRoleFromClub)
    final otherPlayerClubs = summaries.where((e) => e['role'] == 'player' && e['clubId'] != clubId).toList();
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId && activeRole == 'player') {
      if (otherPlayerClubs.isEmpty) {
        newActiveContext = null;
      } else {
        newActiveContext = {'role': 'player', 'clubId': otherPlayerClubs.first['clubId']};
      }
    }
    final updates = <String, dynamic>{};
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
    }
    updates['_adminClubId'] = clubId;
    if (updates.isNotEmpty) {
      await firestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .update(updates);
    }

    await MembershipService.instance.removeRoleFromClub(uid, clubId, 'player');
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
    final summaries = (data['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
    final otherCoachClubs = summaries.where((e) => e['role'] == 'coach' && e['clubId'] != clubId).toList();
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId && activeRole == 'coach') {
      if (otherCoachClubs.isEmpty) {
        newActiveContext = null;
      } else {
        newActiveContext = {'role': 'coach', 'clubId': otherCoachClubs.first['clubId']};
      }
    }
    final updates = <String, dynamic>{};
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
    }
    updates['_adminClubId'] = clubId;
    if (updates.isNotEmpty) {
      await firestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .update(updates);
    }
    await MembershipService.instance.removeRoleFromClub(uid, clubId, 'coach');
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
    final summaries = (data['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
    final otherAdminClubs = summaries
        .where((e) => (e['role'] == 'admin' || e['role'] == 'admin_fondateur') && e['clubId'] != clubId)
        .toList();
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    Map<String, dynamic>? newActiveContext;
    if (activeClubId == clubId &&
        (activeRole == 'admin' || activeRole == 'admin_fondateur')) {
      if (otherAdminClubs.isEmpty) {
        newActiveContext = null;
      } else {
        newActiveContext = {'role': 'admin', 'clubId': otherAdminClubs.first['clubId']};
      }
    }
    final updates = <String, dynamic>{};
    if (newActiveContext == null && activeClubId == clubId) {
      updates['activeContext'] = FieldValue.delete();
    } else if (newActiveContext != null) {
      updates['activeContext'] = newActiveContext;
    }
    updates['_adminClubId'] = clubId;
    if (updates.isNotEmpty) {
      await firestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .update(updates);
    }
    await MembershipService.instance.removeRoleFromClub(uid, clubId, 'admin');
    await MembershipService.instance.removeRoleFromClub(uid, clubId, 'admin_fondateur');
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

// ---------------------------------------------------------------------------
// Swipe-to-reveal delete button pour les tiles membres
// ---------------------------------------------------------------------------

/// Enveloppe une [MemberTile] avec un swipe gauche qui révèle 1 ou 2 boutons :
///   - toujours : bouton rouge "retirer du club"
///   - optionnellement à sa gauche : bouton bleu "changer de rôle"
///
/// La largeur du panneau s'adapte automatiquement au nombre de boutons.
/// Utilise un [builder] pour que la tile adapte ses tailles en temps réel.
class _MemberSlidableDeleteTile extends StatefulWidget {
  /// Builder appelé avec l'animation de slide (0 = fermé, 1 = ouvert).
  final Widget Function(Animation<double> slideAnimation) builder;

  /// Affiche la confirmation puis retire le membre. Renvoie true si retiré.
  final Future<bool> Function() onDeleteTap;

  /// Si non-null, un second bouton (changement de rôle) apparaît à gauche du bouton delete.
  final Future<void> Function()? onRoleChangeTap;

  /// Icône du bouton de changement de rôle.
  final IconData? roleChangeIcon;

  const _MemberSlidableDeleteTile({
    required super.key,
    required this.builder,
    required this.onDeleteTap,
    this.onRoleChangeTap,
    this.roleChangeIcon,
  });

  @override
  State<_MemberSlidableDeleteTile> createState() =>
      _MemberSlidableDeleteTileState();
}

class _MemberSlidableDeleteTileState extends State<_MemberSlidableDeleteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _buttonSize = 48.0;

  /// Largeur du panneau pour 1 bouton.
  /// Layout : [10px gap] [48px btn] [12px right padding] = 70px
  static const double _singleRevealWidth = 70.0;

  /// Largeur du panneau pour 2 boutons.
  /// Layout : [10px gap] [48px btn] [8px gap] [48px btn] [12px right padding] = 126px
  static const double _doubleRevealWidth = 126.0;

  double get _revealWidth =>
      widget.onRoleChangeTap != null ? _doubleRevealWidth : _singleRevealWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => _controller.animateTo(1.0, curve: Curves.easeOut);
  void _close() => _controller.animateTo(0.0, curve: Curves.easeOut);

  void _onDragStart(DragStartDetails _) => _controller.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value =
        (_controller.value - details.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    if (vx < -400) {
      _open();
    } else if (vx > 400) {
      _close();
    } else if (_controller.value >= 0.4) {
      _open();
    } else {
      _close();
    }
  }

  Future<void> _onDeleteTap() async {
    final deleted = await widget.onDeleteTap();
    if (!deleted && mounted) _close();
  }

  Future<void> _onRoleChangeTap() async {
    await widget.onRoleChangeTap!();
    if (mounted) _close();
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _buttonSize,
          height: _buttonSize,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRoleChange =
        widget.onRoleChangeTap != null && widget.roleChangeIcon != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: widget.builder(_controller)),

          // Panneau d'action : s'étend depuis la droite.
          // Le padding droit (12) s'aligne avec le padding horizontal de MemberTile.
          SizeTransition(
            axis: Axis.horizontal,
            sizeFactor: _controller,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRoleChange) ...[
                    _roundButton(
                      icon: widget.roleChangeIcon!,
                      color: Colors.indigo.shade400,
                      onTap: _onRoleChangeTap,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _roundButton(
                    icon: Icons.person_remove_outlined,
                    color: Colors.red.shade400,
                    onTap: _onDeleteTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
