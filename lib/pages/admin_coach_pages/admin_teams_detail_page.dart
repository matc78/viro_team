import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../services/membership_service.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';

class TeamDetailsPage extends StatefulWidget {
  final String clubId;
  final DocumentSnapshot teamDoc;

  const TeamDetailsPage({
    super.key,
    required this.clubId,
    required this.teamDoc,
  });

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  bool _isProcessing = false;
  // Ouvre une liste de membres du club pour les ajouter à l'équipe
  void _showAddMemberSheet(
    String role,
    String teamName,
    String teamCategory,
    List coachIds,
    List playerIds,
    List<String> pendingPlayerIds,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appFirestore.collection(FirebaseCollections.users).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: ViroLoader(size: 40));
          }
          final existingIds = role == 'coach' ? coachIds : playerIds;

          // Filtrer les utilisateurs du club avec le bon rôle
          final allDocs = snapshot.data!.docs
              .map((doc) => doc as DocumentSnapshot<Map<String, dynamic>>)
              .toList();
          final List<DocumentSnapshot<Map<String, dynamic>>> clubMembers;
          if (role == 'coach') {
            final coaches =
                filterUsersByClub(allDocs, widget.clubId, role: 'coach');
            final admins =
                filterUsersByClub(allDocs, widget.clubId, role: 'admin');
            final adminsFondateurs = filterUsersByClub(
              allDocs,
              widget.clubId,
              role: 'admin_fondateur',
            );
            final seenIds = coaches.map((d) => d.id).toSet();
            clubMembers = [
              ...coaches,
              ...admins.where((doc) => seenIds.add(doc.id)),
              ...adminsFondateurs.where((doc) => seenIds.add(doc.id)),
            ];
          } else {
            clubMembers =
                filterUsersByClub(allDocs, widget.clubId, role: 'player');
          }

          final users = clubMembers
              .where((doc) => !existingIds.contains(doc.id))
              .toList();

          if (role == 'coach') {
            if (users.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Aucun membre trouvé avec ce rôle dans le club.",
                  ),
                ),
              );
            }
            return _buildAddMemberSheetContent(
              ctx: ctx,
              role: role,
              teamName: teamName,
              teamCategory: teamCategory,
              users: users,
              pendingList: null,
            );
          }

          // Rôle player : charger aussi les pending_members
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(widget.clubId)
                .collection(FirebaseCollections.pendingMembers)
                .snapshots(),
            builder: (context, pendingSnap) {
              List<DocumentSnapshot<Map<String, dynamic>>> pendingDocs = [];
              if (pendingSnap.hasData) {
                pendingDocs = pendingSnap.data!.docs
                    .where((d) => !pendingPlayerIds.contains(d.id))
                    .toList();
              }
              if (users.isEmpty && pendingDocs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Aucun joueur ou membre en attente à ajouter.",
                    ),
                  ),
                );
              }
              return _buildAddMemberSheetContent(
                ctx: ctx,
                role: role,
                teamName: teamName,
                teamCategory: teamCategory,
                users: users,
                pendingList: pendingDocs,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddMemberSheetContent({
    required BuildContext ctx,
    required String role,
    required String teamName,
    required String teamCategory,
    required List<DocumentSnapshot<Map<String, dynamic>>> users,
    required List<DocumentSnapshot<Map<String, dynamic>>>? pendingList,
  }) {
    final hasPending = pendingList != null && pendingList.isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            role == 'player'
                ? "Ajouter un membre"
                : "Ajouter un Coach / Admin",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (users.isNotEmpty) ...[
                if (hasPending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Joueurs du club",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ...users.map((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  final userId = doc.id;
                  return _buildAddUserTile(
                    ctx: ctx,
                    userId: userId,
                    userData: user,
                    role: role,
                    teamName: teamName,
                    teamCategory: teamCategory,
                    isPending: false,
                  );
                }),
              ],
              if (hasPending) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "En attente de création de compte",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ...pendingList.map((doc) {
                  final data = doc.data() ?? {};
                  return _buildAddUserTile(
                    ctx: ctx,
                    userId: doc.id,
                    userData: data,
                    role: role,
                    teamName: teamName,
                    teamCategory: teamCategory,
                    isPending: true,
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddUserTile({
    required BuildContext ctx,
    required String userId,
    required Map<String, dynamic> userData,
    required String role,
    required String teamName,
    required String teamCategory,
    required bool isPending,
  }) {
    final firstName = userData['firstName'] as String? ?? '';
    final lastName = userData['lastName'] as String? ?? '';
    final email = userData['email'] as String? ?? '';
    final displayName =
        '$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ViroColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: isPending
            ? CircleAvatar(
                radius: 20,
                backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person_outline, color: ViroColors.primary),
              )
            : null,
        title: isPending
            ? Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            : UserDisplayTile(
                userId: userId,
                firstName: userData['firstName'] as String?,
                lastName: userData['lastName'] as String?,
                avatarUrl: effectiveAvatarUrl(userData),
                navigateOnTap: false,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
        subtitle: isPending && email.isNotEmpty
            ? Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12))
            : null,
        trailing: const Icon(
          Icons.add_circle_outline,
          color: ViroColors.primary,
        ),
        onTap: () async {
          if (_isProcessing) return;
          setState(() => _isProcessing = true);
          try {
            if (isPending) {
              await widget.teamDoc.reference.update({
                'pendingPlayerIds': FieldValue.arrayUnion([userId]),
              });
              AppLogger.instance.info(
                'Joueur en attente ajouté à l\'équipe',
                {
                  'pendingId': userId,
                  'teamId': widget.teamDoc.id,
                  'clubId': widget.clubId,
                },
              );
            } else {
              String field = (role == 'player') ? 'playerIds' : 'coachIds';
              await widget.teamDoc.reference.update({
                field: FieldValue.arrayUnion([userId]),
              });
              if (role == 'player') {
                await updatePlayerClubsForTeam(
                  appFirestore,
                  userId,
                  widget.clubId,
                  add: true,
                  teamId: widget.teamDoc.id,
                  teamName: teamName,
                  teamCategory: teamCategory,
                );
              } else {
                await appFirestore
                    .collection(FirebaseCollections.users)
                    .doc(userId)
                    .set({'_adminClubId': widget.clubId}, SetOptions(merge: true));
                final memberRef = appFirestore
                    .collection(FirebaseCollections.clubs)
                    .doc(widget.clubId)
                    .collection(FirebaseCollections.members)
                    .doc(userId);
                final memberSnap = await memberRef.get();
                if (memberSnap.exists) {
                  final coach = (memberSnap.data()?['coach'] as Map?) ?? {};
                  final tIds = List<String>.from((coach['teamIds'] as List?)?.whereType<String>() ?? []);
                  final tNames = List<String>.from((coach['teamNames'] as List?)?.whereType<String>() ?? tIds);
                  if (!tIds.contains(widget.teamDoc.id)) {
                    tIds.add(widget.teamDoc.id);
                    tNames.add(teamName);
                    await MembershipService.instance.updateMemberCoach(
                      uid: userId,
                      clubId: widget.clubId,
                      teamIds: tIds,
                      teamNames: tNames,
                    );
                  }
                } else {
                  await MembershipService.instance.ensureMemberAndProfileSummary(
                    uid: userId,
                    clubId: widget.clubId,
                    role: 'coach',
                    coachTeamIds: [widget.teamDoc.id],
                    coachTeamNames: [teamName],
                  );
                }
              }
              if (role == 'player') {
                await _updateEventsAttendanceForPlayer(
                  userId,
                  teamName,
                  add: true,
                );
              }
              AppLogger.instance.info('Membre ajouté à l\'équipe', {
                'userId': userId,
                'teamId': widget.teamDoc.id,
                'teamName': teamName,
                'role': role,
                'clubId': widget.clubId,
              });
            }
            if (mounted) Navigator.pop(ctx);
          } catch (e) {
            AppLogger.instance.error(
              'Erreur lors de l\'ajout d\'un membre à l\'équipe',
              error: e,
              context: {
                'userId': userId,
                'teamId': widget.teamDoc.id,
                'role': role,
                'clubId': widget.clubId,
              },
            );
            if (mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(FirebaseErrorHandler.getErrorMessage(e)),
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isProcessing = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.teamDoc.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: ViroLoader(size: 80));
        }

        final teamData = snapshot.data!.data() as Map<String, dynamic>;
        final List coachIds = List<String>.from(teamData['coachIds'] ?? []);
        final List playerIds = teamData['playerIds'] ?? [];
        final List<String> pendingPlayerIds =
            List<String>.from(teamData['pendingPlayerIds'] ?? []);
        final String teamName = teamData['name'] ?? "";
        final String teamCategory = teamData['category'] ?? "";

        if (currentUserId == null) {
          return Scaffold(
            appBar: AppBar(title: Text(teamData['name'] ?? "Détails")),
            body: const Center(child: Text("Non connecté")),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: appFirestore
              .collection(FirebaseCollections.users)
              .doc(currentUserId)
              .snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data();
            final rolesInClub =
                getAllUserRolesInClub(userData ?? {}, widget.clubId);
            final isAdmin = rolesInClub.contains('admin') ||
                rolesInClub.contains('admin_fondateur');
            final isCoachOfThisTeam = coachIds.contains(currentUserId);
            final canEdit = isAdmin || isCoachOfThisTeam;

            return Scaffold(
              appBar: AppBar(
                title: Column(
                  children: [
                    Text(teamData['name'] ?? "Détails"),
                    Text(
                      teamData['category'] ?? "",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                // Pas d'icône d'édition : admin et coach ajoutent/retirent via les boutons + et - directement
                actions: [],
              ),
              body: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: _isProcessing,
                    child: Column(
                      children: [
                        _buildMemberSection(
                          "Coachs",
                          coachIds,
                          'coach',
                          teamName,
                          teamCategory,
                          coachIds,
                          playerIds,
                          canEdit: canEdit,
                          showAddWithoutEditMode: isAdmin || isCoachOfThisTeam,
                          canRemoveInSection: isAdmin,
                        ),
                        const Divider(height: 1, color: ViroColors.borderColor),
                        _buildMemberSection(
                          "Effectif (Membres)",
                          playerIds,
                          'player',
                          teamName,
                          teamCategory,
                          coachIds,
                          playerIds,
                          canEdit: canEdit,
                          showAddWithoutEditMode: isAdmin || isCoachOfThisTeam,
                          canRemoveInSection: isAdmin || isCoachOfThisTeam,
                          pendingPlayerIds: pendingPlayerIds,
                        ),
                      ],
                    ),
                  ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: ViroColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
            );
          },
        );
      },
    );
  }

  Widget _buildMemberSection(
    String title,
    List ids,
    String role,
    String teamName,
    String teamCategory,
    List coachIds,
    List playerIds, {
    bool canEdit = true,
    bool showAddWithoutEditMode = false,
    bool canRemoveInSection = true,
    List<String>? pendingPlayerIds,
  }) {
    final isCoach = role == 'coach';
    final showAdd = canEdit &&
        (role != 'coach' || showAddWithoutEditMode);
    final pendingIds = role == 'player' ? (pendingPlayerIds ?? []) : <String>[];
    final hasPending = pendingIds.isNotEmpty;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          if (showAdd)
            IconButton(
              icon: const Icon(
                Icons.add_circle_rounded,
                color: ViroColors.primary,
              ),
              onPressed: () => _showAddMemberSheet(
                role,
                teamName,
                teamCategory,
                coachIds,
                playerIds,
                pendingIds,
              ),
            ),
        ],
      ),
    );

    final isEmpty = ids.isEmpty && !hasPending;
    final listWidget = isEmpty
        ? const Center(
            child: Text(
              "Aucun membre dans cette section",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        : _buildPlayerSectionContent(
            role: role,
            ids: ids,
            teamName: teamName,
            teamCategory: teamCategory,
            pendingIds: pendingIds,
            canEdit: canEdit,
            canRemoveInSection: canRemoveInSection,
          );

    if (isCoach) {
      final height = (ids.length * 68 + 120)
          .clamp(160, 360)
          .toDouble(); // responsive height
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: listWidget,
          ),
        ],
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Expanded(child: listWidget),
        ],
      ),
    );
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _fetchPendingBatch(
    List<String> docIds,
  ) async {
    if (docIds.isEmpty) return [];
    final refs = docIds
        .map(
          (id) => appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(widget.clubId)
              .collection(FirebaseCollections.pendingMembers)
              .doc(id),
        )
        .toList();
    final snaps = await Future.wait(refs.map((r) => r.get()));
    return snaps.cast<DocumentSnapshot<Map<String, dynamic>>>().toList();
  }

  Widget _buildPlayerSectionContent({
    required String role,
    required List ids,
    required String teamName,
    required String teamCategory,
    required List<String> pendingIds,
    required bool canEdit,
    required bool canRemoveInSection,
  }) {
    final isPlayer = role == 'player';
    final hasPending = isPlayer && pendingIds.isNotEmpty;

    if (!hasPending) {
      return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: fetchUsersBatch(ids.cast<String>()),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: ViroLoader(size: 40));
          }
          final userDocs = snap.data!;
          final userMap = {
            for (var doc in userDocs)
              doc.id: doc.data() as Map<String, dynamic>,
          };
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ids.length,
            itemBuilder: (ctx, i) => _buildUserTile(
              userId: ids[i] as String,
              userData: userMap[ids[i] as String],
              role: role,
              teamName: teamName,
              teamCategory: teamCategory,
              canEdit: canEdit,
              canRemoveInSection: canRemoveInSection,
            ),
          );
        },
      );
    }

    return FutureBuilder<
        (List<DocumentSnapshot<Map<String, dynamic>>>, List<DocumentSnapshot<Map<String, dynamic>>>)>(
      future: Future.wait([
        fetchUsersBatch(ids.cast<String>()),
        _fetchPendingBatch(pendingIds),
      ]).then((list) => (list[0], list[1])),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: ViroLoader(size: 40));
        }
        final userDocs = snap.data!.$1;
        final pendingDocs = snap.data!.$2;
        final userMap = {
          for (var doc in userDocs)
            doc.id: doc.data() as Map<String, dynamic>,
        };
        final pendingMap = <String, Map<String, dynamic>>{};
        for (var i = 0; i < pendingIds.length && i < pendingDocs.length; i++) {
          final data = pendingDocs[i].data();
          if (data != null) pendingMap[pendingIds[i]] = data;
        }
        final totalCount = ids.length + pendingIds.length;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: totalCount,
          itemBuilder: (ctx, i) {
            if (i < ids.length) {
              final userId = ids[i] as String;
              return _buildUserTile(
                userId: userId,
                userData: userMap[userId],
                role: role,
                teamName: teamName,
                teamCategory: teamCategory,
                canEdit: canEdit,
                canRemoveInSection: canRemoveInSection,
              );
            }
            final pendingId = pendingIds[i - ids.length];
            final data = pendingMap[pendingId];
            if (data == null) return const SizedBox.shrink();
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ViroColors.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                visualDensity: VisualDensity.compact,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_outline,
                    color: ViroColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  '$firstName $lastName'.trim().isEmpty
                      ? email
                      : '$firstName $lastName'.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: email.isNotEmpty
                    ? Text(
                        email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: canEdit && canRemoveInSection
                    ? IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await widget.teamDoc.reference.update({
                            'pendingPlayerIds':
                                FieldValue.arrayRemove([pendingId]),
                          });
                          AppLogger.instance.info(
                            'Joueur en attente retiré de l\'équipe',
                            {
                              'pendingId': pendingId,
                              'teamId': widget.teamDoc.id,
                              'clubId': widget.clubId,
                            },
                          );
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile({
    required String userId,
    required Map<String, dynamic>? userData,
    required String role,
    required String teamName,
    required String teamCategory,
    required bool canEdit,
    required bool canRemoveInSection,
  }) {
    if (userData == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ViroColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: null,
        title: UserDisplayTile(
          userId: userId,
          firstName: userData['firstName'] as String?,
          lastName: userData['lastName'] as String?,
          avatarUrl: effectiveAvatarUrl(userData),
          navigateOnTap: false,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: canEdit && canRemoveInSection
            ? IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
                onPressed: () async {
                  String field =
                      (role == 'player') ? 'playerIds' : 'coachIds';
                  await widget.teamDoc.reference.update({
                    field: FieldValue.arrayRemove([userId]),
                  });
                  if (role == 'player') {
                    await updatePlayerClubsForTeam(
                      appFirestore,
                      userId,
                      widget.clubId,
                      add: false,
                      teamId: widget.teamDoc.id,
                      teamName: teamName,
                      teamCategory: teamCategory,
                    );
                  } else {
                    await appFirestore
                        .collection(FirebaseCollections.users)
                        .doc(userId)
                        .set({'_adminClubId': widget.clubId}, SetOptions(merge: true));
                    final memberRef = appFirestore
                        .collection(FirebaseCollections.clubs)
                        .doc(widget.clubId)
                        .collection(FirebaseCollections.members)
                        .doc(userId);
                    final memberSnap = await memberRef.get();
                    if (memberSnap.exists) {
                      final coach = (memberSnap.data()?['coach'] as Map?) ?? {};
                      final tIds = List<String>.from((coach['teamIds'] as List?)?.whereType<String>() ?? []);
                      final tNames = List<String>.from((coach['teamNames'] as List?)?.whereType<String>() ?? tIds);
                      final idx = tIds.indexOf(widget.teamDoc.id);
                      if (idx >= 0) {
                        tIds.removeAt(idx);
                        if (idx < tNames.length) tNames.removeAt(idx);
                        await MembershipService.instance.updateMemberCoach(
                          uid: userId,
                          clubId: widget.clubId,
                          teamIds: tIds,
                          teamNames: tNames,
                        );
                      }
                    }
                  }
                  if (role == 'player') {
                    await _updateEventsAttendanceForPlayer(
                      userId,
                      teamName,
                      add: false,
                    );
                  }
                  AppLogger.instance.info('Membre retiré de l\'équipe', {
                    'userId': userId,
                    'teamId': widget.teamDoc.id,
                    'teamName': teamName,
                    'role': role,
                    'clubId': widget.clubId,
                  });
                },
              )
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilDisplayPage(userId: userId),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateEventsAttendanceForPlayer(
    String userId,
    String teamName, {
    required bool add,
  }) async {
    if (teamName.isEmpty) return;
    final eventsRef = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events);

    final List<QuerySnapshot> snaps = await Future.wait([
      eventsRef.where('teamName', isEqualTo: teamName).get(),
      eventsRef.where('teamNames', arrayContains: teamName).get(),
      eventsRef.where('allTeams', isEqualTo: true).get(),
    ]);

    final seen = <String>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final ref = doc.reference;
        if (add) {
          await ref.set({
            'teamMemberIds': FieldValue.arrayUnion([userId]),
            'attendance.$userId': 'none',
          }, SetOptions(merge: true));
        } else {
          await ref.set({
            'teamMemberIds': FieldValue.arrayRemove([userId]),
            'attendance.$userId': FieldValue.delete(),
          }, SetOptions(merge: true));
        }
      }
    }
  }
}
