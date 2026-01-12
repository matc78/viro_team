import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../auth_page.dart';

class PlayerProfilPage extends StatefulWidget {
  const PlayerProfilPage({super.key});

  @override
  State<PlayerProfilPage> createState() => _PlayerProfilPageState();
}

class _PlayerProfilPageState extends State<PlayerProfilPage> {
  bool _isSaving = false;

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
        final clubName = data?['clubName'] as String?;
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
                _buildHeader("$displayFirst $displayLast", clubName),
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
                  Icons.lock_open_outlined,
                  "Changer mon mot de passe",
                  _changePassword,
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

  Widget _buildHeader(String fullName, String? clubName) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ViroColors.primary, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: ViroColors.secondary,
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: ViroColors.primary,
                  ),
                ),
              ),
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
                if (mounted) Navigator.pop(context);
                _showSnack("Mot de passe mis à jour");
              } on FirebaseAuthException catch (e) {
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
              await FirebaseAuth.instance.signOut();
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
                final clubId = data?['clubId'] as String?;
                final role = data?['role'] as String?;

                // Retirer l'utilisateur des membres / coaches du club
                if (clubId != null) {
                  final field = (role == 'admin_fondateur' || role == 'coach')
                      ? 'coaches'
                      : 'members';
                  await firestore.collection('clubs').doc(clubId).update({
                    field: FieldValue.arrayRemove([uid]),
                  });
                }

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
}
