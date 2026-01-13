import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_planning_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_teams_page.dart';
import 'package:viro_team/pages/admin_coach_pages/profil_request_page.dart';
import 'admin_members_page.dart';
import 'admin_profil_page.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _showAllRequests = false;
  String? _processingRequestId;

  // Récupération des données du club lié à l'admin
  Future<Map<String, dynamic>?> _getClubData() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    final clubId = userDoc.data()?['clubId'];

    if (clubId != null) {
      final clubDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .get();
      final data = clubDoc.data() ?? {};
      return {...data, 'id': clubId};
    }
    return null;
  }

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Tableau de bord"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProfilPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getClubData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final club = snapshot.data;
          final clubName = club?['name'] ?? "Mon Club";
          final clubId = club?['id'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bienvenue
                Text(
                  "Salut Coach ! 👋",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  clubName,
                  style: const TextStyle(
                    color: ViroColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 30),

                // Grille d'actions
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: clubId == null
                          ? null
                          : FirebaseFirestore.instance
                                .collection('users')
                                .where('clubId', isEqualTo: clubId)
                                .snapshots(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return _adminCard(
                          title: "Membres",
                          count: count == 0 ? "" : "$count",
                          icon: Icons.group_outlined,
                          color: Colors.orange,
                          onTap: () {
                            if (clubId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminMembersPage(
                                    clubId: clubId,
                                    clubName: clubName,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: clubId == null
                          ? null
                          : FirebaseFirestore.instance
                                .collection('clubs')
                                .doc(clubId)
                                .collection('teams')
                                .snapshots(),
                      builder: (context, snap) {
                        final teamCount = snap.data?.docs.length ?? 0;
                        return _adminCard(
                          title: "Équipes",
                          count: teamCount == 0 ? "" : "$teamCount",
                          icon: Icons.groups_rounded,
                          color: Colors.blue,
                          onTap: () {
                            if (clubId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminTeamsPage(clubId: clubId),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    _adminCard(
                      title: "Planning",
                      count: DateFormat(
                        'd MMM',
                        'fr_FR',
                      ).format(DateTime.now()),
                      icon: Icons.calendar_today_rounded,
                      color: Colors.green,
                      onTap: () {
                        if (clubId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminPlanningPage(clubId: clubId),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Erreur : ID du club introuvable"),
                            ),
                          );
                        }
                      },
                    ),
                    _adminCard(
                      title: "Paramètres",
                      count: "",
                      icon: Icons.settings_suggest_outlined,
                      color: Colors.grey,
                      onTap: () => print("Réglages club"),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                if (clubId != null) ...[
                  const Text(
                    "À ne pas manquer",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _buildJoinRequestsSection(clubId, clubName),
                ],
              ],
            ),
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
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'clubId': clubId,
          'clubName': clubName,
          'hasPendingRequest': false,
          'role': role ?? 'player',
        }, SetOptions(merge: true));

        // Ajouter l'utilisateur dans la liste des membres ou coachs du club
        if (clubId != null) {
          final field = (role == 'admin_fondateur' || role == 'coach')
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
