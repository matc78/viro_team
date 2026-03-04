import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/avatar_moderation.dart';
import '../../widget/player_bottom_nav.dart';
import '../../widget/user_display_tile.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';

class PlayerInfosPage extends StatefulWidget {
  final String clubId;

  const PlayerInfosPage({super.key, required this.clubId});

  @override
  State<PlayerInfosPage> createState() => _PlayerInfosPageState();
}

class _PlayerInfosPageState extends State<PlayerInfosPage> {
  String? _selectedClubId;
  bool _initialized = false;
  Map<String, String> _clubNamesCache = {};
  Map<String, String> _clubSportsCache = {};

  Future<void> _loadClubNames(List<String> clubIds) async {
    if (clubIds.isEmpty) return;
    final Map<String, String> names = {};
    final Map<String, String> sports = {};
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.sublist(i, math.min(i + 10, clubIds.length));
      try {
        final snapshot = await appFirestore
            .collection(FirebaseCollections.clubs)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          names[doc.id] = data['name'] as String? ?? doc.id;
          final sport = data['sport'] as String?;
          if (sport != null && sport.isNotEmpty) sports[doc.id] = sport;
        }
      } catch (_) {
        for (var id in batch) {
          names[id] = id;
        }
      }
    }
    if (mounted) {
      setState(() {
        _clubNamesCache = names;
        _clubSportsCache = sports;
      });
    }
  }

  void _ensureInitialized(List<String> allClubIds) {
    if (_initialized || allClubIds.isEmpty) return;
    _initialized = true;
    final sel = allClubIds.contains(widget.clubId)
        ? widget.clubId
        : allClubIds.first;
    setState(() => _selectedClubId = sel);
    _loadClubNames(allClubIds);
  }

  void _showClubInfos(BuildContext context, String selectedClubId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClubDetailsPage(clubId: selectedClubId),
      ),
    );
  }

  void _showStaffList(BuildContext context, String selectedClubId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _StaffListPage(clubId: selectedClubId)),
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
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appFirestore
            .collection(FirebaseCollections.users)
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

          final Set<String> clubIdsSet = {};
          final roles = userData['roles'] as Map<String, dynamic>? ?? {};

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

          final legacyClubId = userData['clubId'] as String?;
          if (legacyClubId != null) clubIdsSet.add(legacyClubId);
          clubIdsSet.add(widget.clubId);

          final allClubIds = clubIdsSet.toList();

          if (allClubIds.isEmpty) {
            return const Center(child: Text("Aucun club trouvé"));
          }

          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensureInitialized(allClubIds);
            });
          }

          final selectedClubId = _selectedClubId ?? allClubIds.first;
          final showFilter = allClubIds.length > 1;

          return Column(
            children: [
              if (showFilter) _buildClubFilter(allClubIds, selectedClubId),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderButton(
                        icon: Icons.info_outline_rounded,
                        label: "Infos Club",
                        onTap: () => _showClubInfos(context, selectedClubId),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HeaderButton(
                        icon: Icons.people_alt_rounded,
                        label: "Contacts / Staff",
                        onTap: () => _showStaffList(context, selectedClubId),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _ClubAnnouncementsList(
                  clubIds: [selectedClubId],
                  userId: userId,
                  hasMultipleClubs: allClubIds.length > 1,
                  clubNames: _clubNamesCache,
                  clubSports: _clubSportsCache,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: playerBottomNav(
        context,
        currentIndex: 2,
        clubId: _selectedClubId ?? widget.clubId,
      ),
    );
  }

  Widget _buildClubFilter(List<String> allClubIds, String selectedClubId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: selectedClubId,
        decoration: InputDecoration(
          labelText: "Club",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: allClubIds
            .map(
              (id) => DropdownMenuItem(
                value: id,
                child: Text(
                  formatClubNameWithEmoji(
                    _clubNamesCache[id] ?? id,
                    _clubSportsCache[id],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) setState(() => _selectedClubId = id);
        },
      ),
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
    final db = appFirestore;

    // 1. Infos du club (source de vérité pour admins/coachs)
    final clubDoc = await db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .get();
    final clubData = clubDoc.data();

    // 2. Compteurs : admins et coachs depuis le document club (adminId, admins, coaches)
    final adminId = clubData?['adminId'] as String?;
    final adminsList =
        (clubData?['admins'] as List?)?.whereType<String>().toList() ?? [];
    final coachesList =
        (clubData?['coaches'] as List?)?.whereType<String>().toList() ?? [];
    final adminsCount = {
      ...{if (adminId != null) adminId},
      ...adminsList,
    }.length;
    final coachsCount = coachesList.length;

    final usersQuery = await db.collection(FirebaseCollections.users).get();
    final teamsQuery = await db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .count()
        .get();

    final allUsers = usersQuery.docs;
    final users = filterUsersByClub(allUsers, clubId);

    final playersCount = users
        .where(
          (u) =>
              getUserRoleInClub(u.data() as Map<String, dynamic>, clubId) ==
              'player',
        )
        .length;

    // Fondateur : nom depuis adminId du club, sinon fallback sur les rôles utilisateur
    String founderName = "Non défini";
    if (adminId != null && adminId.isNotEmpty) {
      DocumentSnapshot<Map<String, dynamic>>? founderDoc;
      for (final d in allUsers) {
        if (d.id == adminId) {
          founderDoc = d as DocumentSnapshot<Map<String, dynamic>>;
          break;
        }
      }
      if (founderDoc != null) {
        final founderData = founderDoc.data();
        if (founderData != null) {
          final firstName = founderData['firstName'] as String? ?? "";
          final lastName = founderData['lastName'] as String? ?? "";
          founderName = "$firstName $lastName".trim();
          if (founderName.isEmpty) founderName = "Non défini";
        }
      }
    }
    if (founderName == "Non défini") {
      try {
        DocumentSnapshot<Map<String, dynamic>>? founderDoc;
        for (final u in users) {
          final data = u.data();
          if (data == null) continue;
          final role = getUserRoleInClub(data, clubId);
          if (role == 'admin_fondateur') {
            founderDoc = u;
            break;
          }
          if (founderDoc == null &&
              (role == 'admin' || role == 'admin_fondateur')) {
            founderDoc = u;
          }
        }
        if (founderDoc != null) {
          final founderData = founderDoc.data();
          if (founderData != null) {
            final firstName = founderData['firstName'] as String? ?? "";
            final lastName = founderData['lastName'] as String? ?? "";
            founderName = "$firstName $lastName".trim();
            if (founderName.isEmpty) founderName = "Non défini";
          }
        }
      } catch (_) {}
    }

    return {
      'data': clubData,
      'players': playersCount,
      'coachs': coachsCount,
      'admins': adminsCount,
      'teams': teamsQuery.count,
      'founder': founderName,
    };
  }

  String _postalCodeCityLine(Map<String, dynamic>? clubData) {
    if (clubData == null) return '';
    final pc = clubData['postalCode']?.toString().trim();
    final city = clubData['city']?.toString().trim();
    final hasPc = pc != null && pc.isNotEmpty;
    final hasCity = city != null && city.isNotEmpty;
    if (!hasPc && !hasCity) return '';
    if (hasPc && hasCity) return '$pc $city';
    if (hasPc) return pc;
    return city ?? '';
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
                  formatClubNameWithEmoji(
                    clubData?['name'] ?? "Club Inconnu",
                    clubData?['sport'] as String?,
                  ),
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
                if (_postalCodeCityLine(clubData).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _postalCodeCityLine(clubData),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],

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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appFirestore.collection(FirebaseCollections.users).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: ViroLoader());

          final allDocs = snapshot.data!.docs
              .cast<DocumentSnapshot<Map<String, dynamic>>>();
          // Même logique que _fetchClubStats : d'abord utilisateurs du club
          final usersInClub = filterUsersByClub(allDocs, clubId);
          // Puis garder uniquement staff (coach, admin, admin_fondateur)
          final staffDocs = usersInClub.where((doc) {
            final data = doc.data();
            if (data == null) return false;
            final rolesInClub = getAllUserRolesInClub(data, clubId);
            return rolesInClub.any(
              (r) => r == 'coach' || r == 'admin' || r == 'admin_fondateur',
            );
          }).toList();
          if (staffDocs.isEmpty) {
            return const Center(child: Text("Aucun contact trouvé"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final doc = staffDocs[index];
              final data = doc.data();
              if (data == null) return const SizedBox.shrink();

              final rolesInClub = getAllUserRolesInClub(data, clubId);
              // Priorité : admin_fondateur > admin > coach pour l'affichage
              final String role = rolesInClub.contains('admin_fondateur')
                  ? 'admin_fondateur'
                  : rolesInClub.contains('admin')
                  ? 'admin'
                  : rolesInClub.contains('coach')
                  ? 'coach'
                  : 'user';
              final String uid = doc.id;

              // Définition de l'affichage du rôle
              String roleLabel = "Coach";
              Color roleColor = Colors.blue;
              if (role == 'admin_fondateur') {
                roleLabel = "Fondateur";
                roleColor = Colors.orange;
              } else if (role == 'admin') {
                roleLabel = "Admin";
                roleColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: null,
                  title: UserDisplayTile(
                    userId: uid,
                    firstName: data['firstName'] as String?,
                    lastName: data['lastName'] as String?,
                    avatarUrl: effectiveAvatarUrl(data),
                    navigateOnTap: false,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                      color: roleColor.withValues(alpha: 0.1),
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
  final bool hasMultipleClubs;
  final Map<String, String>? clubNames;
  final Map<String, String>? clubSports;

  const _ClubAnnouncementsList({
    required this.clubIds,
    required this.userId,
    this.hasMultipleClubs = false,
    this.clubNames,
    this.clubSports,
  });

  // Récupère les teamIds et catégories de l'utilisateur pour tous ses clubs
  Future<Map<String, Map<String, dynamic>>> _getUserClubsInfo() async {
    try {
      final userDoc = await appFirestore
          .collection(FirebaseCollections.users)
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

            // Catégories : source unifiée roles.player.clubs, sinon fetch depuis équipes
            List<String> categories =
                (club['categories'] as List?)?.whereType<String>().toList() ??
                [];
            if (categories.isEmpty && teamIds.isNotEmpty) {
              final teamsSnapshot = await appFirestore
                  .collection(FirebaseCollections.clubs)
                  .doc(clubIdFromClub)
                  .collection(FirebaseCollections.teams)
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
      case 'Tous les membres':
        return true;

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
    final index = clubId.hashCode % ViroColors.clubPalette.length;
    return ViroColors.clubPalette[index.abs()];
  }

  /// Légende : point de couleur + nom du club (si plusieurs clubs et au moins 1 annonce)
  Widget _buildLegend(List<String> clubIdsInAnnouncements) {
    final distinctIds = clubIdsInAnnouncements.toSet().toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final cid in distinctIds)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getClubColor(cid),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatClubNameWithEmoji(
                    clubNames?[cid] ?? cid,
                    clubSports?[cid],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );
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
        stream: appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.announcements)
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
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(firstClubId)
          .collection(FirebaseCollections.announcements)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, firstSnapshot) {
        // Pour chaque autre club, créer un autre StreamBuilder
        if (clubIds.length == 2) {
          final secondClubId = clubIds[1];
          final secondClubInfo =
              clubsInfo[secondClubId] ?? {'teamIds': [], 'categories': []};

          return StreamBuilder<QuerySnapshot>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(secondClubId)
                .collection(FirebaseCollections.announcements)
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
              color: Colors.grey.withValues(alpha: 0.5),
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

    if (validAnnouncements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.5),
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

    if (hasMultipleClubs && validAnnouncements.isNotEmpty) {
      final clubIdsInAnnouncements = validAnnouncements
          .map((a) => a.clubId)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend(clubIdsInAnnouncements),
          Expanded(child: _buildAnnouncementsList(validAnnouncements)),
        ],
      );
    }
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
              color: Colors.grey.withValues(alpha: 0.5),
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

    if (hasMultipleClubs && validAnnouncements.isNotEmpty) {
      final clubIdsInAnnouncements = validAnnouncements
          .map((a) => a.clubId)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend(clubIdsInAnnouncements),
          Expanded(child: _buildAnnouncementsList(validAnnouncements)),
        ],
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
                  ? Colors.orange.withValues(alpha: 0.5)
                  : clubColor.withValues(alpha: 0.5),
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
                            child: UserDisplayTile(
                              userId: data['senderId'] as String?,
                              firstName: senderFirstName.isNotEmpty
                                  ? senderFirstName
                                  : null,
                              lastName: senderLastName.isNotEmpty
                                  ? senderLastName
                                  : null,
                              compact: true,
                              fallback: 'Administration',
                              textStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
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
                            ? Colors.orange.withValues(alpha: 0.1)
                            : clubColor.withValues(alpha: 0.1),
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
                    color: clubColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: clubColor.withValues(alpha: 0.2),
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
