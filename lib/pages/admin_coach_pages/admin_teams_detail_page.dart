import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
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
  bool _isEditing = false;
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
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: ViroLoader(size: 40));
          final existingIds = role == 'coach' ? coachIds : playerIds;

          // Filtrer les utilisateurs du club avec le bon rôle
          final allDocs = snapshot.data!.docs;
          final clubMembers = filterUsersByClub(
            allDocs,
            widget.clubId,
            role: role == 'coach' ? 'coach' : 'player',
          );

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
                      ? "Ajouter un Licencié"
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
                    final formattedName = _formatName(
                      user['firstName'],
                      user['lastName'],
                    );
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(formattedName),
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
                          final userId = users[i].id;
                          await widget.teamDoc.reference.update({
                            field: FieldValue.arrayUnion([userId]),
                          });
                          final Map<String, dynamic> userUpdate = {
                            'teamIds': FieldValue.arrayUnion([
                              widget.teamDoc.id,
                            ]),
                          };
                          if (role == 'coach') {
                            userUpdate['coachedTeams'] = FieldValue.arrayUnion([
                              {
                                'teamId': widget.teamDoc.id,
                                'teamName': teamName,
                              },
                            ]);
                          }
                          if (teamName.isNotEmpty) {
                            userUpdate['teamNames'] = FieldValue.arrayUnion([
                              teamName,
                            ]);
                          }
                          if (teamCategory.isNotEmpty) {
                            userUpdate['categories'] = FieldValue.arrayUnion([
                              teamCategory,
                            ]);
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .set(userUpdate, SetOptions(merge: true));
                          if (role == 'player') {
                            await _updateEventsAttendanceForPlayer(
                              userId,
                              teamName,
                              add: true,
                            );
                          }
                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Erreur lors de l'ajout : $e"),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.teamDoc.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(body: ViroLoader(size: 80));

        final teamData = snapshot.data!.data() as Map<String, dynamic>;
        final List coachIds = teamData['coachIds'] ?? [];
        final List playerIds = teamData['playerIds'] ?? [];
        final String teamName = teamData['name'] ?? "";
        final String teamCategory = teamData['category'] ?? "";

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
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () => setState(() => _isEditing = !_isEditing),
              ),
            ],
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
                    ),
                    const Divider(height: 1, color: ViroColors.borderColor),
                    _buildMemberSection(
                      "Effectif (Licenciés)",
                      playerIds,
                      'player',
                      teamName,
                      teamCategory,
                      coachIds,
                      playerIds,
                    ),
                  ],
                ),
              ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.1),
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
  }

  Widget _buildMemberSection(
    String title,
    List ids,
    String role,
    String teamName,
    String teamCategory,
    List coachIds,
    List playerIds,
  ) {
    final isCoach = role == 'coach';
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
          if (role != 'coach' || _isEditing)
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
        : FutureBuilder<List<DocumentSnapshot>>(
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
                        color: ViroColors.borderColor.withOpacity(0.5),
                      ),
                    ),
                    child: ListTile(
                      visualDensity: VisualDensity.compact,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (userData['avatarUrl'] != null &&
                                (userData['avatarUrl'] as String).isNotEmpty)
                            ? NetworkImage(userData['avatarUrl'])
                            : null,
                        child:
                            (userData['avatarUrl'] == null ||
                                (userData['avatarUrl'] as String).isEmpty)
                            ? const Icon(Icons.person_outline, size: 18)
                            : null,
                      ),
                      title: Text(
                        _formatName(
                          userData['firstName'],
                          userData['lastName'],
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: _isEditing
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
                                final Map<String, dynamic> userUpdate = {
                                  'teamIds': FieldValue.arrayRemove([
                                    widget.teamDoc.id,
                                  ]),
                                };
                                if (role == 'coach') {
                                  userUpdate['coachedTeams'] =
                                      FieldValue.arrayRemove([
                                        {
                                          'teamId': widget.teamDoc.id,
                                          'teamName': teamName,
                                        },
                                      ]);
                                }
                                if (teamName.isNotEmpty) {
                                  userUpdate['teamNames'] =
                                      FieldValue.arrayRemove([teamName]);
                                }
                                if (teamCategory.isNotEmpty) {
                                  userUpdate['categories'] =
                                      FieldValue.arrayRemove([teamCategory]);
                                }
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .set(userUpdate, SetOptions(merge: true));
                                if (role == 'player') {
                                  await _updateEventsAttendanceForPlayer(
                                    userId,
                                    teamName,
                                    add: false,
                                  );
                                }
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

  String _formatName(dynamic firstName, dynamic lastName) {
    final fn = (firstName as String?)?.trim() ?? "";
    final ln = (lastName as String?)?.trim() ?? "";
    String cap(String v) =>
        v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
    final first = cap(fn);
    final last = ln.toUpperCase();
    final full = [first, last].where((e) => e.isNotEmpty).join(" ").trim();
    return full.isEmpty ? "Membre" : full;
  }

  Future<void> _updateEventsAttendanceForPlayer(
    String userId,
    String teamName, {
    required bool add,
  }) async {
    if (teamName.isEmpty) return;
    final eventsRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('events');

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
