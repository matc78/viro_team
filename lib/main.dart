import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import 'firebase_options.dart';
import 'pages/admin_coach_pages/admin_club_communication_page.dart';
import 'pages/admin_coach_pages/admin_home_page.dart';
import 'pages/admin_coach_pages/admin_loans_page.dart';
import 'pages/auth_page.dart';
import 'pages/no_internet_page.dart';
import 'pages/player_pages/player_home_page.dart';
import 'pages/player_pages/player_event_details_page.dart';
import 'pages/player_pages/player_loan_catalog_page.dart';
import 'pages/splash_page.dart';
import 'notifications/notifications.dart';
import 'services/notification_service.dart';
import 'services/user_session.dart';
import 'theme/viro_theme.dart';
import 'utils/app_logger.dart';
import 'utils/connectivity_checker.dart';
import 'utils/firebase_error_handler.dart';
import 'widget/fatal_error_app.dart';
import 'widget/viro_loader.dart';

/// Handler pour les messages FCM reçus en arrière-plan (obligatoire sur Android).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // La notif est affichée par le système ; le tap est géré par getInitialMessage / onMessageOpenedApp
}

void main() {
  // Wrapper avec runZonedGuarded pour capturer toutes les erreurs asynchrones
  runZonedGuarded(
    () async {
      // 1. Toujours ajouter cette ligne pour Firebase
      WidgetsFlutterBinding.ensureInitialized();

      try {
        // 2. Initialiser Firebase avec les options générées
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // 2.3. Enregistrer le handler FCM en arrière-plan (obligatoire sur Android)
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // 2.5. Initialiser le logger
        AppLogger.instance.init();

        // 3. Configurer Firebase Crashlytics
        // Passer les erreurs Flutter à Crashlytics
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };
        // Passer les erreurs asynchrones non capturées à Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        // 4. Initialiser le formatage de date en arrière-plan pour ne pas bloquer le démarrage
        // La première utilisation attendra que l'initialisation soit terminée
        unawaited(initializeDateFormatting('fr_FR', null));

        // 5. Initialiser FCM (notifications push)
        unawaited(NotificationService.instance.init());

        // 6. Lancer l'application principale
        runApp(const MyApp());
      } catch (error, stackTrace) {
        // En cas d'erreur lors de l'initialisation (ex: Firebase échoue)
        // Essayer d'enregistrer dans Crashlytics si disponible
        try {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            fatal: true,
          );
        } catch (_) {
          // Si Crashlytics n'est pas disponible, on continue quand même
        }

        // Afficher une page d'erreur fatale au lieu de crasher
        runApp(FatalErrorApp(error: error, stackTrace: stackTrace));
      }
    },
    (error, stack) {
      // Gestionnaire d'erreurs asynchrones non capturées
      // Ces erreurs se produisent dans des Futures, Streams, etc. qui ne sont pas await
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        // Si Crashlytics n'est pas disponible, on log quand même l'erreur
        AppLogger.instance.error(
          'Erreur asynchrone non capturée',
          error: error,
          stackTrace: stack,
        );
      }
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String? _currentUserId;
  final UserSession _session = UserSession();
  bool _hasInternet = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnection();
    _setupNotificationHandlers();
  }

  void _setupNotificationHandlers() {
    // Atterrir sur la home admin : un autre admin a pu déjà accepter/refuser la demande
    JoinRequestNotification.onOpen = (_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => const AdminHomePage(),
        ),
      );
    };
    LoanRequestNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      if (clubId != null && clubId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => AdminLoansPage(
              clubId: clubId,
              initialTabIndex: 1,
            ),
          ),
        );
      }
    };
    JoinRequestResponseNotification.onOpen = (payload) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const OnboardingPage(),
        ),
        (route) => false,
      );
    };
    LoanRequestResponseNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      if (clubId != null && clubId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerLoanCatalogPage(
              clubId: clubId,
              initialTabIndex: 1,
            ),
          ),
        );
      }
    };
    LoanReturnNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      if (clubId != null && clubId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => AdminLoansPage(
              clubId: clubId,
              initialTabIndex: 1,
            ),
          ),
        );
      }
    };
    EventNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      final eventId = payload['eventId'];
      if (clubId != null &&
          clubId.isNotEmpty &&
          eventId != null &&
          eventId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerEventDetailsPage(
              clubId: clubId,
              eventId: eventId,
            ),
          ),
        );
      }
    };
    AnnouncementNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      if (clubId != null && clubId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => AdminClubCommunicationPage(clubId: clubId),
          ),
        );
      }
    };
    NotificationService.onTokenRefreshed = () {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        NotificationService.instance.updateTokenForUser(uid);
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Quand l'app revient au premier plan, vérifier la connexion
    if (state == AppLifecycleState.resumed) {
      _checkConnection();
    }
  }

  Future<void> _checkConnection() async {
    final hasConnection = await ConnectivityChecker.hasInternetConnection();
    if (mounted && _hasInternet != hasConnection) {
      setState(() {
        _hasInternet = hasConnection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si pas de connexion, afficher la page "pas de connexion"
    if (!_hasInternet) {
      return MaterialApp(
        title: 'ViroTeam',
        theme: ViroTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: NoInternetPage(
          onConnectionRestored: () {
            _checkConnection();
          },
        ),
      );
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
                  NotificationService.instance.updateTokenForUser(user.uid);
                  NotificationService.instance
                      .handlePendingNotificationIfNeeded();
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
                NotificationService.instance.updateTokenForUser(null);
              });
            }
            return const AuthPage(); // Sinon on affiche l'écran d'auth
          },
        ),
      ),
    );
  }
}
