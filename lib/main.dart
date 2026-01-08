import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/role_selection_page.dart';
import 'firebase_options.dart'; // Généré par flutterfire configure
import 'pages/auth_page.dart';
import 'pages/player_pages/home_page.dart';
import 'pages/admin_coach_pages/admin_home_page.dart';
import 'theme/viro_theme.dart';
import 'widget/viro_loader.dart';

void main() async {
  // 1. Toujours ajouter cette ligne pour Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialiser Firebase avec les options générées
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViroTeam',
      theme: ViroTheme.lightTheme, // Ton thème bleu et blanc
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: ViroLoader(size: 50)));
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: ViroLoader(size: 50)),
                  );
                }
                if (userSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(
                      child: Text("Erreur de chargement des données"),
                    ),
                  );
                }

                final data = userSnapshot.data?.data();
                final role = data?['role'] as String?;
                final hasPending = data?['hasPendingRequest'] == true;
                final hasClub = data?['clubId'] != null;

                // Pas de club et pas de demande : on retourne à la sélection de rôle
                if (!hasPending && !hasClub) {
                  return const RoleSelectionPage();
                }

                // Utilisateur connecté : on dirige vers la bonne Home
                if (role == 'admin_fondateur' || role == 'coach') {
                  return const AdminHomePage();
                }
                return const HomePage(); // par défaut la home joueur
              },
            );
          }
          return const AuthPage(); // Sinon on affiche l'écran d'auth
        },
      ),
    );
  }
}
