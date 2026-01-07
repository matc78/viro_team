import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Généré par flutterfire configure
import 'pages/auth_page.dart';
import 'pages/player_pages/home_page.dart';
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
            return const HomePage(); // User déjà connecté => Home direct
          }
          return const AuthPage(); // Sinon on affiche l'écran d'auth
        },
      ),
    );
  }
}
