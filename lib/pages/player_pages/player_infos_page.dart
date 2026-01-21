import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader());
          }

          final userData = userSnapshot.data?.data();
          if (userData == null) {
            return const Center(child: Text("Erreur de chargement"));
          }

          // Extraire tous les clubIds du joueur
          final Set<String> clubIdsSet = {};
          final roles = userData['roles'] as Map<String, dynamic>? ?? {};

          // Player clubs
          if (roles['player'] is Map) {
            final playerData = roles['player'] as Map;
            if (playerData['clubs'] is List) {
              final clubs = (playerData['clubs'] as List).whereType<Map>();
              for (var club in clubs) {
                final clubIdFromClub = club['clubId'] as String?;
                if (clubIdFromClub != null) clubIdsSet.add(clubIdFromClub);
              }
            }
          }

          // Fallback pour compatibilité
          final legacyClubId = userData['clubId'] as String?;
          if (legacyClubId != null) clubIdsSet.add(legacyClubId);

          // Ajouter le clubId passé en paramètre si pas déjà présent
          clubIdsSet.add(clubId);

          final allClubIds = clubIdsSet.toList();

          return Column(
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
                child: _ClubAnnouncementsList(
                  clubIds: allClubIds,
                  userId: userId,
                ),
              ),
            ],
          );
        },
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
    final usersQuery = await db.collection('users').get();
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
        .where(
          (u) =>
              getUserRoleInClub(u.data() as Map<String, dynamic>, clubId) ==
              'player',
        )
        .length;
    final coachsCount = users
        .where(
          (u) =>
              getUserRoleInClub(u.data() as Map<String, dynamic>, clubId) ==
              'coach',
        )
        .length;
    final adminsCount = users.where((u) {
      final role = getUserRoleInClub(u.data() as Map<String, dynamic>, clubId);
      return role == 'admin' || role == 'admin_fondateur';
    }).length;

    // Trouver le fondateur
    String founderName = "Non défini";
    try {
      final founder = users.firstWhere((u) {
        final data = u.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final role = getUserRoleInClub(data, clubId);
        return role == 'admin_fondateur' || role == 'admin';
      });
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
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: ViroLoader());

          final allDocs = snapshot.data!.docs;
          // Filtrer les utilisateurs du club avec les rôles staff
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final role = getUserRoleInClub(data, clubId);
            return role == 'coach' ||
                role == 'admin' ||
                role == 'admin_fondateur';
          }).toList();
          if (docs.isEmpty) {
            return const Center(child: Text("Aucun contact trouvé"));
          }

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

// --- WIDGET LISTE DES ANNONCES DU CLUB ---
class _ClubAnnouncementsList extends StatelessWidget {
  final List<String> clubIds;
  final String userId;

  const _ClubAnnouncementsList({required this.clubIds, required this.userId});

  // Récupère les teamIds et catégories de l'utilisateur pour tous ses clubs
  Future<Map<String, Map<String, dynamic>>> _getUserClubsInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final roles = userData['roles'] as Map<String, dynamic>? ?? {};

      final Map<String, Map<String, dynamic>> clubsInfo = {};

      // Récupérer les informations pour chaque club
      if (roles['player'] is Map) {
        final playerData = roles['player'] as Map;
        if (playerData['clubs'] is List) {
          final clubs = (playerData['clubs'] as List).whereType<Map>();
          for (var club in clubs) {
            final clubIdFromClub = club['clubId'] as String?;
            if (clubIdFromClub == null) continue;

            final teamIds =
                (club['teamIds'] as List?)?.whereType<String>().toList() ?? [];

            // Récupérer les catégories depuis les équipes
            List<String> categories = [];
            if (teamIds.isNotEmpty) {
              final teamsSnapshot = await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubIdFromClub)
                  .collection('teams')
                  .get();

              for (var teamDoc in teamsSnapshot.docs) {
                if (teamIds.contains(teamDoc.id)) {
                  final category = teamDoc.data()['category'] as String?;
                  if (category != null && category.isNotEmpty) {
                    categories.add(category);
                  }
                }
              }
            }

            // Fallback : récupérer la catégorie directement de l'utilisateur
            if (categories.isEmpty) {
              final userCategory = userData['category'] as String?;
              if (userCategory != null && userCategory.isNotEmpty) {
                categories.add(userCategory);
              }
            }

            clubsInfo[clubIdFromClub] = {
              'teamIds': teamIds,
              'categories': categories,
            };
          }
        }
      }

      return clubsInfo;
    } catch (e) {
      return {};
    }
  }

  // Vérifie si un message est destiné à cet utilisateur pour un club donné
  bool _isMessageForUser(
    Map<String, dynamic> announcementData,
    Map<String, dynamic> userClubInfo,
  ) {
    final targetType = announcementData['targetType'] as String? ?? '';
    final targetIds =
        (announcementData['targetIds'] as List?)
            ?.whereType<String>()
            .toList() ??
        [];

    switch (targetType) {
      case 'Équipes':
        final userTeamIds =
            (userClubInfo['teamIds'] as List?)?.whereType<String>().toList() ??
            [];
        return targetIds.any((id) => userTeamIds.contains(id));

      case 'Catégories':
        final userCategories =
            (userClubInfo['categories'] as List?)
                ?.whereType<String>()
                .toList() ??
            [];
        return targetIds.any((id) => userCategories.contains(id));

      case 'Joueurs':
        return targetIds.contains(userId);

      default:
        return false;
    }
  }

  // Calcule le temps restant avant expiration du message
  String _getTimeRemaining(Timestamp? createdAt, int durationDays) {
    if (createdAt == null) return '';
    final created = createdAt.toDate();
    final expiresAt = created.add(Duration(days: durationDays));
    final now = DateTime.now();

    if (now.isAfter(expiresAt)) return 'Expiré';

    final remaining = expiresAt.difference(now);
    if (remaining.inDays > 0) {
      return '${remaining.inDays} jour${remaining.inDays > 1 ? 's' : ''} restant${remaining.inDays > 1 ? 's' : ''}';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours} heure${remaining.inHours > 1 ? 's' : ''} restante${remaining.inHours > 1 ? 's' : ''}';
    } else {
      return 'Expire bientôt';
    }
  }

  // Générer une couleur unique par clubId (identique au planning)
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

  // Formate le nom de la cible pour l'affichage
  String _formatTargetName(String targetType, List<String> targetIds) {
    if (targetIds.isEmpty) return 'Tous les membres';

    switch (targetType) {
      case 'Équipes':
        if (targetIds.length == 1) {
          return 'Équipe : ${targetIds.first}';
        }
        return '${targetIds.length} équipes';
      case 'Catégories':
        if (targetIds.length == 1) {
          return 'Catégorie : ${targetIds.first}';
        }
        return '${targetIds.length} catégories';
      case 'Joueurs':
        if (targetIds.length == 1) {
          return 'Joueur spécifique';
        }
        return '${targetIds.length} joueurs';
      default:
        return 'Membres du club';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (clubIds.isEmpty) {
      return const Center(child: Text("Aucun club trouvé"));
    }

    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _getUserClubsInfo(),
      builder: (context, userInfoSnapshot) {
        if (userInfoSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ViroLoader());
        }

        final clubsInfo = userInfoSnapshot.data ?? {};

        // Créer un StreamBuilder pour chaque club et les combiner
        return _buildCombinedAnnouncements(clubsInfo);
      },
    );
  }

  // Construit les annonces combinées de tous les clubs
  Widget _buildCombinedAnnouncements(
    Map<String, Map<String, dynamic>> clubsInfo,
  ) {
    // Créer un StreamBuilder pour chaque club
    if (clubIds.length == 1) {
      // Un seul club : utiliser un StreamBuilder simple
      final clubId = clubIds.first;
      final userClubInfo =
          clubsInfo[clubId] ?? {'teamIds': [], 'categories': []};

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          return _processAnnouncements(snapshot, {
            clubId: userClubInfo,
          }, clubsInfo);
        },
      );
    }

    // Plusieurs clubs : utiliser une approche imbriquée
    // Pour simplifier, on utilise le premier club comme base
    // Une version optimisée utiliserait rxdart CombineLatestStream
    final firstClubId = clubIds.first;
    final userClubInfo =
        clubsInfo[firstClubId] ?? {'teamIds': [], 'categories': []};

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(firstClubId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, firstSnapshot) {
        // Pour chaque autre club, créer un autre StreamBuilder
        if (clubIds.length == 2) {
          final secondClubId = clubIds[1];
          final secondClubInfo =
              clubsInfo[secondClubId] ?? {'teamIds': [], 'categories': []};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(secondClubId)
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, secondSnapshot) {
              // Combiner les deux snapshots
              final allDocs = <({DocumentSnapshot doc, String clubId})>[];

              if (firstSnapshot.hasData) {
                for (var doc in firstSnapshot.data!.docs) {
                  allDocs.add((doc: doc, clubId: firstClubId));
                }
              }

              if (secondSnapshot.hasData) {
                for (var doc in secondSnapshot.data!.docs) {
                  allDocs.add((doc: doc, clubId: secondClubId));
                }
              }

              return _processCombinedAnnouncements(
                allDocs,
                clubsInfo,
                secondClubInfo,
              );
            },
          );
        }

        // Plus de 2 clubs : pour simplifier, on traite seulement les 2 premiers
        // Une version complète nécessiterait une bibliothèque comme rxdart
        return _processAnnouncements(firstSnapshot, {
          firstClubId: userClubInfo,
        }, clubsInfo);
      },
    );
  }

  Widget _processAnnouncements(
    AsyncSnapshot<QuerySnapshot> snapshot,
    Map<String, Map<String, dynamic>> currentClubsInfo,
    Map<String, Map<String, dynamic>> allClubsInfo,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: ViroLoader());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return Center(
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
          ],
        ),
      );
    }

    // Filtrer et valider les messages
    final validAnnouncements = <({DocumentSnapshot doc, String clubId})>[];

    for (var entry in currentClubsInfo.entries) {
      final clubId = entry.key;
      final userClubInfo = entry.value;

      for (var doc in snapshot.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        final durationDays = data['durationDays'] as int? ?? 7;

        // Vérifier si le message est encore valide
        if (createdAt != null) {
          final expiresAt = createdAt.toDate().add(
            Duration(days: durationDays),
          );
          if (DateTime.now().isAfter(expiresAt)) {
            continue; // Message expiré
          }
        }

        // Vérifier si le message est destiné à cet utilisateur
        final targetIds =
            (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
        if (targetIds.isNotEmpty) {
          if (!_isMessageForUser(data, userClubInfo)) {
            continue; // Message pas destiné à cet utilisateur
          }
        }

        validAnnouncements.add((doc: doc, clubId: clubId));
      }
    }

    // Trier par date de création (plus récent en premier)
    validAnnouncements.sort((a, b) {
      final aData = a.doc.data() as Map<String, dynamic>;
      final bData = b.doc.data() as Map<String, dynamic>;
      final aCreated = aData['createdAt'] as Timestamp?;
      final bCreated = bData['createdAt'] as Timestamp?;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      return bCreated.compareTo(aCreated);
    });

    return _buildAnnouncementsList(validAnnouncements);
  }

  Widget _processCombinedAnnouncements(
    List<({DocumentSnapshot doc, String clubId})> allDocs,
    Map<String, Map<String, dynamic>> clubsInfo, [
    Map<String, dynamic>? secondClubInfo,
  ]) {
    final validAnnouncements = <({DocumentSnapshot doc, String clubId})>[];

    for (var item in allDocs) {
      final doc = item.doc;
      final clubId = item.clubId;
      final userClubInfo =
          clubsInfo[clubId] ?? {'teamIds': [], 'categories': []};
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'] as Timestamp?;
      final durationDays = data['durationDays'] as int? ?? 7;

      // Vérifier si le message est encore valide
      if (createdAt != null) {
        final expiresAt = createdAt.toDate().add(Duration(days: durationDays));
        if (DateTime.now().isAfter(expiresAt)) {
          continue; // Message expiré
        }
      }

      // Vérifier si le message est destiné à cet utilisateur
      final targetIds =
          (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
      if (targetIds.isNotEmpty) {
        if (!_isMessageForUser(data, userClubInfo)) {
          continue; // Message pas destiné à cet utilisateur
        }
      }

      validAnnouncements.add((doc: doc, clubId: clubId));
    }

    // Trier par date de création (plus récent en premier)
    validAnnouncements.sort((a, b) {
      final aData = a.doc.data() as Map<String, dynamic>;
      final bData = b.doc.data() as Map<String, dynamic>;
      final aCreated = aData['createdAt'] as Timestamp?;
      final bCreated = bData['createdAt'] as Timestamp?;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      return bCreated.compareTo(aCreated);
    });

    if (validAnnouncements.isEmpty) {
      return Center(
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
          ],
        ),
      );
    }

    return _buildAnnouncementsList(validAnnouncements);
  }

  Widget _buildAnnouncementsList(
    List<({DocumentSnapshot doc, String clubId})> validAnnouncements,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: validAnnouncements.length,
      itemBuilder: (context, index) {
        final item = validAnnouncements[index];
        final doc = item.doc;
        final clubId = item.clubId;
        final data = doc.data() as Map<String, dynamic>;

        final message = data['message'] as String? ?? '';
        final targetType = data['targetType'] as String? ?? '';
        final targetIds =
            (data['targetIds'] as List?)?.whereType<String>().toList() ?? [];
        final createdAt = data['createdAt'] as Timestamp?;
        final durationDays = data['durationDays'] as int? ?? 7;
        final senderFirstName = data['senderFirstName'] as String? ?? '';
        final senderLastName = data['senderLastName'] as String? ?? '';

        final targetName = _formatTargetName(targetType, targetIds);
        final timeRemaining = _getTimeRemaining(createdAt, durationDays);
        final senderName = "$senderFirstName $senderLastName".trim();
        final senderLabel = senderName.isNotEmpty
            ? senderName
            : 'Administration';

        final isExpiringSoon =
            createdAt != null &&
            createdAt
                    .toDate()
                    .add(Duration(days: durationDays))
                    .difference(DateTime.now())
                    .inDays <
                2;

        // Récupérer la couleur du club (identique au planning)
        final clubColor = _getClubColor(clubId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isExpiringSoon
                  ? Colors.orange.withOpacity(0.5)
                  : clubColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec expéditeur et temps restant
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            size: 16,
                            color: clubColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              senderLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isExpiringSoon
                            ? Colors.orange.withOpacity(0.1)
                            : clubColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeRemaining,
                        style: TextStyle(
                          fontSize: 10,
                          color: isExpiringSoon
                              ? Colors.orange[800]
                              : clubColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Cible avec couleur du club
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: clubColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: clubColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 14, color: clubColor),
                      const SizedBox(width: 6),
                      Text(
                        targetName,
                        style: TextStyle(
                          fontSize: 11,
                          color: clubColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
