import 'package:flutter/material.dart';
import 'package:viro_team/utils/auth_helper.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import '../../theme/viro_theme.dart';

class PlayerNoClubPage extends StatelessWidget {
  final String firstName;

  const PlayerNoClubPage({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Correction ici : search_off au lieu de SearchOff
              const Icon(
                Icons.search_off_rounded,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                "Bonjour $firstName,",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tu n'es membre d'aucun club pour le moment.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingPage(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.add_home_work_rounded),
                  label: const Text("Rejoindre ou créer un club"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViroColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => signOutCompletely(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text("Se déconnecter"),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
