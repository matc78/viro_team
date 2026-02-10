import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
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
          // Pour la section Coachs : coach, admin et admin_fondateur peuvent être assignés à une équipe
          final allDocs = snapshot.data!.docs
              .map((doc) => doc as DocumentSnapshot<Map<String, dynamic>>)
              .toList();
          final List<DocumentSnapshot<Map<String, dynamic>>> clubMembers;
          if (role == 'coach') {
            final coaches =
                filterUsersByClub(allDocs, widget.clubId, role: 'coach');
            final admins =
                filterUsersByClub(allDocs, widget.clubId, role: 'admin');
            final seenIds = coaches.map((d) => d.id).toSet();
            clubMembers = [
              ...coaches,
              ...admins.where((doc) => seenIds.add(doc.id)),
            ];
          } else {
            clubMembers =
                filterUsersByClub(allDocs, widget.clubId, role: 'player');
          }

          final users = clubMembers
              .where((doc) => !existingIds.contains(doc.id))
              .toList();

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Aucun membre trouvé avec ce rôle dans le club."),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  role == 'player'
                      ? "Ajouter un Membre"
                      : "Ajouter un Coach / Admin",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    if (_isProcessing) {
                      return const ListTile(
                        title: Text("ça l'ajoute..."),
                        trailing: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final user = users[i].data() as Map<String, dynamic>;
                    final userId = users[i].id;
                    return ListTile(
                      leading: null,
                      title: UserDisplayTile(
                        userId: userId,
                        firstName: user['firstName'] as String?,
                        lastName: user['lastName'] as String?,
                        avatarUrl: effectiveAvatarUrl(user),
                        navigateOnTap: false,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: ViroColors.primary,
                      ),
                      onTap: () async {
                        if (_isProcessing) return;
                        setState(() => _isProcessing = true);
                        try {
                          String field = (role == 'player')
                              ? 'playerIds'
                              : 'coachIds';
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
                            final userUpdate = <String, dynamic>{
                              'coachedTeams': FieldValue.arrayUnion([
                                {
                                  'teamId': widget.teamDoc.id,
                                  'teamName': teamName,
                                },
                              ]),
                              '_adminClubId': widget.clubId,
                            };
                            await appFirestore
                                .collection(FirebaseCollections.users)
                                .doc(userId)
                                .set(userUpdate, SetOptions(merge: true));
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
                    );
                  },
                ),
              ),
            ],
          );
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
  }) {
    final isCoach = role == 'coach';
    final showAdd = canEdit &&
        (role != 'coach' || showAddWithoutEditMode);
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
              ),
            ),
        ],
      ),
    );

    final listWidget = ids.isEmpty
        ? const Center(
            child: Text(
              "Aucun membre dans cette section",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        : FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
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
                itemBuilder: (ctx, i) {
                  final userId = ids[i] as String;
                  final userData = userMap[userId];
                  if (userData == null) return const SizedBox();

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
                                String field = (role == 'player')
                                    ? 'playerIds'
                                    : 'coachIds';
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
                                  final userUpdate = <String, dynamic>{
                                    'coachedTeams':
                                        FieldValue.arrayRemove([
                                          {
                                            'teamId': widget.teamDoc.id,
                                            'teamName': teamName,
                                          },
                                        ]),
                                    '_adminClubId': widget.clubId,
                                  };
                                  await appFirestore
                                      .collection(FirebaseCollections.users)
                                      .doc(userId)
                                      .set(userUpdate, SetOptions(merge: true));
                                }
                                if (role == 'player') {
                                  await _updateEventsAttendanceForPlayer(
                                    userId,
                                    teamName,
                                    add: false,
                                  );
                                }
                                AppLogger.instance
                                    .info('Membre retiré de l\'équipe', {
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
                },
              );
            },
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
