import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_club_communication_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_planning_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_teams_page.dart';
import 'package:viro_team/pages/admin_coach_pages/profil_request_page.dart';
import 'admin_members_page.dart';
import 'admin_profil_page.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/profile_switcher_dialog.dart';
import '../../widget/sport_score_widget.dart';
import '../../widget/sport_timer_widget.dart';
import '../add_profile_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _showAllRequests = false;
  String? _processingRequestId;

  String _formatName(
    dynamic firstName,
    dynamic lastName, {
    String fallback = "Licencié",
  }) {
    final fn = (firstName as String?)?.trim();
    final ln = (lastName as String?)?.trim();
    if ((fn == null || fn.isEmpty) && (ln == null || ln.isEmpty)) {
      return fallback;
    }

    String capitalize(String value) {
      if (value.isEmpty) return value;
      return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }

    final first = fn != null ? capitalize(fn) : "";
    final last = ln != null ? ln.toUpperCase() : "";
    return [first, last].where((e) => e.isNotEmpty).join(" ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: const Text("Tableau de bord"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Ajouter un profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProfilePage()),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: user != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .snapshots()
                : null,
            builder: (context, snap) {
              final avatarUrl = snap.data?.data()?['avatarUrl'] as String?;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminProfilPage()),
                  );
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (_) => const ProfileSwitcherDialog(),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          imageBuilder: (context, imageProvider) =>
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: ViroColors.primary.withOpacity(
                                  0.1,
                                ),
                                backgroundImage: imageProvider,
                              ),
                          placeholder: (context, url) => CircleAvatar(
                            radius: 16,
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 16,
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: ViroColors.primary,
                            ),
                          ),
                          memCacheWidth: 64,
                          memCacheHeight: 64,
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: ViroColors.primary.withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: ViroColors.primary,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: user != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .snapshots()
            : null,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Extraire le clubId depuis le document utilisateur
          final userData = userSnapshot.data?.data();
          final activeContext =
              userData?['activeContext'] as Map<String, dynamic>?;
          final clubId =
              activeContext?['clubId'] as String? ??
              userData?['clubId'] as String?;

          // Si pas de clubId, afficher un message
          if (clubId == null) {
            return const Center(
              child: Text("Aucun club associé à votre compte"),
            );
          }

          // Récupérer les données du club
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(clubId)
                .snapshots(),
            builder: (context, clubSnapshot) {
              if (clubSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final clubData = clubSnapshot.data?.data() ?? {};
              final club = {...clubData, 'id': clubId};
              final clubName = club['name'] ?? "Mon Club";

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bienvenue avec Chronomètre
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Salut Coach ! 👋",
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              Text(
                                clubName,
                                style: const TextStyle(
                                  color: ViroColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.5,
                            ),
                            child: SportTimerWidget(
                              sport: club['sport'] as String?,
                              clubId: clubId,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Scoreur adaptatif selon le sport
                    SportScoreWidget(
                      sport: club['sport'] as String?,
                      clubId: clubId,
                    ),

                    const SizedBox(height: 20),

                    // Grille d'actions
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      children: [
                        _MembersCountCard(clubId: clubId, clubName: clubName),
                        _TeamsCountCard(clubId: clubId),
                        _adminCard(
                          title: "Planning",
                          count: DateFormat(
                            'd MMM',
                            'fr_FR',
                          ).format(DateTime.now()),
                          icon: Icons.calendar_today_rounded,
                          color: ViroColors.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminPlanningPage(clubId: clubId),
                              ),
                            );
                          },
                        ),
                        _adminCard(
                          title: "Communiquer",
                          count: "",
                          icon: Icons.campaign_rounded,
                          color: ViroColors.accent,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminClubCommunicationPage(clubId: clubId),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "À ne pas manquer",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildJoinRequestsSection(clubId, clubName),
                    const SizedBox(height: 24),
                    if ((club['logoUrl'] as String?)?.isNotEmpty ?? false)
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: CachedNetworkImageProvider(
                                club['logoUrl'] as String,
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              clubName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _adminCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _AdminCard(
      title: title,
      count: count,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }

  Widget _buildJoinRequestsSection(String clubId, String clubName) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('join_requests')
          .where('clubId', isEqualTo: clubId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _infoCard(
            child: const Text(
              "Erreur de chargement des demandes.",
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _infoCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        // tri côté client pour éviter d'imposer un index Firestore
        docs.sort((a, b) {
          final ta = a.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          final tb = b.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          return tb.compareTo(ta); // plus récent en premier
        });

        if (docs.isEmpty) {
          return _infoCard(
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text("Aucune demande en attente."),
            ),
          );
        }

        final toShow = _showAllRequests ? docs : docs.take(2).toList();
        return _infoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...toShow.map((doc) {
                final data = doc.data();
                final requester = _formatName(
                  data['firstName'],
                  data['lastName'],
                  fallback: data['userId'] ?? "Licencié",
                );
                final role = data['roleRequested'] ?? "player";
                final message = data['message'] ?? "";
                final createdAt = data['createdAt'] as Timestamp?;
                final dateText = createdAt != null
                    ? "${createdAt.toDate().day}/${createdAt.toDate().month}"
                    : "";
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfilRequestPage(
                          requestId: doc.id,
                          userId: data['userId'],
                          clubId: clubId,
                          clubName: clubName,
                          roleRequested: data['roleRequested'],
                          message: message,
                          firstName: data['firstName'],
                          lastName: data['lastName'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ViroColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                requester,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              role == 'coach' ? "Entraîneur" : "Licencié",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                        if (dateText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Reçue le $dateText",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _processingRequestId == doc.id
                                    ? null
                                    : () => _handleRequest(
                                        doc.id,
                                        data['userId'],
                                        accept: false,
                                      ),
                                child: const Text("Refuser"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _processingRequestId == doc.id
                                    ? null
                                    : () => _handleRequest(
                                        doc.id,
                                        data['userId'],
                                        accept: true,
                                        clubId: clubId,
                                        clubName: clubName,
                                        role: data['roleRequested'],
                                      ),
                                child: _processingRequestId == doc.id
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text("Accepter"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (docs.length > 2)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _showAllRequests = !_showAllRequests;
                    }),
                    icon: Icon(
                      _showAllRequests
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    label: Text(
                      _showAllRequests
                          ? "Voir moins"
                          : "Voir toutes les demandes (${docs.length})",
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRequest(
    String requestId,
    String? userId, {
    required bool accept,
    String? clubId,
    String? clubName,
    String? role,
  }) async {
    if (userId == null) return;
    setState(() => _processingRequestId = requestId);
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('join_requests')
          .doc(requestId);

      if (accept) {
        await requestRef.update({
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        // Récupérer les données utilisateur existantes
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final userData = userDoc.data() ?? {};
        final roles = userData['roles'] as Map<String, dynamic>? ?? {};
        final activeContext =
            userData['activeContext'] as Map<String, dynamic>?;

        // Déterminer le rôle réel (normaliser admin_fondateur en admin)
        final normalizedRole = (role == 'admin_fondateur')
            ? 'admin'
            : (role ?? 'player');

        // Construire la nouvelle structure roles sans écraser
        final Map<String, dynamic> updatedRoles = Map<String, dynamic>.from(
          roles,
        );

        if (normalizedRole == 'player') {
          // Player : ajouter le club à la liste des clubs (peut avoir plusieurs clubs)
          final existingPlayer = roles['player'] as Map<String, dynamic>?;

          if (existingPlayer == null) {
            // Premier club : créer la structure avec liste de clubs
            // Récupérer la licence depuis les données de la demande si disponible
            final requestDoc = await FirebaseFirestore.instance
                .collection('join_requests')
                .doc(requestId)
                .get();
            final requestData = requestDoc.data() ?? {};
            final license = requestData['license'] as String?;

            updatedRoles['player'] = {
              'clubs': [
                {
                  'clubId': clubId,
                  'teamIds': [],
                  if (license != null && license.isNotEmpty) 'license': license,
                },
              ],
            };
          } else {
            // Ajouter le club à la liste existante
            List<Map<String, dynamic>> clubsList;

            // Vérifier si c'est la nouvelle structure avec "clubs"
            if (existingPlayer['clubs'] is List) {
              clubsList = (existingPlayer['clubs'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList();
            }
            // Migration depuis l'ancienne structure (clubId direct)
            else if (existingPlayer['clubId'] != null) {
              clubsList = [
                {
                  'clubId': existingPlayer['clubId'],
                  'teamIds': existingPlayer['teamIds'] ?? [],
                  if (existingPlayer['license'] != null)
                    'license': existingPlayer['license'],
                },
              ];
            } else {
              clubsList = [];
            }

            // Vérifier qu'on n'ajoute pas un doublon
            if (!clubsList.any((c) => c['clubId'] == clubId)) {
              // Récupérer la licence depuis les données de la demande si disponible
              final requestDoc = await FirebaseFirestore.instance
                  .collection('join_requests')
                  .doc(requestId)
                  .get();
              final requestData = requestDoc.data() ?? {};
              final license = requestData['license'] as String?;

              clubsList.add({
                'clubId': clubId,
                'teamIds': [],
                if (license != null && license.isNotEmpty) 'license': license,
              });
            }

            // Préserver les autres champs (comme license)
            updatedRoles['player'] = {...existingPlayer, 'clubs': clubsList};
          }
        } else if (normalizedRole == 'coach') {
          // Coach : ajouter à la liste
          final existingCoaches =
              (roles['coach'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          // Vérifier qu'on n'ajoute pas un doublon
          if (!existingCoaches.any((c) => c['clubId'] == clubId)) {
            existingCoaches.add({'clubId': clubId, 'teams': []});
            updatedRoles['coach'] = existingCoaches;
          }
        } else if (normalizedRole == 'admin') {
          // Admin : ajouter à la liste de clubIds
          final existingAdmins =
              (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
          if (!existingAdmins.contains(clubId)) {
            existingAdmins.add(clubId!);
            updatedRoles['admin'] = existingAdmins;
          }
        }

        // Définir activeContext si c'est le premier profil
        Map<String, dynamic>? newActiveContext;
        if (activeContext == null || activeContext.isEmpty) {
          newActiveContext = {'role': normalizedRole, 'clubId': clubId};
        } else {
          // Garder le contexte actuel
          newActiveContext = Map<String, dynamic>.from(activeContext);
        }

        // Mettre à jour le document utilisateur
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'hasPendingRequest': false,
          'roles': updatedRoles,
          'activeContext': newActiveContext,
        }, SetOptions(merge: true));

        // Ajouter l'utilisateur dans la liste des membres ou coachs du club
        if (clubId != null) {
          final field = (normalizedRole == 'admin' || normalizedRole == 'coach')
              ? 'coaches'
              : 'members';
          await FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .update({
                field: FieldValue.arrayUnion([userId]),
              });
        }
      } else {
        await requestRef.update({
          'status': 'refused',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'hasPendingRequest': false,
        }, SetOptions(merge: true));
      }

      // Supprime la demande (acceptée ou refusée) pour nettoyer la liste
      await requestRef.delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Action impossible : $e")));
    } finally {
      if (mounted) setState(() => _processingRequestId = null);
    }
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (count.isNotEmpty)
              Text(
                count,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _infoCard extends StatelessWidget {
  final Widget child;
  const _infoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: child,
    );
  }
}

// Widgets extraits pour optimiser les rebuilds
class _MembersCountCard extends StatelessWidget {
  final String clubId;
  final String clubName;

  const _MembersCountCard({required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        // Filtrer les membres du club côté client
        final allDocs = snap.data?.docs ?? [];
        final clubMembers = filterUsersByClub(allDocs, clubId);
        final count = clubMembers.length;
        return _AdminCard(
          title: "Membres",
          count: count == 0 ? "" : "$count",
          icon: Icons.group_outlined,
          color: ViroColors.accent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AdminMembersPage(clubId: clubId, clubName: clubName),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamsCountCard extends StatelessWidget {
  final String clubId;

  const _TeamsCountCard({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('teams')
          .snapshots(),
      builder: (context, snap) {
        final teamCount = snap.data?.docs.length ?? 0;
        return _AdminCard(
          title: "Équipes",
          count: teamCount == 0 ? "" : "$teamCount",
          icon: Icons.groups_rounded,
          color: ViroColors.primary,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminTeamsPage(clubId: clubId)),
            );
          },
        );
      },
    );
  }
}
