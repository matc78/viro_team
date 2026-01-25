import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/add_profile_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/app_logger.dart';
import '../../utils/firebase_helpers.dart';
import '../../services/user_session.dart';
import '../auth_page.dart';
import '../onboarding_page.dart';
import 'admin_home_page.dart';
import '../player_pages/player_home_page.dart';

class AdminProfilPage extends StatefulWidget {
  const AdminProfilPage({super.key});

  @override
  State<AdminProfilPage> createState() => _AdminProfilPageState();
}

class _AdminProfilPageState extends State<AdminProfilPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Session expirée")));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Erreur de chargement")),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: ViroLoader(size: 80)));
        }

        final userData = snapshot.data?.data();
        final String firstName = userData?['firstName'] ?? "Admin";
        final String lastName = userData?['lastName'] ?? "";
        final String displayFirst = _formatFirst(firstName);
        final String displayLast = _formatLast(lastName);
        final String clubName = userData?['clubName'] ?? "Club non défini";
        final String clubId = userData?['clubId'] ?? "";
        final String role = userData?['role'] ?? "admin_fondateur";

        // Extraire tous les clubIds depuis roles
        final List<String> clubIds = _extractAllClubIds(userData);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(title: const Text("Mon Profil")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // --- SECTION ENTÊTE ---
                FutureBuilder<List<String>>(
                  future: clubIds.isNotEmpty
                      ? _fetchClubLogos(clubIds)
                      : Future.value([]),
                  builder: (context, logosSnap) {
                    final clubLogos = logosSnap.data ?? [];
                    return _buildProfileHeader(
                      displayFirst,
                      displayLast,
                      role,
                      userData?['avatarUrl'],
                      () => _pickAvatar(user.uid),
                      clubLogos,
                    );
                  },
                ),
                const SizedBox(height: 30),

                // --- SECTION : MES INFORMATIONS ---
                _buildSectionTitle("MES INFORMATIONS"),
                _buildMenuCard(
                  icon: Icons.badge_outlined,
                  title: "Modifier mon nom & prénom",
                  subtitle: "$displayFirst $displayLast",
                  onTap: () => _editName(firstName, lastName),
                ),
                _buildMenuCard(
                  icon: Icons.alternate_email,
                  title: "Changer d'adresse email",
                  subtitle: userData?['email'] ?? user.email ?? "",
                  onTap: () =>
                      _changeEmail(userData?['email'] ?? user.email ?? ""),
                ),
                _buildMenuCard(
                  icon: Icons.phone_outlined,
                  title: "Changer mon téléphone",
                  subtitle: userData?['phone'] as String? ?? "Non renseigné",
                  onTap: () =>
                      _changePhone(userData?['phone'] as String? ?? ""),
                ),
                _buildMenuCard(
                  icon: Icons.lock_open_outlined,
                  title: "Changer mon mot de passe",
                  subtitle: "Modifier le mot de passe",
                  onTap: _changePassword,
                ),
                _buildMenuCard(
                  icon: Icons.info_outline,
                  title: "Afficher mes infos",
                  subtitle: "Voir toutes mes informations",
                  onTap: () => _showInfoDialog(userData ?? {}, user),
                ),
                const SizedBox(height: 30),

                // --- SECTION : GESTION DU CLUB ---
                _buildSectionTitle("GESTION DU CLUB"),
                _buildMenuCard(
                  icon: Icons.edit_location_alt_outlined,
                  title: "Changer Nom du Club",
                  subtitle: clubName,
                  onTap: () => _showEditClubName(clubId, clubName),
                ),
                _buildMenuCard(
                  icon: Icons.image_outlined,
                  title: "Changer le logo du club",
                  subtitle: "Ajouter ou mettre à jour",
                  onTap: () => _pickClubLogo(clubId),
                ),
                if (getAllUserRolesInClub(userData ?? {}, clubId)
                    .contains('admin_fondateur'))
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('clubs')
                        .doc(clubId)
                        .snapshots(),
                    builder: (context, clubSnap) {
                      DateTime? seasonEndDate;
                      if (clubSnap.hasData) {
                        final clubData = clubSnap.data?.data();
                        final timestamp = clubData?['seasonEndDate'] as Timestamp?;
                        if (timestamp != null) {
                          seasonEndDate = timestamp.toDate();
                        } else {
                          // Valeur par défaut si non définie
                          final now = DateTime.now();
                          seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
                        }
                      } else {
                        final now = DateTime.now();
                        seasonEndDate = DateTime(now.year, 7, 31, 23, 59);
                      }

                      final dateStr = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR')
                          .format(seasonEndDate);

                      return _buildMenuCard(
                        icon: Icons.calendar_today_outlined,
                        title: "Date de fin de saison",
                        subtitle: dateStr,
                        onTap: () => _showEditSeasonEndDate(clubId, seasonEndDate),
                      );
                    },
                  ),
                _buildMenuCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: "Gérer les privilèges",
                  subtitle: "Promouvoir ou révoquer des membres",
                  onTap: () {
                    // TODO: Navigation vers la page de gestion des rôles
                  },
                ),
                _buildMenuCard(
                  icon: Icons.file_present_outlined,
                  title: "Documents du Club",
                  subtitle: "Statuts, assurances, RIB...",
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // --- SECTION : COMPTE ---
                _buildSectionTitle("PARAMÈTRES DU COMPTE"),
                _buildMenuCard(
                  icon: Icons.switch_account_outlined,
                  title: "Ajouter un nouveau profil",
                  subtitle:
                      "Création d'un compte joueur/coach ou d'un nouveau club",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddProfilePage(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  icon: Icons.notifications_active_outlined,
                  title: "Notifications",
                  subtitle: "Alertes nouvelles demandes",
                  onTap: () {},
                ),

                const SizedBox(height: 40),

                _buildSectionTitle("PARAMÈTRES AVANCÉS"),
                _buildMenuCard(
                  icon: Icons.settings_applications_outlined,
                  title: "Paramètres avancés",
                  subtitle: "Déconnexion, transfert et suppression",
                  onTap: () => _showAdvancedSettings(context, userData ?? {}),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- COMPOSANTS UI ---

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

  Widget _buildProfileHeader(
    String fn,
    String ln,
    String role,
    String? avatarUrl,
    Future<void> Function() onAvatarTap,
    List<String> clubLogos,
  ) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: ViroColors.primary.withOpacity(0.1),
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 55,
                      color: ViroColors.primary,
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: InkWell(
                onTap: _isUploadingAvatar
                    ? null
                    : () {
                        onAvatarTap();
                      },
                borderRadius: BorderRadius.circular(18),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: ViroColors.primary,
                  child: _isUploadingAvatar
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
            // Satellites des clubs
            for (int i = 0; i < clubLogos.length; i++)
              _buildSatellitePosition(i, clubLogos[i]),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "$fn $ln",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: ViroColors.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            role == 'admin_fondateur' ? "FONDATEUR" : "COACH / ADMIN",
            style: const TextStyle(
              color: ViroColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
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

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ViroColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ViroColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: ViroColors.borderColor,
        ),
        onTap: _isSaving ? null : onTap,
      ),
    );
  }

  // --- LOGIQUE ACTIONS ---

  void _showEditClubName(String clubId, String currentName) {
    // On utilise deux contrôleurs distincts
    final currentNameVerifyController = TextEditingController();
    final newNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Changer Nom du Club"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Écrire exactement le nom actuel pour confirmer :",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Actuellement : $currentName",
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: currentNameVerifyController,
              enableInteractiveSelection: false, // Désactive copier/coller
              decoration: InputDecoration(
                hintText: currentName, // Hint demandé
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Saisir le nouveau nom du club :",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newNameController,
              decoration: InputDecoration(
                hintText: "Saisir nouveau nom", // Hint demandé
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              String verifyInput = currentNameVerifyController.text.trim();
              String newNameInput = newNameController.text.trim();

              // Vérification de sécurité
              if (verifyInput != currentName) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Le nom actuel saisi est incorrect."),
                  ),
                );
                return;
              }

              if (newNameInput.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Le nouveau nom ne peut pas être vide."),
                  ),
                );
                return;
              }

              // Si tout est bon, on met à jour
              try {
                await _firestore.collection('clubs').doc(clubId).update({
                  'name': newNameInput,
                });
                await _firestore
                    .collection('users')
                    .doc(_auth.currentUser?.uid)
                    .update({'clubName': newNameInput});

                AppLogger.instance.info(
                  'Nom du club modifié',
                  {
                    'clubId': clubId,
                    'oldName': currentName,
                    'newName': newNameInput,
                    'userId': _auth.currentUser?.uid,
                  },
                );

                if (mounted) Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Nom du club mis à jour avec succès !"),
                  ),
                );
              } catch (e) {
                AppLogger.instance.error(
                  'Erreur lors de la modification du nom du club',
                  error: e,
                  context: {
                    'clubId': clubId,
                    'userId': _auth.currentUser?.uid,
                    'newName': newNameInput,
                  },
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  void _showDeleteClubConfirm(BuildContext context, String clubId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Action irréversible"),
        content: const Text(
          "Voulez-vous vraiment supprimer ce club ? Le club, ses équipes, "
          "événements et annonces seront supprimés. Tous les membres seront retirés du club.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteClub(context, clubId);
            },
            child: const Text(
              "SUPPRIMER LE CLUB",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer mon compte"),
        content: const Text(
          "Voulez-vous vraiment supprimer définitivement votre compte ? "
          "Cette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount(context);
            },
            child: const Text(
              "SUPPRIMER MON COMPTE",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Retourne le premier (role, clubId) autre que [excludeClubId] depuis [userData].
  ({String role, String clubId})? _getFirstOtherProfile(
    Map<String, dynamic> userData,
    String excludeClubId,
  ) {
    final roles = userData['roles'] as Map<String, dynamic>? ?? {};
    // Admin
    if (roles['admin'] is List) {
      for (final cid in (roles['admin'] as List).whereType<String>()) {
        if (cid != excludeClubId && cid.isNotEmpty) {
          return (role: 'admin', clubId: cid);
        }
      }
    }
    // Coach
    if (roles['coach'] is List) {
      for (final e in (roles['coach'] as List)) {
        if (e is Map) {
          final cid = e['clubId'] as String?;
          if (cid != null && cid != excludeClubId && cid.isNotEmpty) {
            return (role: 'coach', clubId: cid);
          }
        }
      }
    }
    if (roles['coach'] is List) {
      for (final cid in (roles['coach'] as List).whereType<String>()) {
        if (cid != excludeClubId && cid.isNotEmpty) {
          return (role: 'coach', clubId: cid);
        }
      }
    }
    // Player
    if (roles['player'] is Map) {
      final pd = roles['player'] as Map;
      if (pd['clubs'] is List) {
        for (final c in (pd['clubs'] as List).whereType<Map>()) {
          final cid = c['clubId'] as String?;
          if (cid != null && cid != excludeClubId && cid.isNotEmpty) {
            return (role: 'player', clubId: cid);
          }
        }
      }
      final legacy = pd['clubId'] as String?;
      if (legacy != null && legacy != excludeClubId && legacy.isNotEmpty) {
        return (role: 'player', clubId: legacy);
      }
    }
    final legacyClubId = userData['clubId'] as String?;
    if (legacyClubId != null &&
        legacyClubId != excludeClubId &&
        legacyClubId.isNotEmpty) {
      final r = userData['role'] as String?;
      return (role: r == 'admin_fondateur' ? 'admin' : (r ?? 'admin'), clubId: legacyClubId);
    }
    return null;
  }

  /// Retourne les [roles] mis à jour après retrait de [clubId].
  Map<String, dynamic> _buildRolesAfterRemoveClub(
    Map<String, dynamic>? roles,
    String clubId,
  ) {
    final r = Map<String, dynamic>.from(roles ?? {});
    if (r['admin'] is List) {
      final list = (r['admin'] as List).whereType<String>().where((c) => c != clubId).toList();
      r['admin'] = list;
    }
    if (r['coach'] is List) {
      final list = (r['coach'] as List).toList();
      final filtered = <dynamic>[];
      for (final e in list) {
        if (e is Map) {
          final cid = e['clubId'] as String?;
          if (cid != clubId) filtered.add(e);
        } else if (e is String && e != clubId) {
          filtered.add(e);
        }
      }
      r['coach'] = filtered;
    }
    if (r['player'] is Map) {
      final pd = Map<String, dynamic>.from(r['player'] as Map);
      if (pd['clubs'] is List) {
        final clubs = (pd['clubs'] as List)
            .whereType<Map>()
            .where((c) => (c['clubId'] as String?) != clubId)
            .toList();
        pd['clubs'] = clubs;
        r['player'] = pd;
      } else if (pd['clubId'] == clubId) {
        pd.remove('clubId');
        r['player'] = pd;
      }
    }
    return r;
  }

  Future<void> _deleteClub(BuildContext context, String clubId) async {
    if (clubId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun club sélectionné.")),
        );
      }
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final usersSnap = await _firestore.collection('users').get();
      final affected = usersSnap.docs.where((d) {
        final data = d.data();
        return userBelongsToClub(data, clubId);
      }).toList();

      Map<String, dynamic>? currentUserData;
      ({String role, String clubId})? otherProfile;
      for (final d in affected) {
        if (d.id == userId) {
          currentUserData = d.data();
          otherProfile = _getFirstOtherProfile(currentUserData, clubId);
          break;
        }
      }

      final batch = _firestore.batch();
      for (final doc in affected) {
        final data = doc.data();
        final updatedRoles = _buildRolesAfterRemoveClub(
          data['roles'] as Map<String, dynamic>?,
          clubId,
        );
        final isCurrent = doc.id == userId;
        final other = isCurrent ? otherProfile : _getFirstOtherProfile(data, clubId);
        final activeContext = data['activeContext'] as Map<String, dynamic>?;
        final activeClub = activeContext?['clubId'] as String?;
        Object? newActiveContext;
        if (activeClub == clubId) {
          if (other != null) {
            newActiveContext = {'role': other.role, 'clubId': other.clubId};
          } else {
            newActiveContext = FieldValue.delete();
          }
        }

        final updates = <String, dynamic>{
          'roles': updatedRoles,
          if (newActiveContext != null) 'activeContext': newActiveContext,
        };
        final legacyClubId = data['clubId'] as String?;
        if (legacyClubId == clubId) {
          if (other != null) {
            updates['clubId'] = other.clubId;
            final clubDoc = await _firestore.collection('clubs').doc(other.clubId).get();
            final name = clubDoc.data()?['name'] as String?;
            if (name != null) updates['clubName'] = name;
          } else {
            updates['clubId'] = FieldValue.delete();
            updates['clubName'] = FieldValue.delete();
          }
        }

        batch.set(doc.reference, updates, SetOptions(merge: true));
      }

      await batch.commit();

      final joinRequests = await _firestore
          .collection('join_requests')
          .where('clubId', isEqualTo: clubId)
          .get();
      final jrBatch = _firestore.batch();
      for (final d in joinRequests.docs) {
        jrBatch.delete(d.reference);
      }
      if (joinRequests.docs.isNotEmpty) await jrBatch.commit();

      final teamsRef = _firestore.collection('clubs').doc(clubId).collection('teams');
      final teamsSnap = await teamsRef.get();
      final tBatch = _firestore.batch();
      for (final d in teamsSnap.docs) tBatch.delete(d.reference);
      if (teamsSnap.docs.isNotEmpty) await tBatch.commit();

      final eventsRef = _firestore.collection('clubs').doc(clubId).collection('events');
      final eventsSnap = await eventsRef.get();
      final eBatch = _firestore.batch();
      for (final d in eventsSnap.docs) eBatch.delete(d.reference);
      if (eventsSnap.docs.isNotEmpty) await eBatch.commit();

      final annRef = _firestore.collection('clubs').doc(clubId).collection('announcements');
      final annSnap = await annRef.get();
      final aBatch = _firestore.batch();
      for (final d in annSnap.docs) aBatch.delete(d.reference);
      if (annSnap.docs.isNotEmpty) await aBatch.commit();

      await _firestore.collection('clubs').doc(clubId).delete();

      try {
        final storageRef = FirebaseStorage.instance.ref().child('clubs').child(clubId);
        final list = await storageRef.listAll();
        for (final ref in list.items) await ref.delete();
        for (final pre in list.prefixes) {
          final sub = await pre.listAll();
          for (final ref in sub.items) await ref.delete();
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();
      if (otherProfile != null) {
        final session = UserSession();
        await session.switchContext(otherProfile.role, otherProfile.clubId);
        if (!mounted) return;
        if (otherProfile.role == 'player') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PlayerHomePage()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminHomePage()),
            (route) => false,
          );
        }
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression du club : $e")),
        );
      }
      AppLogger.instance.error('Suppression club', error: e, context: {'clubId': clubId});
    } finally {}
  }

  Future<void> _showTransferClub(BuildContext context, String clubId) async {
    if (clubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun club sélectionné.")),
      );
      return;
    }
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final usersSnap = await _firestore.collection('users').get();
    final allDocs = usersSnap.docs;
    final inClub = filterUsersByClub(allDocs, clubId);
    final candidates = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in inClub) {
      if (d.id == userId) continue;
      final r = getUserRoleInClub(d.data()!, clubId);
      if (r == 'admin' || r == 'coach' || r == 'admin_fondateur') {
        candidates.add(d);
      }
    }

    if (!context.mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Aucun autre admin ou coach dans ce club. Ajoutez-en un avant de transférer.",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Transférer la propriété du club",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choisir le nouveau propriétaire (admin ou coach) :",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final doc = candidates[index];
                    final data = doc.data()!;
                    final fn = data['firstName'] as String? ?? '';
                    final ln = data['lastName'] as String? ?? '';
                    final name = '$fn $ln'.trim();
                    final r = getUserRoleInClub(data, clubId) ?? '';
                    final roleLabel = r == 'admin_fondateur' || r == 'admin'
                        ? 'Admin'
                        : r == 'coach'
                            ? 'Coach'
                            : r;
                    return ListTile(
                      title: Text(name.isEmpty ? doc.id : name),
                      subtitle: Text(roleLabel),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmAndExecuteTransfer(
                          context,
                          clubId,
                          doc.id,
                          name.isEmpty ? doc.id : name,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAndExecuteTransfer(
    BuildContext context,
    String clubId,
    String newOwnerId,
    String newOwnerName,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer le transfert"),
        content: Text(
          "Transférer la propriété du club à $newOwnerName ? "
          "Vous ne serez plus administrateur de ce club.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeTransferClub(context, clubId, newOwnerId);
            },
            child: const Text("Transférer"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransferClub(
    BuildContext context,
    String clubId,
    String newOwnerId,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final clubRef = _firestore.collection('clubs').doc(clubId);
      final clubSnap = await clubRef.get();
      final clubData = clubSnap.data();
      if (clubData == null) throw Exception("Club introuvable");

      final admins = List<String>.from(
        (clubData['admins'] as List?)?.whereType<String>() ?? [],
      );
      if (!admins.contains(newOwnerId)) admins.add(newOwnerId);
      admins.remove(userId);

      await clubRef.update({
        'adminId': newOwnerId,
        'admins': admins,
      });

      final newOwnerRef = _firestore.collection('users').doc(newOwnerId);
      final newOwnerSnap = await newOwnerRef.get();
      final newOwnerData = newOwnerSnap.data() ?? {};
      final roles = Map<String, dynamic>.from(
        newOwnerData['roles'] as Map<String, dynamic>? ?? {},
      );
      final adminList = List<String>.from(
        (roles['admin'] as List?)?.whereType<String>() ?? [],
      );
      if (!adminList.contains(clubId)) adminList.add(clubId);
      roles['admin'] = adminList;
      await newOwnerRef.set({'roles': roles}, SetOptions(merge: true));

      final currentUserRef = _firestore.collection('users').doc(userId);
      final currentSnap = await currentUserRef.get();
      final currentData = currentSnap.data() ?? {};
      final updatedRoles = _buildRolesAfterRemoveClub(
        currentData['roles'] as Map<String, dynamic>?,
        clubId,
      );
      final other = _getFirstOtherProfile(currentData, clubId);
      final newActiveContext = other != null
          ? {'role': other.role, 'clubId': other.clubId}
          : FieldValue.delete();
      final updates = <String, dynamic>{
        'roles': updatedRoles,
        'activeContext': newActiveContext,
      };
      final legacyClubId = currentData['clubId'] as String?;
      if (legacyClubId == clubId) {
        if (other != null) {
          updates['clubId'] = other.clubId;
          final clubDoc = await _firestore.collection('clubs').doc(other.clubId).get();
          final name = clubDoc.data()?['name'] as String?;
          if (name != null) updates['clubName'] = name;
        } else {
          updates['clubId'] = FieldValue.delete();
          updates['clubName'] = FieldValue.delete();
        }
      }
      await currentUserRef.set(updates, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop();
      if (other != null) {
        final session = UserSession();
        await session.switchContext(other.role, other.clubId);
        if (!mounted) return;
        if (other.role == 'player') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PlayerHomePage()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminHomePage()),
            (route) => false,
          );
        }
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du transfert : $e")),
        );
      }
      AppLogger.instance.error(
        'Transfert club',
        error: e,
        context: {'clubId': clubId, 'newOwnerId': newOwnerId},
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final joinReq = await _firestore
          .collection('join_requests')
          .where('userId', isEqualTo: uid)
          .get();
      final jrBatch = _firestore.batch();
      for (final d in joinReq.docs) jrBatch.delete(d.reference);
      if (joinReq.docs.isNotEmpty) await jrBatch.commit();
    } catch (_) {}

    try {
      final clubsSnap = await _firestore.collection('clubs').get();
      for (final clubDoc in clubsSnap.docs) {
        final teamsSnap = await _firestore
            .collection('clubs')
            .doc(clubDoc.id)
            .collection('teams')
            .get();
        for (final teamDoc in teamsSnap.docs) {
          final d = teamDoc.data();
          final playerIds = List<String>.from(
            (d['playerIds'] as List?)?.whereType<String>() ?? [],
          );
          final coachIds = List<String>.from(
            (d['coachIds'] as List?)?.whereType<String>() ?? [],
          );
          if (playerIds.contains(uid) || coachIds.contains(uid)) {
            playerIds.remove(uid);
            coachIds.remove(uid);
            await teamDoc.reference.update({
              'playerIds': playerIds,
              'coachIds': coachIds,
            });
          }
        }
      }
    } catch (_) {}

    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (_) {}

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        if (e.code == 'requires-recent-login') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Cette action requiert une reconnexion récente. "
                "Déconnectez-vous puis reconnectez-vous, puis réessayez.",
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur suppression compte : ${e.message}")),
          );
        }
      }
      return;
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur suppression compte : $e")),
        );
      }
      return;
    }

    try {
      await _auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  Future<void> _pickClubLogo(String clubId) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return; // annulé par l'utilisateur

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('clubs')
          .child(clubId)
          .child('logo_${DateTime.now().millisecondsSinceEpoch}.png');

      await storageRef.putFile(File(file.path));
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('clubs').doc(clubId).set({
        'logoUrl': url,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logo mis à jour avec succès")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du changement de logo : $e")),
      );
    }
  }

  Future<void> _showEditSeasonEndDate(
    String clubId,
    DateTime? currentDate,
  ) async {
    // Valeur par défaut si non définie
    final now = DateTime.now();
    final initialDate = currentDate ?? DateTime(now.year, 7, 31, 23, 59);
    DateTime selectedDate = initialDate;
    TimeOfDay selectedTime = TimeOfDay(
      hour: initialDate.hour,
      minute: initialDate.minute,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Modifier la date de fin de saison"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sélectionnez la date et l'heure de fin de saison :",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: ViroColors.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy', 'fr_FR')
                                .format(selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: ViroColors.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final finalDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  Navigator.pop(ctx, {
                    'date': finalDateTime,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViroColors.primary,
                ),
                child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result['date'] != null) {
      final newDate = result['date'] as DateTime;
      
      // Vérifier combien d'événements sont après la nouvelle date
      try {
        final eventsQuery = await _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('events')
            .where('date', isGreaterThan: Timestamp.fromDate(newDate))
            .get();
        
        final eventsToDelete = eventsQuery.docs;
        final eventsCount = eventsToDelete.length;
        
        // Afficher un dialog de confirmation si des événements seront supprimés
        if (eventsCount > 0) {
          final confirmDelete = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Confirmation de suppression"),
              content: Text(
                "$eventsCount événement${eventsCount > 1 ? 's' : ''} ${eventsCount > 1 ? 'seront' : 'sera'} supprimé${eventsCount > 1 ? 's' : ''} car ${eventsCount > 1 ? 'ils sont' : 'il est'} après la nouvelle date de fin de saison.\n\n"
                "Souhaitez-vous continuer ?",
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text("Supprimer et continuer", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          
          if (confirmDelete != true) {
            return; // L'utilisateur a annulé
          }
        }
        
        // Supprimer les événements après la nouvelle date
        if (eventsCount > 0) {
          final batch = _firestore.batch();
          for (var doc in eventsToDelete) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          
          AppLogger.instance.info(
            'Événements supprimés après modification de la date de fin de saison',
            {
              'clubId': clubId,
              'eventsCount': eventsCount,
              'newSeasonEndDate': newDate.toIso8601String(),
              'userId': _auth.currentUser?.uid,
            },
          );
        }
        
        // Sauvegarder la nouvelle date de fin de saison
        await _firestore.collection('clubs').doc(clubId).set({
          'seasonEndDate': Timestamp.fromDate(newDate),
        }, SetOptions(merge: true));

        AppLogger.instance.info(
          'Date de fin de saison modifiée',
          {
            'clubId': clubId,
            'newDate': newDate.toIso8601String(),
            'eventsDeleted': eventsCount,
            'userId': _auth.currentUser?.uid,
          },
        );

        if (mounted) {
          final message = eventsCount > 0
              ? "Date de fin de saison mise à jour. $eventsCount événement${eventsCount > 1 ? 's supprimé' : ' supprimé'}."
              : "Date de fin de saison mise à jour avec succès !";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        AppLogger.instance.error(
          'Erreur lors de la modification de la date de fin de saison',
          error: e,
          context: {
            'clubId': clubId,
            'userId': _auth.currentUser?.uid,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur : $e")),
          );
        }
      }
    }
  }

  void _showAdvancedSettings(
    BuildContext context,
    Map<String, dynamic> userData,
  ) {
    final activeContext = userData['activeContext'] as Map<String, dynamic>?;
    final activeClubId = activeContext?['clubId'] as String? ??
        userData['clubId'] as String? ??
        '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Paramètres avancés",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Se déconnecter"),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSignOut(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                title: const Text("Transférer le club"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransferClub(context, activeClubId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text("Supprimer le club"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteClubConfirm(context, activeClubId);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
                title: const Text("Supprimer mon compte"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountConfirm(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).set({
        'avatarUrl': url,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de mettre à jour l'avatar : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _formatFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _formatLast(String value) => value.toUpperCase();

  // --- MÉTHODES D'ÉDITION DES INFORMATIONS PERSONNELLES ---

  Future<void> _editName(String currentFirst, String currentLast) async {
    final firstController = TextEditingController(text: currentFirst);
    final lastController = TextEditingController(text: currentLast);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier le nom"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstController,
              decoration: const InputDecoration(labelText: "Prénom"),
            ),
            TextField(
              controller: lastController,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;
              final first = firstController.text.trim();
              final last = lastController.text.trim();
              setState(() => _isSaving = true);
              try {
                await _firestore.collection('users').doc(user.uid).set({
                  'firstName': first,
                  'lastName': last,
                }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nom mis à jour avec succès")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Impossible de mettre à jour le nom : $e"),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Changer l'email"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nouvel email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;
              final newEmail = controller.text.trim();
              setState(() => _isSaving = true);
              try {
                // verifyBeforeUpdateEmail envoie un email de validation puis change l'email
                await user.verifyBeforeUpdateEmail(newEmail);
                await _firestore.collection('users').doc(user.uid).set({
                  'email': newEmail,
                }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Email mis à jour (vérifiez votre boîte mail pour confirmer si nécessaire)",
                      ),
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.code == 'requires-recent-login'
                            ? "Reconnectez-vous puis réessayez."
                            : (e.message ??
                                  "Erreur lors du changement d'email"),
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhone(String currentPhone) async {
    final controller = TextEditingController(text: currentPhone);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Changer le téléphone"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: "Nouveau numéro"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;
              final newPhone = controller.text.trim();
              setState(() => _isSaving = true);
              try {
                await _firestore.collection('users').doc(user.uid).set({
                  'phone': newPhone,
                }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Téléphone mis à jour")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur lors de la mise à jour : $e"),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Changer le mot de passe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Mot de passe actuel",
              ),
            ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Nouveau mot de passe",
              ),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirmer le nouveau mot de passe",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;

              final currentPass = currentController.text.trim();
              final newPass = newController.text.trim();
              final confirmPass = confirmController.text.trim();

              if (newPass.length < 6) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Le mot de passe doit contenir au moins 6 caractères",
                      ),
                    ),
                  );
                }
                return;
              }
              if (newPass != confirmPass) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Les nouveaux mots de passe ne correspondent pas",
                      ),
                    ),
                  );
                }
                return;
              }

              setState(() => _isSaving = true);
              try {
                // Re-auth pour sécurité
                final credential = EmailAuthProvider.credential(
                  email: user.email ?? "",
                  password: currentPass,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPass);
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mot de passe mis à jour")),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.code == 'wrong-password'
                            ? "Mot de passe actuel incorrect."
                            : (e.code == 'requires-recent-login'
                                  ? "Reconnectez-vous puis réessayez."
                                  : (e.message ??
                                        "Erreur lors du changement de mot de passe")),
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfoDialog(Map<String, dynamic> data, User user) async {
    final first = data['firstName'] as String? ?? "À préciser";
    final last = data['lastName'] as String? ?? "À préciser";
    final email = data['email'] as String? ?? user.email ?? "À préciser";
    final phone = data['phone'] as String? ?? "À préciser";
    final createdAt = data['createdAt'];
    String createdLabel = "À préciser";
    if (createdAt is Timestamp) {
      createdLabel = DateFormat('dd/MM/yyyy').format(createdAt.toDate());
    }

    // Extraire tous les clubs et rôles
    final clubsWithRoles = await _extractRolesByClubForInfo(data, user.uid);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mes informations"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine("Nom", _formatLast(last)),
              _infoLine("Prénom", _formatFirst(first)),
              _infoLine("Email", email),
              _infoLine("Téléphone", phone),
              _infoLine("Date de création", createdLabel),
              const SizedBox(height: 16),
              if (clubsWithRoles.isNotEmpty) ...[
                const Divider(),
                const Text(
                  "CLUBS & RÔLES",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...clubsWithRoles.map((clubInfo) {
                  return _buildClubInfoInDialog(clubInfo, user.uid);
                }),
              ] else
                _infoLine("Clubs", "Aucun club"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _extractRolesByClubForInfo(
    Map<String, dynamic> data,
    String userId,
  ) async {
    final Map<String, Map<String, dynamic>> clubsMap = {};
    final roles = data['roles'] as Map<String, dynamic>? ?? {};

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

    // 3. Extraire les rôles COACH
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
    final legacyClubId = data['clubId'] as String?;
    if (legacyClubId != null && !clubsMap.containsKey(legacyClubId)) {
      final legacyRole = data['role'] as String?;
      clubsMap[legacyClubId] = {
        'clubId': legacyClubId,
        'roles': legacyRole != null ? [legacyRole] : [],
      };
    }

    // 5. Récupérer les infos des clubs (nom, logo) et les équipes
    final List<Map<String, dynamic>> result = [];
    for (var entry in clubsMap.entries) {
      final clubId = entry.key;
      final clubInfo = entry.value;

      try {
        final clubDoc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .get();
        final clubData = clubDoc.data();
        clubInfo['clubName'] = (clubData?['name'] as String?) ?? "Club inconnu";

        // Récupérer les équipes pour ce club
        final teams = await _fetchTeamsForClub(clubId, userId);
        clubInfo['teams'] = teams;
      } catch (e) {
        clubInfo['clubName'] = "Club inconnu";
        clubInfo['teams'] = <String>[];
      }

      result.add(clubInfo);
    }

    return result;
  }

  Future<List<String>> _fetchTeamsForClub(String clubId, String userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final playerTeams = await db
          .collection('clubs')
          .doc(clubId)
          .collection('teams')
          .where('playerIds', arrayContains: userId)
          .get();
      final coachTeams = await db
          .collection('clubs')
          .doc(clubId)
          .collection('teams')
          .where('coachIds', arrayContains: userId)
          .get();

      final names = <String>{};
      for (var doc in [...playerTeams.docs, ...coachTeams.docs]) {
        final teamData = doc.data();
        final name = teamData['name'] as String?;
        if (name != null && name.isNotEmpty) names.add(name);
      }
      return names.toList();
    } catch (e) {
      return [];
    }
  }

  Widget _buildClubInfoInDialog(Map<String, dynamic> clubInfo, String userId) {
    final clubName = clubInfo['clubName'] as String? ?? "Club inconnu";
    final roles = clubInfo['roles'] as List<String>;
    final license = clubInfo['license'] as String?;
    final teams = clubInfo['teams'] as List<String>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clubName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: roles.map((role) {
              return Chip(
                label: Text(
                  _formatRoleNameForInfo(role),
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: _getRoleColorForInfo(role).withOpacity(0.1),
                labelStyle: TextStyle(
                  color: _getRoleColorForInfo(role),
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          if (license != null && license.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoLine("Licence", license, compact: true),
          ],
          if (teams.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoLine("Équipe(s)", teams.join(", "), compact: true),
          ],
        ],
      ),
    );
  }

  String _formatRoleNameForInfo(String role) {
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

  Color _getRoleColorForInfo(String role) {
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

  Widget _infoLine(String label, String value, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4.0 : 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black54,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Extraire tous les clubIds depuis roles
  List<String> _extractAllClubIds(Map<String, dynamic>? userData) {
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
    final legacyClubId = userData?['clubId'] as String?;
    if (legacyClubId != null) clubIdsSet.add(legacyClubId);

    return clubIdsSet.toList();
  }

  // Récupérer les logos des clubs
  Future<List<String>> _fetchClubLogos(List<String> clubIds) async {
    final logos = <String>[];
    for (final id in clubIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('clubs')
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
}
