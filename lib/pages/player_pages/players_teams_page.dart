import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
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
        future:
            FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
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
                  return _buildTeamCard(
                    context,
                    teamData,
                    clubName,
                    clubLogo,
                  );
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
    final List playerIds = teamData['playerIds'] ?? [];
    final List coachIds = teamData['coachIds'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        shape:
            const Border(), // Retire la bordure par défaut de l'ExpansionTile
        leading: CircleAvatar(
          backgroundColor: ViroColors.primary.withOpacity(0.1),
          backgroundImage:
              clubLogo.isNotEmpty ? NetworkImage(clubLogo) : null,
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
          _buildMemberSection(
            context,
            "Staff / Coachs",
            coachIds,
            isCoach: true,
          ),
          const SizedBox(height: 10),
          // Section JOUEURS
          _buildMemberSection(
            context,
            "Coéquipiers",
            playerIds,
            isCoach: false,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMemberSection(
    BuildContext context,
    String title,
    List ids, {
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
        ...ids.map((id) => _MemberTile(userId: id)),
      ],
    );
  }
}

// Widget interne pour récupérer les infos de chaque membre (nom/prénom)
class _MemberTile extends StatelessWidget {
  final String userId;

  const _MemberTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox();

        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundImage: (data['avatarUrl'] != null &&
                    (data['avatarUrl'] as String).isNotEmpty)
                ? NetworkImage(data['avatarUrl'])
                : null,
            child: (data['avatarUrl'] == null ||
                    (data['avatarUrl'] as String).isEmpty)
                ? const Icon(Icons.person, size: 14)
                : null,
          ),
          title: Text(
            "${data['firstName']} ${data['lastName']}",
            style: const TextStyle(fontSize: 13),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 16,
            color: Colors.grey,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilDisplayPage(userId: userId),
              ),
            );
          },
        );
      },
    );
  }
}
