import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';
import 'player_planning_page.dart';
import 'player_home_page.dart';
import 'player_profil_page.dart';

class PlayerInfosPage extends StatelessWidget {
  final String clubId;

  const PlayerInfosPage({super.key, required this.clubId});
  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: ViroColors.background,
      selectedItemColor: ViroColors.primary,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: 2,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PlayerHomePage()),
            (route) => false,
          );
        }
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerPlanningPage(clubId: clubId),
            ),
          );
        }
        if (index == 2) {
          // déjà sur Infos
        }
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerProfilPage()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: "Planning",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          label: "Infos",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: "Profil",
        ),
      ],
    );
  }

  // --- LOGIQUE D'AFFICHAGE DES SOUS-PAGES ---

  void _showClubInfos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ClubDetailsPage(clubId: clubId)),
    );
  }

  void _showStaffList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _StaffListPage(clubId: clubId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Infos & Actualités"),
        centerTitle: true,
        backgroundColor: ViroColors.background,
        elevation: 0,
        automaticallyImplyLeading:
            false, // On gère nous même si besoin, ou via la BottomNav
      ),
      body: Column(
        children: [
          // --- HEADER BOUTONS ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderButton(
                    icon: Icons.info_outline_rounded,
                    label: "Infos Club",
                    onTap: () => _showClubInfos(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _HeaderButton(
                    icon: Icons.people_alt_rounded,
                    label: "Contacts / Staff",
                    onTap: () => _showStaffList(context),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- ZONE DE NOTIFICATIONS / MESSAGES ---
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 60,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune actualité pour le moment",
                    style: TextStyle(color: Colors.grey),
                  ),
                  // TODO: Implémenter ici le StreamBuilder pour la collection 'posts' ou 'notifications' du club
                  // Ex: FirebaseFirestore.instance.collection('clubs').doc(clubId).collection('feed')...
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }
}

// --- WIDGET BOUTON EN-TÊTE ---
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ViroColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ViroColors.borderColor),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --- PAGE 1 : DÉTAILS DU CLUB ---
class _ClubDetailsPage extends StatelessWidget {
  final String clubId;
  const _ClubDetailsPage({required this.clubId});

  Future<Map<String, dynamic>> _fetchClubStats() async {
    final db = FirebaseFirestore.instance;

    // 1. Infos du club
    final clubDoc = await db.collection('clubs').doc(clubId).get();

    // 2. Compteurs (C'est mieux d'avoir des compteurs stockés, mais voici la méthode brute pour l'instant)
    final usersQuery = await db
        .collection('users')
        .get();
    final teamsQuery = await db
        .collection('clubs')
        .doc(clubId)
        .collection('teams')
        .count()
        .get();

    final allUsers = usersQuery.docs;
    // Filtrer les utilisateurs du club
    final users = filterUsersByClub(allUsers, clubId);

    // Filtrage simple avec la nouvelle structure
    final playersCount = users
        .where((u) => getUserRoleInClub(u.data() as Map<String, dynamic>, clubId) == 'player')
        .length;
    final coachsCount = users
        .where((u) => getUserRoleInClub(u.data() as Map<String, dynamic>, clubId) == 'coach')
        .length;
    final adminsCount = users
        .where((u) {
          final role = getUserRoleInClub(u.data() as Map<String, dynamic>, clubId);
          return role == 'admin' || role == 'admin_fondateur';
        })
        .length;

    // Trouver le fondateur
    String founderName = "Non défini";
    try {
      final founder = users.firstWhere(
        (u) {
          final data = u.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final role = getUserRoleInClub(data, clubId);
          return role == 'admin_fondateur' || role == 'admin';
        },
      );
      final founderData = founder.data() as Map<String, dynamic>?;
      if (founderData != null) {
        final firstName = founderData['firstName'] as String? ?? "";
        final lastName = founderData['lastName'] as String? ?? "";
        founderName = "$firstName $lastName".trim();
        if (founderName.isEmpty) founderName = "Non défini";
      }
    } catch (_) {}

    return {
      'data': clubDoc.data(),
      'players': playersCount,
      'coachs': coachsCount,
      'admins': adminsCount,
      'teams': teamsQuery.count,
      'founder': founderName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Infos du Club"),
        backgroundColor: ViroColors.background,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchClubStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: ViroLoader());

          final data = snapshot.data!;
          final clubData = data['data'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Logo et Nom
                CircleAvatar(
                  radius: 40,
                  backgroundColor: ViroColors.primary,
                  child: Text(
                    (clubData?['name'] ?? "C")[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  clubData?['name'] ?? "Club Inconnu",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  clubData?['address'] ?? "Adresse non renseignée",
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),

                // Cartes de statistiques
                Row(
                  children: [
                    _StatCard(
                      label: "Joueurs",
                      count: data['players'].toString(),
                      icon: Icons.sports_handball,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: "Équipes",
                      count: data['teams'].toString(),
                      icon: Icons.groups,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard(
                      label: "Coachs",
                      count: data['coachs'].toString(),
                      icon: Icons.sports,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: "Admins",
                      count: data['admins'].toString(),
                      icon: Icons.admin_panel_settings,
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star, color: Colors.orange),
                  title: const Text("Club fondé par"),
                  subtitle: Text(
                    data['founder'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ViroColors.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: ViroColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE 2 : LISTE CONTACTS / STAFF ---
class _StaffListPage extends StatelessWidget {
  final String clubId;
  const _StaffListPage({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Staff & Contacts"),
        backgroundColor: ViroColors.background,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: ViroLoader());

          final allDocs = snapshot.data!.docs;
          // Filtrer les utilisateurs du club avec les rôles staff
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final role = getUserRoleInClub(data, clubId);
            return role == 'coach' || role == 'admin' || role == 'admin_fondateur';
          }).toList();
          if (docs.isEmpty)
            return const Center(child: Text("Aucun contact trouvé"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final rawData = docs[index].data();
              final data = rawData as Map<String, dynamic>?;
              if (data == null) return const SizedBox.shrink();
              
              // Utiliser la nouvelle fonction pour obtenir le rôle dans ce club
              final String role = getUserRoleInClub(data, clubId) ?? 'user';
              final String uid = docs[index].id;

              // Définition de l'affichage du rôle
              String roleLabel = "Coach";
              Color roleColor = Colors.blue;
              if (role == 'admin' || role == 'admin_fondateur') {
                roleLabel = "Admin";
                roleColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ViroColors.primary,
                    child: Text(
                      (data['firstName'] ?? "?")[0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    "${data['firstName']} ${data['lastName']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    data['email'] ?? "",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Navigation vers la page de profil existante
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilDisplayPage(userId: uid),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
