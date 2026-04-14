import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/firebase_collections.dart';
import '../../services/user_session.dart';
import '../../widget/player_club_stats_widgets.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
import '../../services/membership_service.dart';

class ProfilDisplayPage extends StatelessWidget {
  final String userId;

  const ProfilDisplayPage({super.key, required this.userId});

  // Vérifie si l'utilisateur actuel peut gérer un membre dans un club donné
  // en se basant uniquement sur les rôles club (sans activeContext).
  Future<bool> _canManageMemberInClub(String clubId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;

    final currentUserDoc = await appFirestore
        .collection(FirebaseCollections.users)
        .doc(currentUid)
        .get();
    final currentUserData = currentUserDoc.data();
    if (currentUserData == null) return false;

    final roles = getAllUserRolesInClub(currentUserData, clubId);
    return roles.contains('coach') ||
        roles.contains('admin') ||
        roles.contains('admin_fondateur');
  }

  List<String> _extractClubIdsFromUserData(Map<String, dynamic> userData) {
    final clubIds = <String>{};
    final summaries = (userData['profileSummaries'] as List?)
            ?.whereType<Map>()
            .toList() ??
        [];
    for (final e in summaries) {
      final clubId = e['clubId'] as String?;
      if (clubId != null && clubId.isNotEmpty) {
        clubIds.add(clubId);
      }
    }
    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId != null && legacyClubId.isNotEmpty) {
      clubIds.add(legacyClubId);
    }
    return clubIds.toList();
  }

  Future<bool> _canManageMemberProfile(Map<String, dynamic> targetUserData) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;
    if (currentUid == userId) return true;

    final targetClubIds = _extractClubIdsFromUserData(targetUserData);
    for (final clubId in targetClubIds) {
      if (await _canManageMemberInClub(clubId)) {
        return true;
      }
    }
    return false;
  }

  void _showFullScreenAvatar(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullScreenAvatarView(imageUrl: imageUrl),
      ),
    );
  }

  // Vérifie si l'utilisateur actuel peut modifier la licence d'un joueur dans un club
  Future<bool> _canEditLicense(String clubId) async {
    return _canManageMemberInClub(clubId);
  }

  // Vérifie si l'utilisateur actuel peut voir la licence d'un joueur dans un club
  Future<bool> _canViewLicense(String clubId) async {
    return _canManageMemberInClub(clubId);
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
                await MembershipService.instance.updateMemberPlayer(
                  uid: userId,
                  clubId: clubId,
                  license: newVal,
                );

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
            future: _canManageMemberProfile(data),
            builder: (context, accessSnapshot) {
              final bool hasAccess = accessSnapshot.data ?? false;

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
                                      final avatar = CircleAvatar(
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
                                      if (url == null) return avatar;
                                      return GestureDetector(
                                        onTap: () =>
                                            _showFullScreenAvatar(context, url),
                                        child: avatar,
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
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Consumer<UserSession>(
                      builder: (context, session, _) {
                        final cid = session.currentClubId;
                        if (cid == null || cid.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PlayerClubStatsSection(
                            clubId: cid,
                            userData: data,
                          ),
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
          // Licence pour ce club (visible uniquement pour coach/admin/admin_fondateur du même club)
          if (roles.contains('player'))
            FutureBuilder<bool>(
              future: _canViewLicense(clubId),
              builder: (context, canViewSnap) {
                final canView = canViewSnap.data ?? false;
                if (!canView) return const SizedBox.shrink();
                final displayLicense = license ?? "";
                final hasLicense = displayLicense.isNotEmpty;
                return FutureBuilder<bool>(
                  future: _canEditLicense(clubId),
                  builder: (context, canEditSnap) {
                    final canEdit = canEditSnap.data ?? false;
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

  // Extraire les rôles organisés par club (profileSummaries + members pour licence)
  Future<List<Map<String, dynamic>>> _extractRolesByClub(
    Map<String, dynamic> userData,
  ) async {
    final Map<String, Map<String, dynamic>> clubsMap = {};
    final summaries = (userData['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
    final uid = userId;

    for (final e in summaries) {
      final clubId = e['clubId'] as String?;
      final role = e['role'] as String?;
      if (clubId == null || clubId.isEmpty || role == null || role.isEmpty) continue;
      clubsMap[clubId] ??= {'clubId': clubId, 'roles': <String>[]};
      if (!(clubsMap[clubId]!['roles'] as List<String>).contains(role)) {
        (clubsMap[clubId]!['roles'] as List<String>).add(role);
      }
    }

    // Licence et détails player depuis les documents member
    for (final clubId in clubsMap.keys) {
      final roles = clubsMap[clubId]!['roles'] as List<String>? ?? [];
      if (roles.contains('player')) {
        final member = await getMemberData(appFirestore, uid, clubId);
        final player = member?['player'] as Map<String, dynamic>?;
        final license = player?['license'] as String?;
        if (license != null && license.isNotEmpty) {
          clubsMap[clubId]!['license'] = license;
        }
      }
    }

    // Contexte actif / legacy si pas déjà dans la map
    final activeContext = userData['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String?;
    final activeRole = activeContext?['role'] as String?;
    if (activeClubId != null &&
        activeClubId.isNotEmpty &&
        !clubsMap.containsKey(activeClubId)) {
      clubsMap[activeClubId] = {
        'clubId': activeClubId,
        'roles': activeRole != null ? [activeRole] : [],
      };
    }

    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId != null && !clubsMap.containsKey(legacyClubId)) {
      final legacyRole = userData['role'] as String?;
      clubsMap[legacyClubId] = {
        'clubId': legacyClubId,
        'roles': legacyRole != null ? [legacyRole] : [],
      };
    }

    // Récupérer les infos des clubs (nom, logo)
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

class _FullScreenAvatarView extends StatelessWidget {
  const _FullScreenAvatarView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          children: [
            Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const ViroLoader(size: 48),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, size: 80, color: Colors.white70),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
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
  final summaries = (data['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
  for (final e in summaries) {
    final cid = e['clubId'] as String?;
    if (cid != null && cid.isNotEmpty) clubIdsSet.add(cid);
  }
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
