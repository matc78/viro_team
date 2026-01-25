import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/app_logger.dart';
import '../auth_page.dart';
import '../add_profile_page.dart';

class PlayerProfilPage extends StatefulWidget {
  const PlayerProfilPage({super.key});

  @override
  State<PlayerProfilPage> createState() => _PlayerProfilPageState();
}

class _PlayerProfilPageState extends State<PlayerProfilPage> {
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Utilisateur non connecté")),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: ViroLoader(size: 80));
        }
        final data = snapshot.data?.data();
        final rawFirst = data?['firstName'] as String? ?? "Sportif";
        final rawLast = data?['lastName'] as String? ?? "";
        final displayFirst = _formatFirst(rawFirst);
        final displayLast = _formatLast(rawLast);

        // Utiliser activeContext pour le club actuel
        final activeContext = data?['activeContext'] as Map<String, dynamic>?;
        final String? clubName =
            activeContext?['clubName'] as String? ??
            data?['clubName'] as String?;

        // Construire la liste de tous les clubIds depuis roles
        final roles = data?['roles'] as Map<String, dynamic>? ?? {};
        final Set<String> clubIdsSet = {};

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
        if (roles['coach'] is List) {
          for (var coach in (roles['coach'] as List)) {
            if (coach is Map) {
              final coachClubId = coach['clubId'] as String?;
              if (coachClubId != null) clubIdsSet.add(coachClubId);
            }
          }
        }

        // Admin
        if (roles['admin'] is List) {
          clubIdsSet.addAll((roles['admin'] as List).whereType<String>());
        }

        // Fallback pour compatibilité
        final legacyClubId = data?['clubId'] as String?;
        if (legacyClubId != null) clubIdsSet.add(legacyClubId);

        final List<String> clubIds = clubIdsSet.toList();
        final avatarUrl = data?['avatarUrl'] as String?;
        final email = data?['email'] as String? ?? user.email ?? "";

        return Scaffold(
          appBar: AppBar(
            title: const Text("Mon Profil"),
            centerTitle: false,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 15),
                child: ViroLoader(size: 20),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                FutureBuilder<List<String>>(
                  future: clubIds.isNotEmpty
                      ? _fetchClubLogos(clubIds)
                      : Future.value([]),
                  builder: (context, snap) {
                    final logos = snap.data ?? [];
                    return _buildHeader(
                      "$displayFirst $displayLast",
                      clubName,
                      logos,
                      avatarUrl,
                    );
                  },
                ),
                const SizedBox(height: 30),
                _buildSectionHeader("MES INFORMATIONS"),
                _buildActionTile(
                  Icons.badge_outlined,
                  "Modifier mon nom & prénom",
                  () => _editName(rawFirst, rawLast),
                ),
                _buildActionTile(
                  Icons.alternate_email,
                  "Changer d'adresse email",
                  () => _changeEmail(email),
                ),
                _buildActionTile(
                  Icons.phone_outlined,
                  "Changer mon téléphone",
                  () => _changePhone(data?['phone'] as String? ?? ""),
                ),
                _buildActionTile(
                  Icons.lock_open_outlined,
                  "Changer mon mot de passe",
                  _changePassword,
                ),
                _buildActionTile(
                  Icons.info_outline,
                  "Afficher mes infos",
                  () => _showInfoDialog(data ?? {}, user),
                ),
                const SizedBox(height: 30),

                _buildSectionHeader("PROFILS & CLUBS"),
                _buildActionTile(
                  Icons.add_circle_outline,
                  "Ajouter un profil",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddProfilePage(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                _buildSectionHeader("COMPTE & SÉCURITÉ"),
                _buildActionTile(
                  Icons.logout_rounded,
                  "Se déconnecter",
                  () => _showLogoutDialog(context),
                  isDestructive: true,
                ),
                _buildActionTile(
                  Icons.delete_forever_outlined,
                  "Supprimer mon compte",
                  () => _showDeleteDialog(context),
                  isDestructive: true,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
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

  Widget _buildHeader(
    String fullName,
    String? clubName,
    List<String> clubLogos,
    String? avatarUrl,
  ) {
    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: ViroColors.primary.withOpacity(0.1),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 55,
                        color: ViroColors.primary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _isUploadingAvatar ? null : _pickAvatar,
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
              for (int i = 0; i < clubLogos.length; i++)
                _buildSatellitePosition(i, clubLogos[i]),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          fullName.trim().isEmpty ? "Sportif" : fullName,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontSize: 22),
        ),
        Text(
          clubName ?? "Aucun club",
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 5),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    Color color = isDestructive ? Colors.redAccent : ViroColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor, width: 1.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDestructive ? Colors.redAccent : Colors.black87,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: ViroColors.borderColor,
        ),
        onTap: _isSaving ? null : onTap,
      ),
    );
  }

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
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final first = firstController.text.trim();
              final last = lastController.text.trim();
              setState(() => _isSaving = true);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                      'firstName': first,
                      'lastName': last,
                    }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showSnack("Impossible de mettre à jour le nom : $e");
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
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final newEmail = controller.text.trim();
              setState(() => _isSaving = true);
              try {
                // verifyBeforeUpdateEmail envoie un email de validation puis change l'email
                await user.verifyBeforeUpdateEmail(newEmail);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({'email': newEmail}, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
                _showSnack(
                  "Email mis à jour (vérifie ta boîte mail pour confirmer si nécessaire)",
                );
              } on FirebaseAuthException catch (e) {
                _showSnack(
                  e.code == 'requires-recent-login'
                      ? "Reconnecte-toi puis réessaie."
                      : (e.message ?? "Erreur lors du changement d'email"),
                );
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
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final newPhone = controller.text.trim();
              setState(() => _isSaving = true);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({'phone': newPhone}, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
                _showSnack("Téléphone mis à jour");
              } catch (e) {
                _showSnack("Erreur lors de la mise à jour : $e");
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
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final currentPass = currentController.text.trim();
              final newPass = newController.text.trim();
              final confirmPass = confirmController.text.trim();

              if (newPass.length < 6) {
                _showSnack(
                  "Le mot de passe doit contenir au moins 6 caractères",
                );
                return;
              }
              if (newPass != confirmPass) {
                _showSnack("Les nouveaux mots de passe ne correspondent pas");
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
                AppLogger.instance.info(
                  'Mot de passe modifié',
                  {'userId': user.uid},
                );
                if (mounted) Navigator.pop(context);
                _showSnack("Mot de passe mis à jour");
              } on FirebaseAuthException catch (e) {
                AppLogger.instance.error(
                  'Erreur lors du changement de mot de passe',
                  error: e,
                  context: {
                    'userId': user.uid,
                    'errorCode': e.code,
                  },
                );
                _showSnack(
                  e.code == 'wrong-password'
                      ? "Mot de passe actuel incorrect."
                      : (e.code == 'requires-recent-login'
                            ? "Reconnecte-toi puis réessaie."
                            : (e.message ??
                                  "Erreur lors du changement de mot de passe")),
                );
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Es-tu sûr de vouloir quitter ViroTeam ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              await FirebaseAuth.instance.signOut();
              AppLogger.instance.info(
                'Déconnexion',
                {'userId': userId},
              );
              if (!context.mounted) return;
              Navigator.pop(context); // close dialog
              _goToAuth(context);
            },
            child: const Text("OUI, QUITTER"),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Suppression du compte"),
        content: const Text(
          "Cette action est définitive. Es-tu sûr de vouloir supprimer ton compte ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog before action
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Utilisateur introuvable.")),
                    );
                  }
                  return;
                }

                final uid = user.uid;
                final firestore = FirebaseFirestore.instance;

                // Récupérer les infos pour nettoyer club et demandes
                final userDoc = await firestore
                    .collection('users')
                    .doc(uid)
                    .get();
                final data = userDoc.data();

                // Utiliser activeContext pour le club actuel
                final activeContext =
                    data?['activeContext'] as Map<String, dynamic>?;
                final clubId = activeContext?['clubId'] as String?;
                final role = activeContext?['role'] as String?;

                // Fallback pour compatibilité
                final legacyClubId = data?['clubId'] as String?;
                final legacyRole = data?['role'] as String?;
                final finalClubId = clubId ?? legacyClubId;
                final finalRole = role ?? legacyRole;

                // Retirer l'utilisateur des membres / coaches du club
                // Note: Avec la nouvelle structure, il faudrait retirer de tous les clubs
                // Pour l'instant, on retire seulement du club actif
                if (finalClubId != null) {
                  final field =
                      (finalRole == 'admin' ||
                          finalRole == 'admin_fondateur' ||
                          finalRole == 'coach')
                      ? 'coaches'
                      : 'members';
                  await firestore.collection('clubs').doc(finalClubId).update({
                    field: FieldValue.arrayRemove([uid]),
                  });
                }

                // TODO: Retirer aussi de tous les autres clubs dans roles.coach et roles.admin

                // Supprimer les demandes d'adhésion associées
                final requests = await firestore
                    .collection('join_requests')
                    .where('userId', isEqualTo: uid)
                    .get();
                for (final doc in requests.docs) {
                  await doc.reference.delete();
                }

                // Supprimer le document utilisateur
                await firestore.collection('users').doc(uid).delete();

                // Supprimer le compte Firebase Auth
                await user.delete();
                await FirebaseAuth.instance.signOut();

                if (context.mounted) _goToAuth(context);
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.code == 'requires-recent-login'
                          ? "Merci de te reconnecter puis de réessayer."
                          : (e.message ?? "Suppression impossible"),
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Suppression impossible : $e")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("OUI, SUPPRIMER"),
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
    final clubsWithRoles = await _extractRolesByClub(data);

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

  Future<List<Map<String, dynamic>>> _extractRolesByClub(
    Map<String, dynamic> data,
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
        final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
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
                  _formatRoleName(role),
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: _getRoleColor(role).withOpacity(0.1),
                labelStyle: TextStyle(
                  color: _getRoleColor(role),
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

  void _goToAuth(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _formatLast(String value) => value.toUpperCase();

  Future<List<String>> _fetchClubLogos(List<String> clubIds) async {
    final logos = <String>[];
    for (final id in clubIds) {
      final doc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(id)
          .get();
      final url = doc.data()?['logoUrl'] as String?;
      if (url != null && url.isNotEmpty) logos.add(url);
    }
    return logos;
  }

  Future<void> _pickAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;
      setState(() {
        _isSaving = true;
        _isUploadingAvatar = true;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await storageRef.putFile(File(file.path));
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'avatarUrl': url,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de changer l'avatar : $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingAvatar = false;
        });
      }
    }
  }
}
