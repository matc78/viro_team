import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import 'firebase_options.dart';
import 'pages/admin_coach_pages/admin_club_communication_page.dart';
import 'pages/admin_coach_pages/admin_home_page.dart';
import 'pages/admin_coach_pages/admin_loans_page.dart';
import 'pages/admin_coach_pages/admin_event_details_page.dart';
import 'pages/auth_page.dart';
import 'pages/complete_profile_page.dart';
import 'package:viro_team/pages/player_confirm_club_invitation_page.dart';
import 'pages/invite_signup_page.dart';
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
import 'utils/auth_helper.dart';
import 'utils/connectivity_checker.dart';
import 'utils/migration_user_to_memberships.dart';
import 'widget/fatal_error_app.dart';
import 'widget/viro_loader.dart';

/// Handler pour les messages FCM reçus en arrière-plan (obligatoire sur Android).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // La notif est affichée par le système ; le tap est géré par getInitialMessage / onMessageOpenedApp
}

bool _migrationRan = false;

Future<void> _runMigrationOnce() async {
  if (_migrationRan) return;
  _migrationRan = true;
  try {
    await runMigrationUserToMemberships(
      dryRun: false,
      onProgress: (msg) => AppLogger.instance.info('Migration', {'step': msg}),
    );
  } catch (e, st) {
    AppLogger.instance.error('Migration échouée', error: e, stackTrace: st);
  }
}

void main() {
  // Wrapper avec runZonedGuarded pour capturer toutes les erreurs asynchrones
  runZonedGuarded(
    () async {
      // 1. Toujours ajouter cette ligne pour Firebase
      WidgetsFlutterBinding.ensureInitialized();

      // Orientation : portrait uniquement sur téléphone, libre sur tablette
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final view = views.first;
        final physicalSize = view.physicalSize;
        final dpr = view.devicePixelRatio;
        final shortestSide = (physicalSize.width < physicalSize.height
                ? physicalSize.width
                : physicalSize.height) /
            dpr;
        final isTablet = shortestSide >= 600;
        await SystemChrome.setPreferredOrientations(
          isTablet
              ? [
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]
              : [DeviceOrientation.portraitUp],
        );
      }

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

        // 4.5. Migration one-shot (base test uniquement) : roles → members + profileSummaries + avatar_moderation
        if (!kReleaseMode) {
          unawaited(_runMigrationOnce());
        }

        // 5. Initialiser FCM (notifications push)
        unawaited(NotificationService.instance.init());

        // 6. Lancer l'application principale (Provider au-dessus pour que toutes les routes aient accès à UserSession)
        runApp(
          ChangeNotifierProvider<UserSession>(
            create: (_) => UserSession(),
            child: const MyApp(),
          ),
        );
      } catch (error, stackTrace) {
        // En cas d'erreur lors de l'initialisation (ex: Firebase échoue)
        // Essayer d'enregistrer dans Crashlytics si disponible
        try {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            fatal: true,
          );
        } catch (e) {
          // Si Crashlytics n'est pas disponible, on continue quand même
          AppLogger.instance.error('Crashlytics unavailable', error: e);
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
      } catch (e) {
        // Si Crashlytics n'est pas disponible, on log quand même l'erreur
        AppLogger.instance.error('Crashlytics unavailable', error: e);
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
    EventUpdateNotification.onOpen = (payload) {
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
    EventPresenceNotification.onOpen = (payload) {
      final clubId = payload['clubId'];
      final eventId = payload['eventId'];
      if (clubId != null &&
          clubId.isNotEmpty &&
          eventId != null &&
          eventId.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => AdminEventDetailsPage(
              clubId: clubId,
              eventId: eventId,
            ),
          ),
        );
      }
    };
    EventDeletedNotification.onOpen = (payload) {
      // Événement supprimé, on pourrait juste aller sur le planning.
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const PlayerHomePage(),
        ),
        (route) => false,
      );
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
        child: _AuthGate(
          currentUserId: _currentUserId,
          onUserIdChanged: (uid) {
            if (mounted) setState(() => _currentUserId = uid);
          },
          onSessionStarted: (uid) {
            NotificationService.instance.updateTokenForUser(uid);
            NotificationService.instance.handlePendingNotificationIfNeeded();
          },
          onSessionStopped: () {
            NotificationService.instance.updateTokenForUser(null);
          },
        ),
      ),
    );
  }
}

/// Encapsule la logique d'auth et de routage : une seule écoute Firestore via [UserSession].
class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.currentUserId,
    required this.onUserIdChanged,
    required this.onSessionStarted,
    required this.onSessionStopped,
  });

  final String? currentUserId;
  final void Function(String?) onUserIdChanged;
  final void Function(String uid) onSessionStarted;
  final void Function() onSessionStopped;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Timer? _retryTimer;
  int _userDocRetryCount = 0;
  String? _inviteToken;
  String? _inviteClubId;
  bool _initialLinkChecked = false;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _parseInviteUri(uri);
      _appLinks.uriLinkStream.listen((Uri uri) {
        if (mounted) _parseInviteUri(uri);
      });
      if (mounted) setState(() => _initialLinkChecked = true);
    } catch (e) {
      AppLogger.instance.error('AppLinks init failed', error: e);
      if (mounted) setState(() => _initialLinkChecked = true);
    }
  }

  void _parseInviteUri(Uri uri) {
    if (uri.host == 'invite' || uri.pathSegments.contains('invite')) {
      final t = uri.queryParameters['t'];
      final c = uri.queryParameters['c'];
      if (t != null && t.isNotEmpty && c != null && c.isNotEmpty) {
        setState(() {
          _inviteToken = t;
          _inviteClubId = c;
        });
      }
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: ViroLoader(size: 50)),
          );
        }
        if (!snapshot.hasData) {
          if (widget.currentUserId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onUserIdChanged(null);
              context.read<UserSession>().stopListening();
              widget.onSessionStopped();
            });
          }
          if (_inviteToken != null && _inviteClubId != null) {
            return InviteSignUpPage(
              token: _inviteToken!,
              clubId: _inviteClubId!,
              onSignUpSuccess: () {
                setState(() {
                  _inviteToken = null;
                  _inviteClubId = null;
                });
              },
            );
          }
          return const AuthPage();
        }

        final user = snapshot.data!;
        if (user.uid != widget.currentUserId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onUserIdChanged(user.uid);
            context.read<UserSession>().startListening(user.uid);
            widget.onSessionStarted(user.uid);
          });
        }

        return Consumer<UserSession>(
          builder: (context, session, _) {
            if (session.isLoading && session.currentUser == null) {
              return const Scaffold(
                body: Center(child: ViroLoader(size: 50)),
              );
            }
            final currentUser = session.currentUser;
            if (currentUser != null) {
              _userDocRetryCount = 0;
            }
            if (currentUser == null) {
              if (_userDocRetryCount == 0) {
                if (_retryTimer == null) {
                  final uid = user.uid;
                  _retryTimer = Timer(const Duration(milliseconds: 1500), () {
                    if (!mounted) return;
                    _retryTimer?.cancel();
                    _retryTimer = null;
                    setState(() => _userDocRetryCount = 1);
                    context.read<UserSession>().loadUser(uid);
                  });
                }
                return const Scaffold(
                  body: Center(child: ViroLoader(size: 50)),
                );
              }
              Future.microtask(() async {
                try {
                  await signOutCompletely();
                } catch (e) {
                  AppLogger.instance.error('signOutCompletely failed', error: e);
                }
              });
              return const AuthPage();
            }

            // Utilisateur connecté qui ouvre un lien d'invitation : page de confirmation (Accepter / Refuser) puis appliquer ou refuser
            final inviteToken = _inviteToken;
            final inviteClubId = _inviteClubId;
            if (inviteToken != null && inviteClubId != null) {
              final email = currentUser.email ?? '';
              if (email.isNotEmpty) {
                final uid = user.uid;
                return PlayerConfirmClubInvitationPage(
                  token: inviteToken,
                  clubId: inviteClubId,
                  userId: uid,
                  userEmail: email,
                  onDone: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      await context.read<UserSession>().loadUser(uid);
                      if (!mounted) return;
                      setState(() {
                        _inviteToken = null;
                        _inviteClubId = null;
                      });
                    });
                  },
                );
              }
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _inviteToken = null;
                      _inviteClubId = null;
                    });
                  }
                });
                return const Scaffold(
                  body: Center(child: ViroLoader(size: 50)),
                );
              }
            }

            final activeContext = currentUser.activeContext;
            final activeRole = activeContext?.role;
            final activeClubId = activeContext?.clubId;

            // Contexte actif manquant, invalide ou obsolète : afficher loader.
            // La restauration est déclenchée par UserSession lors du premier snapshot serveur (pas cache).
            if (currentUser.hasAnyRole && !currentUser.isActiveContextCoherent) {
              return const Scaffold(
                body: Center(child: ViroLoader(size: 50)),
              );
            }

            // Utilisateur Google qui n'a pas complété son profil (nom, prénom, téléphone)
            if (currentUser.profileCompleted == false) {
              return const CompleteProfilePage();
            }

            if (!currentUser.hasAnyRole && activeContext == null) {
              if (!_initialLinkChecked) {
                return const Scaffold(
                  body: Center(child: ViroLoader(size: 50)),
                );
              }
              return const OnboardingPage();
            }
            if (activeContext != null &&
                activeRole != null &&
                activeClubId != null) {
              if (activeRole == 'admin' ||
                  activeRole == 'coach' ||
                  activeRole == 'admin_fondateur') {
                return const AdminHomePage();
              }
              if (activeRole == 'player') {
                return const PlayerHomePage();
              }
            }
            if (currentUser.hasPendingRequest) {
              return const PlayerHomePage();
            }
            if (!_initialLinkChecked) {
              return const Scaffold(
                body: Center(child: ViroLoader(size: 50)),
              );
            }
            return const OnboardingPage();
          },
        );
      },
    );
  }
}
