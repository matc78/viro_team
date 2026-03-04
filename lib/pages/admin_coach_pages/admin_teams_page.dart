import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/team_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/viro_loader.dart';
import 'admin_teams_detail_page.dart';

class AdminTeamsPage extends StatefulWidget {
  final String clubId;
  const AdminTeamsPage({super.key, required this.clubId});

  @override
  State<AdminTeamsPage> createState() => _AdminTeamsPageState();
}

class _AdminTeamsPageState extends State<AdminTeamsPage> {
  final FirebaseFirestore _db = appFirestore;
  final TeamService _teamService = TeamService();
  String? _clubSport;
  String? _clubLogoUrl;
  String? _deletingTeamId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadClubInfo();
  }

  Future<void> _loadClubInfo() async {
    final doc = await _db.collection(FirebaseCollections.clubs).doc(widget.clubId).get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _clubSport = (data['sport'] as String?) ?? "";
      _clubLogoUrl = data['logoUrl'] as String?;
    });
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final categories = getCategoriesBySport(_clubSport ?? "");
    String category = categories.isNotEmpty ? categories.first : "Sénior";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nouvelle Équipe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Nom de l'équipe",
                hintText: "ex: Équipe A",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(
                labelText: "Catégorie",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => category = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  final teamRef = await _teamService.addTeam(
                    widget.clubId,
                    {
                      'name': nameController.text.trim(),
                      'category': category,
                      'playerIds': [],
                      'coachIds': [],
                      'pendingPlayerIds': [],
                      'createdAt': FieldValue.serverTimestamp(),
                    },
                  );
                  if (teamRef == null) throw Exception('Création échouée');
                  AppLogger.instance.info(
                    'Équipe créée',
                    {
                      'teamId': teamRef.id,
                      'teamName': nameController.text.trim(),
                      'category': category,
                      'clubId': widget.clubId,
                    },
                  );
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  AppLogger.instance.error(
                    'Erreur lors de la création de l\'équipe',
                    error: e,
                    context: {
                      'clubId': widget.clubId,
                      'teamName': nameController.text.trim(),
                    },
                  );
                }
              }
            },
            child: const Text("CRÉER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _fetchCoachNames(List<String> coachIds) async {
    if (coachIds.isEmpty) return [];
    final snap = await _db
        .collection(FirebaseCollections.users)
        .where(FieldPath.documentId, whereIn: coachIds)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      final first = (data['firstName'] as String? ?? "").trim();
      final last = (data['lastName'] as String? ?? "").trim().toUpperCase();
      final name = [first, last].where((e) => e.isNotEmpty).join(" ");
      return name.isEmpty ? "Coach" : name;
    }).toList();
  }

  static List<String> getCategoriesBySport(String sportName) {
    final sport = sportName.toLowerCase().trim().replaceAll('-', '');
    switch (sport) {
      case 'football':
        return [
          'U7',
          'U8',
          'U9',
          'U10',
          'U11',
          'U12',
          'U13',
          'U14',
          'U15',
          'U16',
          'U17',
          'U18',
          'U19',
          'Sénior',
          'Vétéran',
          'Féminines',
          'Loisir',
        ];
      case 'basketball':
        return [
          'U7',
          'U9',
          'U11',
          'U13',
          'U15',
          'U17',
          'U18',
          'U20',
          'Sénior',
          'Sénior +',
          'Loisir',
        ];
      case 'volleyball':
        return [
          'M7',
          'M9',
          'M11',
          'M13',
          'M15',
          'M18',
          'M21',
          'Sénior',
          'Loisir',
          'Soft',
        ];
      case 'handball':
        return [
          '-9',
          '-11',
          '-13',
          '-15',
          '-18',
          'Sénior',
          'Féminines',
          'Loisir',
        ];
      case 'rugby':
        return [
          'M6',
          'M8',
          'M10',
          'M12',
          'M14',
          'M16',
          'M19',
          'Sénior',
          'Vétéran (+35)',
          'Loisir',
        ];
      case 'tennis':
        return [
          'Galaxie Rouge',
          'Galaxie Orange',
          'Galaxie Vert',
          '11/12 ans',
          '13/14 ans',
          '15/16 ans',
          '17/18 ans',
          'Sénior',
          'Sénior +',
          'Loisir',
        ];
      case 'judo':
        return [
          'Éveil',
          'Mini-poussin',
          'Poussin',
          'Benjamin',
          'Minime',
          'Cadet',
          'Junior',
          'Sénior',
          'Vétéran',
        ];
      case 'natation':
        return [
          'Avenirs',
          'Benjamins',
          'Juniors 1',
          'Juniors 2',
          'Juniors 3',
          'Juniors 4',
          'Séniors',
          'Masters',
        ];
      default:
        return ['U13', 'U15', 'U17', 'Sénior', 'Loisir'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Gestion des Équipes"), centerTitle: true),
        body: const Center(child: Text("Non connecté")),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appFirestore.collection(FirebaseCollections.users).doc(userId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final rolesInClub = getAllUserRolesInClub(userData ?? {}, widget.clubId);
        final canCreateOrDelete =
            rolesInClub.contains('admin') || rolesInClub.contains('admin_fondateur');

        return Scaffold(
          appBar: AppBar(
            title: const Text("Gestion des Équipes"),
            centerTitle: true,
            actions: [
              if (canCreateOrDelete)
                IconButton(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit),
                  onPressed: () => setState(() {
                    _isEditing = !_isEditing;
                  }),
                ),
            ],
          ),
          body: AbsorbPointer(
        absorbing: _deletingTeamId != null,
        child: Stack(
          children: [
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
            StreamBuilder<List<DocumentSnapshot>>(
              stream: _teamService.watchTeamsByClub(widget.clubId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: FirebaseErrorHandler.buildErrorWidget(
                      context,
                      snapshot.error,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: ViroLoader(size: 50));
                }

                final teams = snapshot.data!;

                if (teams.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Aucune équipe pour le moment",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 140,
                  ),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final data = team.data() as Map<String, dynamic>;
                    final coachIds = List<String>.from(data['coachIds'] ?? []);
                    final playerIds = List<String>.from(
                      data['playerIds'] ?? [],
                    );
                    final playerCount = playerIds.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: ViroColors.borderColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
                          backgroundImage:
                              (_clubLogoUrl != null && _clubLogoUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(_clubLogoUrl!)
                              : null,
                          child: (_clubLogoUrl == null || _clubLogoUrl!.isEmpty)
                              ? const Icon(
                                  Icons.groups_rounded,
                                  color: ViroColors.primary,
                                )
                              : null,
                        ),
                        title: Text(
                          data['name'] ?? "Sans nom",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Catégorie : ${data['category']}"),
                            if (playerCount > 0)
                              Text(
                                "$playerCount joueur${playerCount > 1 ? 's' : ''}",
                              ),
                            FutureBuilder<List<String>>(
                              future: _fetchCoachNames(coachIds),
                              builder: (context, snapshot) {
                                final coaches = snapshot.data ?? [];
                                if (coaches.isEmpty) {
                                  return const Text("Coach(s) : non renseigné");
                                }
                                return Text("Coach(s) : ${coaches.join(', ')}");
                              },
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEditing)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: _deletingTeamId == team.id
                                    ? null
                                    : () => _confirmDeleteTeam(team),
                              )
                            else
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: ViroColors.borderColor,
                              ),
                          ],
                        ),
                        onTap: _isEditing
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamDetailsPage(
                                      clubId: widget.clubId,
                                      teamDoc: team,
                                    ),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                );
              },
            ),
            if (_deletingTeamId != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(color: ViroColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
          floatingActionButton: canCreateOrDelete && !_isEditing
              ? FloatingActionButton(
                  onPressed: _showCreateTeamDialog,
                  backgroundColor: ViroColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  Future<void> _confirmDeleteTeam(DocumentSnapshot teamDoc) async {
    final data = teamDoc.data() as Map<String, dynamic>? ?? {};
    final teamName = data['name'] ?? "cette équipe";
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer l'équipe ?"),
        content: Text("Supprimer $teamName et retirer tous ses membres ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _deleteTeam(teamDoc);
  }

  Future<void> _deleteTeam(DocumentSnapshot teamDoc) async {
    final data = teamDoc.data() as Map<String, dynamic>? ?? {};
    final String teamName = data['name'] ?? "";
    final String teamCategory = data['category'] ?? "";
    final List<String> playerIds =
        (data['playerIds'] as List?)?.whereType<String>().toList() ?? [];
    final List<String> coachIds =
        (data['coachIds'] as List?)?.whereType<String>().toList() ?? [];
    final memberIds = [...playerIds, ...coachIds];

    setState(() => _deletingTeamId = teamDoc.id);
    try {
      await _cleanupEvents(teamName, memberIds);

      // Mise à jour des profils membres (source unifiée : roles.player.clubs)
      for (final uid in memberIds) {
        final isCoach = coachIds.contains(uid);
        if (isCoach) {
          await _db.collection(FirebaseCollections.users).doc(uid).set({
            'coachedTeams': FieldValue.arrayRemove([
              {'teamId': teamDoc.id, 'teamName': teamName},
            ]),
            '_adminClubId': widget.clubId,
          }, SetOptions(merge: true));
        } else {
          await updatePlayerClubsForTeam(
            _db,
            uid,
            widget.clubId,
            add: false,
            teamId: teamDoc.id,
            teamName: teamName,
            teamCategory: teamCategory,
          );
        }
      }

      await teamDoc.reference.delete();
      AppLogger.instance.warning(
        'Équipe supprimée',
        {
          'teamId': teamDoc.id,
          'teamName': teamName,
          'clubId': widget.clubId,
          'category': teamCategory,
          'memberCount': memberIds.length,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Équipe supprimée : ${teamName.isEmpty ? teamDoc.id : teamName}",
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la suppression de l\'équipe',
        error: e,
        context: {
          'teamId': teamDoc.id,
          'teamName': teamName,
          'clubId': widget.clubId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingTeamId = null);
    }
  }

  Future<void> _cleanupEvents(String teamName, List<String> memberIds) async {
    if (teamName.isEmpty) return;
    final eventsRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.events);
    final snaps = await Future.wait([
      eventsRef.where('teamName', isEqualTo: teamName).get(),
      eventsRef.where('teamNames', arrayContains: teamName).get(),
    ]);
    final seen = <String>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final teamNames =
            (data['teamNames'] as List?)?.whereType<String>().toList() ?? [];
        final otherTeams = teamNames
            .where((t) => t != teamName)
            .toList(growable: false);
        final bool onlyThisTeam =
            otherTeams.isEmpty &&
            ((teamNames.length == 1 && teamNames.first == teamName) ||
                (teamNames.isEmpty && data['teamName'] == teamName));

        if (onlyThisTeam) {
          await doc.reference.delete();
          continue;
        }

        final updates = <String, dynamic>{
          'teamNames': FieldValue.arrayRemove([teamName]),
          'teamMemberIds': FieldValue.arrayRemove(memberIds),
        };
        if (data['teamName'] == teamName) {
          updates['teamName'] = FieldValue.delete();
        }
        for (final id in memberIds) {
          updates['attendance.$id'] = FieldValue.delete();
        }
        await doc.reference.set(updates, SetOptions(merge: true));
      }
    }
  }
}
