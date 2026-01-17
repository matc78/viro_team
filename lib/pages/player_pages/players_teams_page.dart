import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/firebase_helpers.dart';
import '../profil_display_page.dart';

class PlayerTeamsPage extends StatelessWidget {
  final String clubId;

  const PlayerTeamsPage({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Mes Équipes"),
        centerTitle: true,
        backgroundColor: ViroColors.background,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .get(),
        builder: (context, clubSnap) {
          if (clubSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader());
          }
          final clubData = clubSnap.data?.data();
          final clubName = clubData?['name'] as String? ?? "Mon Club";
          final clubLogo = clubData?['logoUrl'] as String? ?? "";
          return StreamBuilder<QuerySnapshot>(
            // On récupère les équipes du club où l'utilisateur est dans la liste 'playerIds'
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(clubId)
                .collection('teams')
                .where('playerIds', arrayContains: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: Text("Erreur de chargement"));
              if (!snapshot.hasData) return const Center(child: ViroLoader());

              final teams = snapshot.data!.docs;

              if (teams.isEmpty) {
                return const Center(
                  child: Text(
                    "Tu n'es affecté à aucune équipe pour le moment.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final teamData = teams[index].data() as Map<String, dynamic>;
                  return _buildTeamCard(context, teamData, clubName, clubLogo);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    Map<String, dynamic> teamData,
    String clubName,
    String clubLogo,
  ) {
    final List<String> playerIds = ((teamData['playerIds'] ?? []) as List)
        .cast<String>();
    final List<String> coachIds = ((teamData['coachIds'] ?? []) as List)
        .cast<String>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        shape:
            const Border(), // Retire la bordure par défaut de l'ExpansionTile
        leading: CircleAvatar(
          backgroundColor: ViroColors.primary.withOpacity(0.1),
          backgroundImage: clubLogo.isNotEmpty ? CachedNetworkImageProvider(clubLogo) : null,
          child: clubLogo.isEmpty
              ? const Icon(Icons.shield_rounded, color: ViroColors.primary)
              : null,
        ),
        title: Text(
          teamData['name'] ?? "Équipe sans nom",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          clubName,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        children: [
          const Divider(),
          // Section COACHS
          FutureBuilder<List<DocumentSnapshot>>(
            future: coachIds.isEmpty
                ? Future.value(<DocumentSnapshot>[])
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
          FutureBuilder<List<DocumentSnapshot>>(
            future: playerIds.isEmpty
                ? Future.value(<DocumentSnapshot>[])
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
      leading: CircleAvatar(
        radius: 14,
        backgroundImage:
            (userData['avatarUrl'] != null &&
                (userData['avatarUrl'] as String).isNotEmpty)
            ? CachedNetworkImageProvider(userData['avatarUrl'] as String)
            : null,
        child:
            (userData['avatarUrl'] == null ||
                (userData['avatarUrl'] as String).isEmpty)
            ? const Icon(Icons.person, size: 14)
            : null,
      ),
      title: Text(
        "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}",
        style: const TextStyle(fontSize: 13),
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
