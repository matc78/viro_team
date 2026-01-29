import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_club_communication_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_equipment_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_loans_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_planning_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_teams_page.dart';
import 'package:viro_team/pages/admin_coach_pages/profil_request_page.dart';
import 'admin_members_page.dart';
import 'admin_profil_page.dart';
import 'package:intl/intl.dart';
import '../../constants/firebase_collections.dart';
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
  String? _processingLoanRequestId;

  String _formatName(
    dynamic firstName,
    dynamic lastName, {
    String fallback = "Membre",
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

              return Stack(
                children: [
                  // Logo en arrière-plan avec opacité
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 0.12,
                      child: Image.asset(
                        'assets/logo/logo_seul.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Contenu principal
                  SingleChildScrollView(
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
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.5,
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
                        _buildLoanRequestsSection(clubId),
                        const SizedBox(height: 24),
                        _buildUpcomingLoans(clubId),
                        const SizedBox(height: 24),
                        _buildLoanPreparationReminders(clubId),
                        const SizedBox(height: 24),
                        _buildLoanReturnReminders(clubId),
                        const SizedBox(height: 30),

                        // Grille d'actions (cards en bas du body)
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          children: [
                            _MembersCountCard(
                              clubId: clubId,
                              clubName: clubName,
                            ),
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
                                    builder: (_) => AdminClubCommunicationPage(
                                      clubId: clubId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _adminCard(
                              title: "Équipement",
                              count: "",
                              icon: Icons.inventory_2,
                              color: ViroColors.primary,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdminEquipmentPage(
                                      clubId: clubId,
                                      sport: club['sport'] as String?,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _adminCard(
                              title: "Prêts",
                              count: "",
                              icon: Icons.handshake_outlined,
                              color: ViroColors.accent,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminLoansPage(clubId: clubId),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
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
                  ),
                ],
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
                  fallback: data['userId'] ?? "Membre",
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
                              role == 'coach' ? "Entraîneur" : "Membre",
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

  Widget _buildLoanRequestsSection(String clubId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          // Vérifier si c'est une erreur d'index manquant
          if (error.contains('index') || error.contains('requires an index')) {
            return _infoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Index Firestore requis",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Un index composite est nécessaire pour cette requête.",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Erreur: $error",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return _infoCard(
            child: Text(
              "Erreur de chargement: $error",
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _infoCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trier côté client par createdAt (descendant)
        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descendant
          });

        return _infoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.request_quote, color: ViroColors.warning),
                  const SizedBox(width: 8),
                  const Text(
                    "Demandes de prêt",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${docs.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: ViroColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sortedDocs.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final playerName = data['playerName'] as String? ?? 'Joueur';
                final quantity = data['quantity'] as int? ?? 1;
                final duration = data['duration'] as int? ?? 0;
                final durationUnit = data['durationUnit'] as String? ?? 'jour';
                final reason = data['reason'] as String? ?? '';
                final requestedPickupDate =
                    data['requestedPickupDate'] as Timestamp?;
                final createdAt = data['createdAt'] as Timestamp?;

                String durationUnitLabel(String unit) {
                  switch (unit) {
                    case 'jour':
                      return 'jour(s)';
                    case 'semaine':
                      return 'semaine(s)';
                    case 'mois':
                      return 'mois';
                    default:
                      return unit;
                  }
                }

                final dateText = createdAt != null
                    ? "${createdAt.toDate().day}/${createdAt.toDate().month}"
                    : "";

                return InkWell(
                  onTap: () {
                    // Optionnel : navigation vers une page de détail
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
                                equipmentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Chip(
                              label: const Text(
                                "En attente",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: ViroColors.warning,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Demandé par $playerName",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Quantité: $quantity • Durée: $duration ${durationUnitLabel(durationUnit)}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (requestedPickupDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Récupération: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(requestedPickupDate.toDate())}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Raison:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
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
                                onPressed: _processingLoanRequestId == doc.id
                                    ? null
                                    : () => _handleLoanRequest(
                                        doc.id,
                                        clubId,
                                        data,
                                        accept: false,
                                      ),
                                child: const Text("Refuser"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _processingLoanRequestId == doc.id
                                    ? null
                                    : () => _handleLoanRequest(
                                        doc.id,
                                        clubId,
                                        data,
                                        accept: true,
                                      ),
                                child: _processingLoanRequestId == doc.id
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLoanRequest(
    String requestId,
    String clubId,
    Map<String, dynamic> requestData, {
    required bool accept,
  }) async {
    setState(() => _processingLoanRequestId = requestId);
    try {
      if (accept) {
        await _acceptLoanRequest(requestId, clubId, requestData);
      } else {
        await _refuseLoanRequest(requestId, clubId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _processingLoanRequestId = null);
    }
  }

  Future<void> _acceptLoanRequest(
    String requestId,
    String clubId,
    Map<String, dynamic> requestData,
  ) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Accepter la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous accepter cette demande de prêt ?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Message (optionnel)",
                hintText: "Message pour le joueur",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Accepter"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _processingLoanRequestId = null);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final requestedPickupDate =
          requestData['requestedPickupDate'] as Timestamp?;
      final duration = requestData['duration'] as int? ?? 0;
      final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
      final equipmentId = requestData['equipmentId'] as String? ?? '';
      final equipmentName =
          requestData['equipmentName'] as String? ?? 'Équipement';
      final quantity = requestData['quantity'] as int? ?? 1;
      final playerId = requestData['playerId'] as String? ?? '';
      final playerName = requestData['playerName'] as String? ?? 'Joueur';

      if (requestedPickupDate == null) {
        throw Exception("Date de récupération manquante");
      }

      // Calculer la date de retour
      final pickupDate = requestedPickupDate.toDate();
      int durationDays = duration;
      if (durationUnit == 'semaine') {
        durationDays = duration * 7;
      } else if (durationUnit == 'mois') {
        durationDays = duration * 30;
      }
      final returnDate = pickupDate.add(Duration(days: durationDays));

      // Créer le prêt actif
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .add({
            'equipmentId': equipmentId,
            'equipmentName': equipmentName,
            'quantity': quantity,
            'borrowerId': playerId,
            'borrowerName': playerName,
            'lentAt': requestedPickupDate,
            'dueAt': Timestamp.fromDate(returnDate),
            'status': 'active',
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Mettre à jour la demande
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'accepted',
            'adminResponse': responseController.text.trim().isNotEmpty
                ? responseController.text.trim()
                : null,
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande acceptée et prêt créé avec succès !"),
            backgroundColor: ViroColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _refuseLoanRequest(String requestId, String clubId) async {
    final responseController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Refuser la demande"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Voulez-vous refuser cette demande de prêt ?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Raison du refus *",
                hintText: "Expliquez pourquoi la demande est refusée",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: responseController.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ViroColors.error),
            child: const Text("Refuser"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _processingLoanRequestId = null);
      return;
    }

    if (responseController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez indiquer une raison de refus."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      setState(() => _processingLoanRequestId = null);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .doc(requestId)
          .update({
            'status': 'refused',
            'adminResponse': responseController.text.trim(),
            'respondedAt': FieldValue.serverTimestamp(),
            'respondedBy': currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande refusée."),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            backgroundColor: ViroColors.error,
          ),
        );
      }
      rethrow;
    }
  }

  Widget _buildUpcomingLoans(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;

        // Filtrer les prêts acceptés dont la date de récupération est dans le futur
        final upcomingLoans = requests.where((doc) {
          final data = doc.data();
          final requestedPickupDate = data['requestedPickupDate'] as Timestamp?;
          if (requestedPickupDate == null) return false;
          final pickupDate = requestedPickupDate.toDate();
          final pickupDay = DateTime(
            pickupDate.year,
            pickupDate.month,
            pickupDate.day,
          );
          return pickupDay.isAfter(today);
        }).toList();

        if (upcomingLoans.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trier par date de récupération (ascendant)
        upcomingLoans.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = (aData['requestedPickupDate'] as Timestamp?)?.toDate();
          final bDate = (bData['requestedPickupDate'] as Timestamp?)?.toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

        return _infoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: ViroColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    "Prochains prêts",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...upcomingLoans.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final quantity = data['quantity'] as int? ?? 1;
                final borrowerName = data['playerName'] as String? ?? 'Joueur';
                final requestedPickupDate =
                    data['requestedPickupDate'] as Timestamp?;
                final duration = data['duration'] as int? ?? 0;
                final durationUnit = data['durationUnit'] as String? ?? 'jour';

                String durationUnitLabel(String unit) {
                  switch (unit) {
                    case 'jour':
                      return 'jour(s)';
                    case 'semaine':
                      return 'semaine(s)';
                    case 'mois':
                      return 'mois';
                    default:
                      return unit;
                  }
                }

                final pickupDate = requestedPickupDate?.toDate();
                final daysUntilPickup = pickupDate?.difference(today).inDays;

                return Padding(
                  key: ValueKey(doc.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ViroColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              color: ViroColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$equipmentName (x$quantity)",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Joueur: $borrowerName",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (pickupDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Récupération: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(pickupDate)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (daysUntilPickup != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            daysUntilPickup == 1
                                ? "Dans 1 jour"
                                : "Dans $daysUntilPickup jours",
                            style: TextStyle(
                              fontSize: 12,
                              color: ViroColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          "Durée: $duration ${durationUnitLabel(durationUnit)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanPreparationReminders(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('status', isEqualTo: 'active')
          .where('lentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('lentAt', isLessThan: Timestamp.fromDate(tomorrow))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final loans = snapshot.data!.docs;

        return _infoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: ViroColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    "Prêts à récupérer aujourd'hui",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...loans.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final quantity = data['quantity'] as int? ?? 1;
                final borrowerName =
                    data['borrowerName'] as String? ?? 'Joueur';

                return Padding(
                  key: ValueKey(doc.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: ViroColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$equipmentName (x$quantity) - $borrowerName",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanReturnReminders(String clubId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inThreeDays = today.add(const Duration(days: 3));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('status', isEqualTo: 'active')
          .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('dueAt', isLessThanOrEqualTo: Timestamp.fromDate(inThreeDays))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final loans = snapshot.data!.docs;

        // Trier côté client par dueAt (ascendant)
        final sortedLoans = loans.toList()
          ..sort((a, b) {
            final aDue = a.data()['dueAt'] as Timestamp?;
            final bDue = b.data()['dueAt'] as Timestamp?;
            if (aDue == null && bDue == null) return 0;
            if (aDue == null) return 1;
            if (bDue == null) return -1;
            return aDue.compareTo(bDue); // Ascendant
          });

        return _infoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: ViroColors.warning),
                  const SizedBox(width: 8),
                  const Text(
                    "Retours de prêt à venir",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sortedLoans.map((doc) {
                final data = doc.data();
                final equipmentName =
                    data['equipmentName'] as String? ?? 'Équipement';
                final quantity = data['quantity'] as int? ?? 1;
                final borrowerName =
                    data['borrowerName'] as String? ?? 'Joueur';
                final dueAt = data['dueAt'] as Timestamp?;

                final dueDate = dueAt?.toDate();
                final isToday =
                    dueDate != null &&
                    DateTime(dueDate.year, dueDate.month, dueDate.day) == today;

                return Padding(
                  key: ValueKey(doc.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        isToday
                            ? Icons.warning_amber_rounded
                            : Icons.calendar_today,
                        color: isToday ? ViroColors.error : ViroColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$equipmentName (x$quantity) - $borrowerName",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                            if (dueDate != null)
                              Text(
                                isToday
                                    ? "Retour aujourd'hui"
                                    : "Retour le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(dueDate)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isToday
                                      ? ViroColors.error
                                      : Colors.grey[700],
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
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
