import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import 'firebase_options.dart';
import 'pages/auth_page.dart';
import 'pages/player_pages/player_home_page.dart';
import 'pages/admin_coach_pages/admin_home_page.dart';
import 'pages/splash_page.dart';
import 'services/user_session.dart';
import 'theme/viro_theme.dart';
import 'utils/firebase_error_handler.dart';
import 'widget/viro_loader.dart';

void main() async {
  // 1. Toujours ajouter cette ligne pour Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialiser Firebase avec les options générées
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Initialiser le formatage de date en arrière-plan pour ne pas bloquer le démarrage
  // La première utilisation attendra que l'initialisation soit terminée
  unawaited(initializeDateFormatting('fr_FR', null));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _currentUserId;
  final UserSession _session = UserSession();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViroTeam',
      theme: ViroTheme.lightTheme, // Ton thème bleu et blanc
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashPage(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: ViroLoader(size: 50)));
            }
            if (snapshot.hasData) {
              final user = snapshot.data!;

              // Démarrer l'écoute uniquement si l'utilisateur a changé
              // Évite les appels répétés lors des reconstructions
              if (_currentUserId != user.uid) {
                _currentUserId = user.uid;
                // Utiliser un microtask pour éviter d'appeler startListening pendant le build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _session.startListening(user.uid);
                });
              }

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: ViroLoader(size: 50)),
                    );
                  }
                  if (userSnapshot.hasError) {
                    return Scaffold(
                      body: FirebaseErrorHandler.buildErrorWidget(
                        context,
                        userSnapshot.error,
                      ),
                    );
                  }

                  final data = userSnapshot.data?.data();
                  final docExists = userSnapshot.data?.exists ?? false;

                  if (!docExists || data == null) {
                    // Document n'existe pas dans la base de données : déconnecter et rediriger vers l'authentification
                    // Cela permet à l'utilisateur de créer un compte
                    Future.microtask(() async {
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (e) {
                        // Ignorer les erreurs de déconnexion
                      }
                    });
                    // Afficher AuthPage pendant la déconnexion
                    // Le StreamBuilder se reconstruira automatiquement une fois déconnecté
                    return const AuthPage();
                  }

                  // Parse activeContext
                  final activeContext =
                      data['activeContext'] as Map<String, dynamic>?;
                  final activeRole = activeContext?['role'] as String?;
                  final activeClubId = activeContext?['clubId'] as String?;

                  // Parse roles pour vérifier s'il y a des profils
                  final roles = data['roles'] as Map<String, dynamic>? ?? {};
                  final hasPlayer = roles['player'] != null;
                  final hasCoach =
                      (roles['coach'] as List?)?.isNotEmpty ?? false;
                  final hasAdmin =
                      (roles['admin'] as List?)?.isNotEmpty ?? false;
                  final hasAnyRole = hasPlayer || hasCoach || hasAdmin;

                  // Vérifier les demandes en attente
                  final hasPending = data['hasPendingRequest'] == true;

                  // 1. Pas de profil du tout
                  if (!hasAnyRole && activeContext == null) {
                    return const OnboardingPage();
                  }

                  // 2. Demande en attente
                  if (hasPending) {
                    return const PlayerHomePage(); // PlayerPendingPage sera affichée dans PlayerHomePage
                  }

                  // 3. Profil actif
                  if (activeContext != null &&
                      activeRole != null &&
                      activeClubId != null) {
                    if (activeRole == 'admin' ||
                        activeRole == 'coach' ||
                        activeRole == 'admin_fondateur') {
                      return const AdminHomePage();
                    } else if (activeRole == 'player') {
                      return const PlayerHomePage();
                    }
                  }

                  // 4. Profils existants mais pas de contexte actif (cas rare)
                  // Forcer la sélection du premier profil disponible ou rediriger vers onboarding
                  return const OnboardingPage();
                },
              );
            }
            // Réinitialiser le userId lors de la déconnexion
            if (_currentUserId != null) {
              _currentUserId = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _session.stopListening();
              });
            }
            return const AuthPage(); // Sinon on affiche l'écran d'auth
          },
        ),
      ),
    );
  }
}
