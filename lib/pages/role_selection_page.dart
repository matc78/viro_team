import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import 'player_pages/home_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isUpdating = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isUpdating = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Sauvegarde du rôle dans Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': role,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) return const Scaffold(body: ViroLoader(size: 80));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                "Bienvenue dans l'équipe !",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Text(
                "Quelle est votre mission au sein du club ?",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),

              _roleCard(
                title: "Créer un Club",
                subtitle: "Je souhaite fonder et gérer mon club",
                icon: Icons.add_business_outlined,
                onTap: () => _selectRole('admin_fondateur'),
              ),
              _roleCard(
                title: "Rejoindre (Entraîneur / Admin)",
                subtitle: "Gérer les entraînements et l'équipe",
                icon: Icons.admin_panel_settings_outlined,
                onTap: () => _selectRole('coach'),
              ),
              _roleCard(
                title: "Rejoindre (Licencié)",
                subtitle: "Consulter mon calendrier et mes services",
                icon: Icons.sports_volleyball_outlined,
                onTap: () => _selectRole('player'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: ViroColors.primary, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: ViroColors.borderColor,
        ),
        onTap: onTap,
      ),
    );
  }
}
