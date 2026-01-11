import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("Session expirée")));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Scaffold(
            body: Center(child: Text("Erreur de chargement")),
          );
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: ViroLoader(size: 80)));
        }

        final userData = snapshot.data?.data();
        final String firstName = userData?['firstName'] ?? "Admin";
        final String lastName = userData?['lastName'] ?? "";
        final String clubName = userData?['clubName'] ?? "Club non défini";
        final String clubId = userData?['clubId'] ?? "";
        final String role = userData?['role'] ?? "admin_fondateur";

        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(title: const Text("Mon Profil")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // --- SECTION ENTÊTE ---
                _buildProfileHeader(firstName, lastName, role),
                const SizedBox(height: 30),

                // --- SECTION : GESTION DU CLUB ---
                _buildSectionTitle("GESTION DU CLUB"),
                _buildMenuCard(
                  icon: Icons.edit_location_alt_outlined,
                  title: "Nom du Club",
                  subtitle: clubName,
                  onTap: () => _showEditClubName(clubId, clubName),
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
                  title: "Changer de compte",
                  subtitle: "Se déconnecter et changer de profil",
                  onTap: () => _handleSignOut(context),
                ),
                _buildMenuCard(
                  icon: Icons.lock_outline,
                  title: "Sécurité",
                  subtitle: "Modifier le mot de passe",
                  onTap: () {},
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

  Widget _buildProfileHeader(String fn, String ln, String role) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: ViroColors.primary.withOpacity(0.1),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 55,
                color: ViroColors.primary,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: ViroColors.primary,
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
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
        onTap: onTap,
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
      ),
    );
  }

  // --- LOGIQUE ACTIONS ---

  void _showEditClubName(String clubId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nom du Club"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Entrez le nouveau nom",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _firestore.collection('clubs').doc(clubId).update({
                  'name': controller.text.trim(),
                });
                await _firestore
                    .collection('users')
                    .doc(_auth.currentUser?.uid)
                    .update({'clubName': controller.text.trim()});
                if (mounted) Navigator.pop(ctx);
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
}
