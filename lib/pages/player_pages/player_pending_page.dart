import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class PlayerPendingPage extends StatefulWidget {
  final String clubName;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const PlayerPendingPage({
    super.key,
    required this.clubName,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  State<PlayerPendingPage> createState() => _PlayerPendingPageState();
}

class _PlayerPendingPageState extends State<PlayerPendingPage> {
  Future<void> _cancelRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasPendingRequest': false,
        'lastClubRequested': FieldValue.delete(),
      });
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.send_rounded,
                  size: 80,
                  color: ViroColors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Message envoyé !",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  "Ta demande pour rejoindre le club \"${widget.clubName}\" est en cours d'examen par l'administrateur.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                const ViroLoader(size: 50),
                const SizedBox(height: 20),
                const Text(
                  "On te prévient dès que c'est validé !",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.isRefreshing ? null : widget.onRefresh,
                    icon: widget.isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text("Rafraîchir le statut"),
                  ),
                ),
                TextButton(
                  onPressed: _cancelRequest,
                  child: const Text(
                    "Annuler et choisir un autre club",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
