import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../auth_page.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Profil"),
        centerTitle: false,
        actions: [
          // Petit loader discret pour indiquer la synchronisation
          const ViroLoader(size: 20),
          const SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- HEADER PROFIL ---
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
                      // backgroundImage: AssetImage('assets/images/avatar.png'), // À utiliser plus tard
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: ViroColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Alexandre Viro",
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 22),
            ),
            const Text(
              "Membre de l'équipe Senior A",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // --- SECTION : INFORMATIONS ---
            _buildSectionHeader("MES INFORMATIONS"),
            _buildActionTile(
              Icons.badge_outlined,
              "Modifier mon nom & prénom",
              () {},
            ),
            _buildActionTile(
              Icons.alternate_email,
              "Changer d'adresse email",
              () {},
            ),
            _buildActionTile(
              Icons.lock_open_outlined,
              "Changer mon mot de passe",
              () {},
            ),

            const SizedBox(height: 30),

            // --- SECTION : CLUB & SPORT (Utile pour une app de club) ---
            _buildSectionHeader("CLUB & SPORT"),
            _buildActionTile(Icons.history, "Historique des matchs", () {}),
            _buildActionTile(
              Icons.workspace_premium_outlined,
              "Ma licence (PDF)",
              () {},
            ),
            _buildActionTile(
              Icons.notifications_none,
              "Préférences de notifications",
              () {},
            ),

            const SizedBox(height: 30),

            // --- SECTION : DANGER ZONE ---
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
  }

  // Header de section identique à la Home
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

  // Tuile d'action respectant les bordures fines du thème
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
        onTap: onTap,
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
                      const SnackBar(
                        content: Text("Utilisateur introuvable."),
                      ),
                    );
                  }
                  return;
                }

                final uid = user.uid;
                final firestore = FirebaseFirestore.instance;

                // Récupérer les infos pour nettoyer club et demandes
                final userDoc =
                    await firestore.collection('users').doc(uid).get();
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
}
