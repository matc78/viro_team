import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';

class PlayerTeamsPage extends StatefulWidget {
  final String clubId;

  const PlayerTeamsPage({super.key, required this.clubId});

  @override
  State<PlayerTeamsPage> createState() => _PlayerTeamsPageState();
}

class _PlayerTeamsPageState extends State<PlayerTeamsPage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Extraire tous les clubIds du joueur depuis roles
  List<String> _extractClubIds(Map<String, dynamic>? userData) {
    final Set<String> clubIdsSet = {};
    final roles = userData?['roles'] as Map<String, dynamic>? ?? {};

    // Player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        for (var club in clubs) {
          final clubId = club['clubId'] as String?;
          if (clubId != null) clubIdsSet.add(clubId);
        }
      }
      // Ancienne structure : clubId direct (compatibilité)
      else {
        final playerClubId = playerData['clubId'] as String?;
        if (playerClubId != null) clubIdsSet.add(playerClubId);
      }
    }

    // Fallback pour compatibilité
    final legacyClubId = userData?['clubId'] as String?;
    if (legacyClubId != null) clubIdsSet.add(legacyClubId);

    // Ajouter aussi le clubId passé en paramètre pour compatibilité
    if (widget.clubId.isNotEmpty) clubIdsSet.add(widget.clubId);

    return clubIdsSet.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Mes Équipes"),
        centerTitle: true,
        backgroundColor: ViroColors.background,
        elevation: 0,
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUserId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: ViroLoader());
              }
              if (!userSnapshot.hasData) {
                return const Center(child: Text("Erreur de chargement"));
              }

              final userData = userSnapshot.data?.data();
              final clubIds = _extractClubIds(userData);

              if (clubIds.isEmpty) {
                return const Center(
                  child: Text(
                    "Tu n'es affecté à aucun club pour le moment.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return _buildTeamsList(clubIds);
            },
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

  Widget _buildTeamsList(List<String> clubIds) {
    // Créer les streams pour chaque club
    final streams = clubIds.map((clubId) {
      return FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('teams')
          .where('playerIds', arrayContains: _currentUserId)
          .snapshots();
    }).toList();

    // Utiliser des StreamBuilder imbriqués pour combiner les équipes
    return _buildCombinedTeamsStreams(streams, clubIds);
  }

  // Construire des StreamBuilder imbriqués pour combiner les streams
  Widget _buildCombinedTeamsStreams(
    List<Stream<QuerySnapshot>> streams,
    List<String> clubIds,
  ) {
    if (streams.isEmpty) {
      return const Center(
        child: Text(
          "Tu n'es affecté à aucune équipe pour le moment.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (streams.length == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot) {
          return _buildTeamsFromSnapshots([snapshot.data], clubIds);
        },
      );
    }

    if (streams.length == 2) {
      return StreamBuilder<QuerySnapshot>(
        stream: streams[0],
        builder: (context, snapshot0) {
          return StreamBuilder<QuerySnapshot>(
            stream: streams[1],
            builder: (context, snapshot1) {
              return _buildTeamsFromSnapshots([
                snapshot0.data,
                snapshot1.data,
              ], clubIds);
            },
          );
        },
      );
    }

    // Pour 3 clubs ou plus
    return StreamBuilder<QuerySnapshot>(
      stream: streams[0],
      builder: (context, snapshot0) {
        return StreamBuilder<QuerySnapshot>(
          stream: streams[1],
          builder: (context, snapshot1) {
            if (streams.length == 3) {
              return StreamBuilder<QuerySnapshot>(
                stream: streams[2],
                builder: (context, snapshot2) {
                  return _buildTeamsFromSnapshots([
                    snapshot0.data,
                    snapshot1.data,
                    snapshot2.data,
                  ], clubIds);
                },
              );
            }
            // Pour plus de 3 clubs, traiter les 3 premiers
            return _buildTeamsFromSnapshots([
              snapshot0.data,
              snapshot1.data,
              if (streams.length > 2) null,
            ], clubIds.take(3).toList());
          },
        );
      },
    );
  }

  // Construire la liste d'équipes à partir des snapshots
  Widget _buildTeamsFromSnapshots(
    List<QuerySnapshot?>? snapshots,
    List<String> clubIds,
  ) {
    if (snapshots == null || snapshots.isEmpty) {
      return const Center(child: ViroLoader());
    }

    // Combiner toutes les équipes avec leur clubId
    final List<Map<String, dynamic>> allTeamsWithClub = [];
    for (int i = 0; i < snapshots.length && i < clubIds.length; i++) {
      final snapshot = snapshots[i];
      if (snapshot == null) continue;
      final clubId = clubIds[i];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allTeamsWithClub.add({
          'teamId': doc.id,
          'teamData': data,
          'clubId': clubId,
        });
      }
    }

    if (allTeamsWithClub.isEmpty) {
      return const Center(
        child: Text(
          "Tu n'es affecté à aucune équipe pour le moment.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 140),
      itemCount: allTeamsWithClub.length,
      itemBuilder: (context, index) {
        final teamInfo = allTeamsWithClub[index];
        final teamData = teamInfo['teamData'] as Map<String, dynamic>;
        final clubId = teamInfo['clubId'] as String;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .get(),
          builder: (context, clubSnap) {
            final clubData = clubSnap.data?.data() as Map<String, dynamic>?;
            final clubName = clubData?['name'] as String? ?? "Mon Club";
            final clubLogo = clubData?['logoUrl'] as String? ?? "";
            return _buildTeamCard(
              context,
              teamData,
              clubName,
              clubLogo,
              clubId,
            );
          },
        );
      },
    );
  }

  // Générer une couleur unique par clubId
  Color _getClubColor(String clubId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
    ];
    final index = clubId.hashCode % colors.length;
    return colors[index.abs()];
  }

  Widget _buildTeamCard(
    BuildContext context,
    Map<String, dynamic> teamData,
    String clubName,
    String clubLogo,
    String clubId,
  ) {
    final clubColor = _getClubColor(clubId);
    final List<String> playerIds = ((teamData['playerIds'] ?? []) as List)
        .cast<String>();
    final List<String> coachIds = ((teamData['coachIds'] ?? []) as List)
        .cast<String>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: clubColor.withOpacity(0.3), width: 2),
      ),
      child: ExpansionTile(
        shape:
            const Border(), // Retire la bordure par défaut de l'ExpansionTile
        leading: CircleAvatar(
          backgroundColor: clubColor.withOpacity(0.1),
          backgroundImage: clubLogo.isNotEmpty
              ? CachedNetworkImageProvider(clubLogo)
              : null,
          child: clubLogo.isEmpty
              ? Icon(Icons.shield_rounded, color: clubColor)
              : null,
        ),
        title: Text(
          teamData['name'] ?? "Équipe sans nom",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: clubColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                clubName,
                style: TextStyle(
                  fontSize: 12,
                  color: clubColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        children: [
          const Divider(),
          // Section COACHS
          FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            future: coachIds.isEmpty
                ? Future.value(<DocumentSnapshot<Map<String, dynamic>>>[])
                : fetchUsersBatch(coachIds),
            builder: (context, coachSnap) {
              if (!coachSnap.hasData) {
                return const Center(
                  child: SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final coachDocs = coachSnap.data!;
              final coachMap = {
                for (var doc in coachDocs)
                  doc.id: doc.data() as Map<String, dynamic>,
              };
              return _buildMemberSection(
                context,
                "Staff / Coachs",
                coachIds,
                coachMap,
                isCoach: true,
              );
            },
          ),
          const SizedBox(height: 10),
          // Section JOUEURS
          FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            future: playerIds.isEmpty
                ? Future.value(<DocumentSnapshot<Map<String, dynamic>>>[])
                : fetchUsersBatch(playerIds),
            builder: (context, playerSnap) {
              if (!playerSnap.hasData) {
                return const Center(
                  child: SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final playerDocs = playerSnap.data!;
              final playerMap = {
                for (var doc in playerDocs)
                  doc.id: doc.data() as Map<String, dynamic>,
              };
              return _buildMemberSection(
                context,
                "Coéquipiers",
                playerIds,
                playerMap,
                isCoach: false,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMemberSection(
    BuildContext context,
    String title,
    List<String> ids,
    Map<String, Map<String, dynamic>> userMap, {
    required bool isCoach,
  }) {
    if (ids.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isCoach ? Colors.orange : ViroColors.primary,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...ids.map((id) {
          final userData = userMap[id];
          if (userData == null) return const SizedBox();
          return _MemberTile(userData: userData, userId: id);
        }),
      ],
    );
  }
}

// Widget pour afficher un membre avec les données pré-chargées
class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const _MemberTile({required this.userData, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: null,
      title: UserDisplayTile(
        userId: userId,
        firstName: userData['firstName'] as String?,
        lastName: userData['lastName'] as String?,
        avatarUrl: userData['avatarUrl'] as String?,
        navigateOnTap: false,
        textStyle: const TextStyle(fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilDisplayPage(userId: userId)),
        );
      },
    );
  }
}
