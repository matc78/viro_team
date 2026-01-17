import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:viro_team/pages/multirole_selection_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../auth_page.dart';

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

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(title: const Text("Mon Profil")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // --- SECTION ENTÊTE ---
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: clubId.isNotEmpty
                      ? FirebaseFirestore.instance
                            .collection('clubs')
                            .doc(clubId)
                            .get()
                      : null,
                  builder: (context, snap) {
                    final logoUrl =
                        snap.data?.data()?['logoUrl'] as String? ?? "";
                    return _buildProfileHeader(
                      displayFirst,
                      displayLast,
                      role,
                      userData?['avatarUrl'],
                      () => _pickAvatar(user.uid),
                      logoUrl,
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
                  onTap: () => _changeEmail(userData?['email'] ?? user.email ?? ""),
                ),
                _buildMenuCard(
                  icon: Icons.phone_outlined,
                  title: "Changer mon téléphone",
                  subtitle: userData?['phone'] as String? ?? "Non renseigné",
                  onTap: () => _changePhone(userData?['phone'] as String? ?? ""),
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
                        builder: (_) => const MultiRoleSelectionPage(),
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
                  onTap: () => _showAdvancedSettings(context, clubId),
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

  Widget _buildProfileHeader(
    String fn,
    String ln,
    String role,
    String? avatarUrl,
    Future<void> Function() onAvatarTap,
    String? clubLogoUrl,
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
            if (clubLogoUrl != null && clubLogoUrl.isNotEmpty)
              Positioned(
                top: -4,
                right: -4,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    backgroundImage: CachedNetworkImageProvider(clubLogoUrl),
                  ),
                ),
              ),
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

                if (mounted) Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Nom du club mis à jour avec succès !"),
                  ),
                );
              } catch (e) {
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

  void _showDeleteConfirm(BuildContext context, String clubId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Action irréversible"),
        content: const Text(
          "Voulez-vous vraiment supprimer le club ? Cela déconnectera tous les membres.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              // Logique de suppression complexe (Club + Members IDs...)
              Navigator.pop(ctx);
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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

  void _showAdvancedSettings(BuildContext context, String clubId) {
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
                  // TODO: implémenter le transfert de club
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Fonction à implémenter : transfert de club",
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text("Supprimer le club"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirm(context, clubId);
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
                  _showDeleteConfirm(context, clubId);
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
                    SnackBar(content: Text("Impossible de mettre à jour le nom : $e")),
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
                            : (e.message ?? "Erreur lors du changement d'email"),
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
                    SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
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

  void _showInfoDialog(Map<String, dynamic> data, User user) {
    final first = data['firstName'] as String? ?? "À préciser";
    final last = data['lastName'] as String? ?? "À préciser";
    final email = data['email'] as String? ?? user.email ?? "À préciser";
    final phone = data['phone'] as String? ?? "À préciser";
    final createdAt = data['createdAt'];
    String createdLabel = "À préciser";
    if (createdAt is Timestamp) {
      createdLabel = DateFormat('dd/MM/yyyy').format(createdAt.toDate());
    }
    final club = data['clubName'] as String? ?? "À préciser";
    final role = data['role'] as String? ?? data['activeContext']?['role'] as String? ?? "À préciser";

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
              _infoLine("Club", club),
              _infoLine("Rôle", role == 'admin_fondateur' ? "Fondateur" : (role == 'admin' ? "Administrateur" : (role == 'coach' ? "Coach" : role))),
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

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
