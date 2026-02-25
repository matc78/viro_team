import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';

class ProfilDisplayPage extends StatelessWidget {
  final String userId;

  const ProfilDisplayPage({super.key, required this.userId});

  // Vérifie si l'utilisateur actuel a le droit de voir les infos privées (email, téléphone)
  Future<Map<String, dynamic>> _viewerInfo() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return {'hasAccess': false, 'role': null};
    if (currentUid == userId) {
      return {'hasAccess': true, 'role': null};
    }

    final currentUserDoc = await appFirestore
        .collection(FirebaseCollections.users)
        .doc(currentUid)
        .get();
    final currentUserData = currentUserDoc.data();
    if (currentUserData == null) return {'hasAccess': false, 'role': null};

    // Utiliser activeContext pour le rôle actuel
    final activeContext =
        currentUserData['activeContext'] as Map<String, dynamic>?;
    final role = activeContext?['role'] as String?;
    final legacyRole = currentUserData['role'] as String?;
    final finalRole = role ?? legacyRole;

    // Admins et coachs voient toujours les coordonnées
    if (finalRole == 'admin' ||
        finalRole == 'admin_fondateur' ||
        finalRole == 'coach') {
      return {'hasAccess': true, 'role': finalRole};
    }

    // Un joueur peut voir les coordonnées des coachs/admins des clubs auxquels il appartient
    final viewerClubIds = _getViewerPlayerClubIds(currentUserData);
    if (viewerClubIds.isEmpty) return {'hasAccess': false, 'role': finalRole};

    final viewedUserDoc = await appFirestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .get();
    final viewedData = viewedUserDoc.data();
    if (viewedData == null) return {'hasAccess': false, 'role': finalRole};

    final staffClubIds = _getStaffClubIds(viewedData);
    final hasSharedClub = viewerClubIds.any(
      (clubId) => staffClubIds.contains(clubId),
    );
    final hasAccess = hasSharedClub;

    return {'hasAccess': hasAccess, 'role': finalRole};
  }

  /// Club IDs auxquels le viewer appartient en tant que joueur
  List<String> _getViewerPlayerClubIds(Map<String, dynamic> userData) {
    final ids = <String>{};
    final roles = userData['roles'] as Map<String, dynamic>?;
    if (roles != null && roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      if (playerData['clubs'] is List) {
        for (final c in (playerData['clubs'] as List)) {
          if (c is Map) {
            final clubId = c['clubId'] as String?;
            if (clubId != null && clubId.isNotEmpty) ids.add(clubId);
          }
        }
      } else if (playerData['clubId'] != null) {
        ids.add(playerData['clubId'] as String);
      }
    }
    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId != null && legacyClubId.isNotEmpty) ids.add(legacyClubId);
    return ids.toList();
  }

  /// Club IDs où l'utilisateur est coach ou admin
  List<String> _getStaffClubIds(Map<String, dynamic> userData) {
    final ids = <String>{};
    final roles = userData['roles'] as Map<String, dynamic>?;
    if (roles == null) return ids.toList();
    if (roles['coach'] is List) {
      for (final c in (roles['coach'] as List)) {
        if (c is Map) {
          final clubId = c['clubId'] as String?;
          if (clubId != null && clubId.isNotEmpty) ids.add(clubId);
        }
      }
    }
    if (roles['admin'] is List) {
      for (final id in (roles['admin'] as List).whereType<String>()) {
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids.toList();
  }

  // Vérifie si l'utilisateur actuel peut modifier la licence d'un joueur dans un club
  Future<bool> _canEditLicense(String clubId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;

    // Récupérer les données de l'utilisateur actuel
    final currentUserDoc = await appFirestore
        .collection(FirebaseCollections.users)
        .doc(currentUid)
        .get();
    final currentUserData = currentUserDoc.data();
    if (currentUserData == null) return false;

    // Vérifier directement dans la structure des rôles
    final roles = currentUserData['roles'] as Map<String, dynamic>? ?? {};

    // Vérifier si l'utilisateur est admin de ce club
    if (roles['admin'] is List) {
      final adminClubIds = (roles['admin'] as List).whereType<String>();
      if (adminClubIds.contains(clubId)) {
        return true; // Admin ou admin_fondateur (tous deux stockés dans roles.admin)
      }
    }

    // Vérifier le rôle avec getUserRoleInClub (fallback)
    final role = getUserRoleInClub(currentUserData, clubId);
    if (role == 'admin' || role == 'admin_fondateur') {
      return true;
    }

    // Vérifier aussi dans activeContext et legacy role
    final activeContext =
        currentUserData['activeContext'] as Map<String, dynamic>?;
    final activeRole = activeContext?['role'] as String?;
    final activeClubId = activeContext?['clubId'] as String?;
    if (activeClubId == clubId &&
        (activeRole == 'admin' || activeRole == 'admin_fondateur')) {
      return true;
    }

    final legacyRole = currentUserData['role'] as String?;
    final legacyClubId = currentUserData['clubId'] as String?;
    if (legacyClubId == clubId &&
        (legacyRole == 'admin' || legacyRole == 'admin_fondateur')) {
      return true;
    }

    // Si coach, vérifier qu'il est coach d'au moins une équipe contenant ce joueur
    if (role == 'coach') {
      try {
        // Récupérer toutes les équipes où le coach est dans coachIds
        final teamsSnapshot = await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.teams)
            .where('coachIds', arrayContains: currentUid)
            .get();

        // Vérifier si au moins une équipe contient le joueur dans playerIds
        for (var teamDoc in teamsSnapshot.docs) {
          final teamData = teamDoc.data();
          final playerIds =
              (teamData['playerIds'] as List?)?.whereType<String>().toList() ??
              [];
          if (playerIds.contains(userId)) {
            return true;
          }
        }
      } catch (e) {
        // En cas d'erreur, retourner false par sécurité
        return false;
      }
    }

    return false;
  }

  Future<void> _editLicense(
    BuildContext context,
    String? currentValue,
    String clubId,
  ) async {
    final controller = TextEditingController(text: currentValue ?? "");
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier le numéro de licence"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Numéro de licence"),
            inputFormatters: [
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                  selection: newValue.selection,
                ),
              ),
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Champ requis";
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final newVal = controller.text.trim();

              // Fermer la boîte de dialogue immédiatement
              Navigator.pop(ctx);

              try {
                // Récupérer les données actuelles de l'utilisateur
                final userDoc = await appFirestore
                    .collection(FirebaseCollections.users)
                    .doc(userId)
                    .get();
                final userData = userDoc.data() ?? {};
                final roles = userData['roles'] as Map<String, dynamic>? ?? {};
                final playerData =
                    roles['player'] as Map<String, dynamic>? ?? {};
                final clubs =
                    (playerData['clubs'] as List?)?.whereType<Map>().toList() ??
                    [];

                // Trouver et mettre à jour la licence pour ce club
                bool found = false;
                for (int i = 0; i < clubs.length; i++) {
                  if (clubs[i]['clubId'] == clubId) {
                    clubs[i] = {...clubs[i], 'license': newVal};
                    found = true;
                    break;
                  }
                }

                // Si le club n'existe pas dans la liste, l'ajouter
                if (!found) {
                  clubs.add({'clubId': clubId, 'license': newVal});
                }

                // Mettre à jour Firestore avec la structure complète
                // Reconstruire toute la structure roles pour éviter les problèmes de chemins imbriqués
                final updatedRoles = Map<String, dynamic>.from(roles);
                updatedRoles['player'] = {...playerData, 'clubs': clubs};

                await appFirestore
                    .collection(FirebaseCollections.users)
                    .doc(userId)
                    .update({'roles': updatedRoles});

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Licence mise à jour")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
                }
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Profil"),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: appFirestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 60));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Utilisateur introuvable"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String firstName = data['firstName'] ?? "";
          final String lastName = data['lastName'] ?? "";
          final String formattedName = _formatName(firstName, lastName);

          return FutureBuilder<bool>(
            future: _viewerInfo().then((v) => v['hasAccess'] as bool),
            builder: (context, accessSnapshot) {
              final bool hasAccess = accessSnapshot.data ?? false;
              final Future<Map<String, dynamic>> viewerInfoFuture =
                  _viewerInfo();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // --- HEADER : AVATAR ET NOM ---
                    FutureBuilder<List<String>>(
                      future: _fetchClubLogos(data),
                      builder: (context, logosSnap) {
                        final logos = logosSnap.data ?? [];
                        return Center(
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final url = effectiveAvatarUrl(data);
                                      return CircleAvatar(
                                        radius: 60,
                                        backgroundColor: ViroColors.primary
                                            .withValues(alpha: 0.1),
                                        backgroundImage: url != null
                                            ? CachedNetworkImageProvider(url)
                                            : null,
                                        child: url == null
                                            ? const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: ViroColors.primary,
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                  // Satellites des clubs
                                  for (int i = 0; i < logos.length; i++)
                                    _buildSatellitePosition(i, logos[i]),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                formattedName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                              ),
                              // Les badges de rôles seront affichés dans la section RÔLES PAR CLUB
                              const SizedBox(height: 4),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // --- SECTION : RÔLES ET CLUBS ---
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _extractRolesByClub(data),
                      builder: (context, rolesSnap) {
                        if (rolesSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: ViroLoader(size: 30),
                          );
                        }
                        final clubsWithRoles = rolesSnap.data ?? [];

                        if (clubsWithRoles.isEmpty) {
                          return _buildInfoTile(
                            Icons.badge_outlined,
                            "Rôle",
                            "Aucun club",
                          );
                        }

                        return Column(
                          children: [
                            _buildSectionTitle("RÔLES PAR CLUB"),
                            ...clubsWithRoles.map((clubInfo) {
                              return _buildClubRolesSection(
                                context,
                                clubInfo,
                                userId,
                                data,
                                viewerInfoFuture,
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- SECTION : NUMÉRO DE LICENCE (si applicable) ---
                    // Note: Les licences sont maintenant gérées par club dans la section RÔLES PAR CLUB
                    // Cette section affiche uniquement l'ancienne licence globale pour compatibilité
                    if ((data['licenseNumber'] as String?) != null &&
                        (data['licenseNumber'] as String).isNotEmpty)
                      Column(
                        children: [
                          _buildSectionTitle("INFORMATIONS"),
                          _buildInfoTile(
                            Icons.credit_card,
                            "Numéro de licence",
                            data['licenseNumber'] as String,
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // --- SECTION : COORDONNÉES (CONDITIONNEL) ---
                    _buildSectionTitle("COORDONNÉES"),
                    if (hasAccess) ...[
                      _buildInfoTile(
                        Icons.email_outlined,
                        "Email",
                        data['email'] ?? "Non renseigné",
                      ),
                      _buildInfoTile(
                        Icons.phone_android_outlined,
                        "Téléphone",
                        data['phone'] ?? "Non renseigné",
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ViroColors.borderColor),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Les coordonnées sont visibles uniquement par les coachs et l'administration.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
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

  // Calculer la position d'un satellite autour de l'avatar
  Widget _buildSatellitePosition(int index, String logoUrl) {
    double? top;
    double? bottom;
    double? left;
    double? right;

    // Positionner autour de l'avatar : 0 = haut droite, 1 = haut centre, 2 = haut gauche, etc.
    switch (index % 8) {
      case 0: // En haut à droite (premier satellite)
        top = -6;
        right = -6;
        break;
      case 1: // En haut au centre
        top = -6;
        break;
      case 2: // En haut à gauche
        top = -6;
        left = -6;
        break;
      case 3: // À gauche au centre
        left = -6;
        break;
      case 4: // En bas à gauche
        bottom = -6;
        left = -6;
        break;
      case 5: // En bas au centre
        bottom = -6;
        break;
      case 6: // En bas à droite
        bottom = -6;
        right = -6;
        break;
      case 7: // À droite au centre
        right = -6;
        break;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.white,
          backgroundImage: CachedNetworkImageProvider(logoUrl),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: ViroColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // Construire une section pour un club avec ses rôles
  Widget _buildClubRolesSection(
    BuildContext context,
    Map<String, dynamic> clubInfo,
    String userId,
    Map<String, dynamic> userData,
    Future<Map<String, dynamic>> viewerInfoFuture,
  ) {
    final clubId = clubInfo['clubId'] as String;
    final clubName = clubInfo['clubName'] as String? ?? "Club inconnu";
    final clubSport = clubInfo['clubSport'] as String?;
    final clubLogo = clubInfo['clubLogo'] as String? ?? "";
    final roles = clubInfo['roles'] as List<String>;
    final license = clubInfo['license'] as String?;

    // Générer une couleur unique par club
    final clubColor = _getClubColor(clubId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: clubColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du club
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: clubColor.withValues(alpha: 0.1),
                  backgroundImage: clubLogo.isNotEmpty
                      ? CachedNetworkImageProvider(clubLogo)
                      : null,
                  child: clubLogo.isEmpty
                      ? Icon(Icons.shield_rounded, color: clubColor, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatClubNameWithEmoji(clubName, clubSport),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: roles.map((role) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getRoleColor(role).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatRoleName(role).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(role),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: clubColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Licence pour ce club (affichée si l'utilisateur est joueur ou si un admin/coach peut modifier)
          if (roles.contains('player'))
            FutureBuilder<bool>(
              future: _canEditLicense(clubId),
              builder: (context, canEditSnap) {
                final canEdit = canEditSnap.data ?? false;
                final displayLicense = license ?? "";
                final hasLicense = displayLicense.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Numéro de licence",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              hasLicense ? displayLicense : "Non renseigné",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: hasLicense ? Colors.black : Colors.grey,
                                fontStyle: hasLicense
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editLicense(
                            context,
                            hasLicense ? displayLicense : null,
                            clubId,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              },
            ),
          // Équipes
          FutureBuilder<List<String>>(
            future: _fetchTeams(clubId, userId),
            builder: (context, teamSnap) {
              if (teamSnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: ViroLoader(size: 24)),
                );
              }
              final teams = teamSnap.data ?? [];
              if (teams.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.group, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Équipe(s)",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: teams.map((teamName) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: clubColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  teamName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: clubColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Extraire les rôles organisés par club
  Future<List<Map<String, dynamic>>> _extractRolesByClub(
    Map<String, dynamic> userData,
  ) async {
    final Map<String, Map<String, dynamic>> clubsMap = {};
    final roles = userData['roles'] as Map<String, dynamic>? ?? {};

    // 1. Extraire les rôles ADMIN (liste de clubIds)
    if (roles['admin'] is List) {
      for (var clubId in (roles['admin'] as List).whereType<String>()) {
        clubsMap[clubId] = {'clubId': clubId, 'roles': <String>[]};
        clubsMap[clubId]!['roles'].add('admin');
      }
    }

    // 2. Extraire les rôles PLAYER (structure avec clubs)
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      if (playerData['clubs'] is List) {
        for (var clubEntry in (playerData['clubs'] as List).whereType<Map>()) {
          final clubId = clubEntry['clubId'] as String?;
          if (clubId == null) continue;

          if (!clubsMap.containsKey(clubId)) {
            clubsMap[clubId] = {'clubId': clubId, 'roles': <String>[]};
          }
          clubsMap[clubId]!['roles'].add('player');

          // Ajouter la licence si disponible pour ce club
          final license = clubEntry['license'] as String?;
          if (license != null && license.isNotEmpty) {
            clubsMap[clubId]!['license'] = license;
          }
        }
      }
      // Compatibilité avec l'ancienne structure (clubId direct)
      else {
        final legacyClubId = playerData['clubId'] as String?;
        if (legacyClubId != null) {
          if (!clubsMap.containsKey(legacyClubId)) {
            clubsMap[legacyClubId] = {
              'clubId': legacyClubId,
              'roles': <String>[],
            };
          }
          clubsMap[legacyClubId]!['roles'].add('player');
        }
      }
    }

    // 3. Extraire les rôles COACH (structure similaire à player ou liste)
    if (roles['coach'] is Map) {
      final coachData = roles['coach'] as Map;
      if (coachData['clubs'] is List) {
        for (var clubEntry in (coachData['clubs'] as List).whereType<Map>()) {
          final clubId = clubEntry['clubId'] as String?;
          if (clubId == null) continue;

          if (!clubsMap.containsKey(clubId)) {
            clubsMap[clubId] = {'clubId': clubId, 'roles': <String>[]};
          }
          clubsMap[clubId]!['roles'].add('coach');
        }
      }
    } else if (roles['coach'] is List) {
      // Ancienne structure : liste de clubIds
      for (var clubId in (roles['coach'] as List).whereType<String>()) {
        if (!clubsMap.containsKey(clubId)) {
          clubsMap[clubId] = {'clubId': clubId, 'roles': <String>[]};
        }
        clubsMap[clubId]!['roles'].add('coach');
      }
    }

    // 4. Compatibilité avec l'ancienne structure (clubId direct)
    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId != null && !clubsMap.containsKey(legacyClubId)) {
      final legacyRole = userData['role'] as String?;
      clubsMap[legacyClubId] = {
        'clubId': legacyClubId,
        'roles': legacyRole != null ? [legacyRole] : [],
      };
    }

    // 5. Récupérer les infos des clubs (nom, logo)
    final List<Map<String, dynamic>> result = [];
    for (var entry in clubsMap.entries) {
      final clubId = entry.key;
      final clubInfo = entry.value;

      try {
        final clubDoc = await appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .get();
        final clubData = clubDoc.data();
        clubInfo['clubName'] = (clubData?['name'] as String?) ?? "Club inconnu";
        clubInfo['clubSport'] = clubData?['sport'] as String?;
        clubInfo['clubLogo'] = clubData?['logoUrl'] as String? ?? "";
      } catch (e) {
        clubInfo['clubName'] = "Club inconnu";
        clubInfo['clubLogo'] = "";
      }

      result.add(clubInfo);
    }

    return result;
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
      Colors.red,
      Colors.cyan,
    ];
    final index = clubId.hashCode % colors.length;
    return colors[index.abs()];
  }

  // Obtenir la couleur pour un rôle
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'admin_fondateur':
        return Colors.red;
      case 'coach':
        return Colors.orange;
      case 'player':
        return ViroColors.primary;
      default:
        return Colors.grey;
    }
  }

  // Formater le nom du rôle
  String _formatRoleName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrateur';
      case 'admin_fondateur':
        return 'Admin Fondateur';
      case 'coach':
        return 'Coach';
      case 'player':
        return 'Joueur';
      default:
        return role;
    }
  }
}

String _formatName(String first, String last) {
  String cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
  final f = cap(first);
  final l = last.toUpperCase();
  return [f, l].where((e) => e.isNotEmpty).join(" ").trim();
}

Future<List<String>> _fetchClubLogos(Map<String, dynamic> data) async {
  final logos = <String>[];
  final Set<String> clubIdsSet = {};
  final roles = data['roles'] as Map<String, dynamic>? ?? {};

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

  // Coach
  if (roles['coach'] is Map) {
    final coachData = roles['coach'] as Map;
    if (coachData['clubs'] is List) {
      final clubs = (coachData['clubs'] as List).whereType<Map>();
      for (var club in clubs) {
        final clubId = club['clubId'] as String?;
        if (clubId != null) clubIdsSet.add(clubId);
      }
    }
  } else if (roles['coach'] is List) {
    // Ancienne structure : liste de clubIds
    clubIdsSet.addAll((roles['coach'] as List).whereType<String>());
  }

  // Admin
  if (roles['admin'] is List) {
    clubIdsSet.addAll((roles['admin'] as List).whereType<String>());
  }

  // Fallback pour compatibilité
  if (data['clubIds'] is List) {
    clubIdsSet.addAll((data['clubIds'] as List).whereType<String>());
  }
  if (data['clubId'] is String) clubIdsSet.add(data['clubId']);

  final clubIds = clubIdsSet.toList();
  for (final id in clubIds) {
    try {
      final doc = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(id)
          .get();
      final url = doc.data()?['logoUrl'] as String?;
      if (url != null && url.isNotEmpty) logos.add(url);
    } catch (e) {
      // Ignorer les erreurs de récupération
    }
  }
  return logos;
}

Future<List<String>> _fetchTeams(String clubId, String uid) async {
  final db = appFirestore;
  final playerTeams = await db
      .collection(FirebaseCollections.clubs)
      .doc(clubId)
      .collection(FirebaseCollections.teams)
      .where('playerIds', arrayContains: uid)
      .get();
  final coachTeams = await db
      .collection(FirebaseCollections.clubs)
      .doc(clubId)
      .collection(FirebaseCollections.teams)
      .where('coachIds', arrayContains: uid)
      .get();

  final names = <String>{};
  for (final doc in [...playerTeams.docs, ...coachTeams.docs]) {
    final data = doc.data();
    final name = data['name'] as String? ?? "Équipe";
    names.add(name);
  }
  return names.toList();
}
