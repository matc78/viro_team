import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/notifications/notifications.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Gère FCM : permissions, token, sauvegarde dans users/{uid}, dispatch du tap sur notif.
/// Chaque type de notif est défini dans [lib/notifications/] (un fichier par notif).
/// Les listeners FCM sont actifs pour toute la durée de l'app ; [dispose] les annule (utile en tests).
final class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Callback appelé quand le token FCM est rafraîchi (pour ré-enregistrer dans Firestore).
  static void Function()? onTokenRefreshed;

  RemoteMessage? _pendingInitialMessage;
  bool _initialized = false;

  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<String?>? _onTokenRefreshSubscription;

  /// À appeler une fois au démarrage (après Firebase.initializeApp).
  /// Ne demande pas les permissions ici : utiliser [requestPermissionIfNeeded] depuis une home page.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Message ouvert depuis une notif (app en arrière-plan)
    _onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Notif reçue au premier plan (optionnel : afficher in-app)
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.instance.info(
        'FCM: message reçu au premier plan',
        message.data,
      );
    });

    // Notif qui a ouvert l'app (app fermée)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _pendingInitialMessage = initial;
    }

    // Rafraîchissement du token
    _onTokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      AppLogger.instance.info('FCM: token rafraîchi');
      onTokenRefreshed?.call();
    });
  }

  /// Annule les abonnements FCM. Utile en tests ou si le service a un cycle de vie explicite.
  void dispose() {
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onTokenRefreshSubscription?.cancel();
    _onTokenRefreshSubscription = null;
    _pendingInitialMessage = null;
    _initialized = false;
  }

  /// À appeler lorsque l'utilisateur arrive sur une home page (après choix onboarding).
  /// Affiche la demande de permission (iOS / Android 13+), puis enregistre le token si [uid] est fourni.
  Future<void> requestPermissionIfNeeded(String? uid) async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.instance.info('FCM: permissions refusées');
      return;
    }
    if (uid != null && uid.isNotEmpty) {
      await updateTokenForUser(uid);
    }
  }

  /// Enregistre le token FCM pour l'utilisateur connecté [uid].
  /// Appeler après connexion et quand [uid] change. Passer [null] à la déconnexion.
  Future<void> updateTokenForUser(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await appFirestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      AppLogger.instance.info('FCM: token enregistré pour $uid');
    } catch (e) {
      AppLogger.instance.error(
        'FCM: erreur enregistrement token',
        error: e,
        context: {'uid': uid},
      );
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case AnnouncementNotification.type:
        if (AnnouncementNotification.onOpen != null) {
          AnnouncementNotification.onOpen!(
            AnnouncementNotification.payloadFromData(data),
          );
        }
        break;
      case JoinRequestNotification.type:
        if (JoinRequestNotification.onOpen != null) {
          JoinRequestNotification.onOpen!(
            JoinRequestNotification.payloadFromData(data),
          );
        }
        break;
      case LoanRequestNotification.type:
        if (LoanRequestNotification.onOpen != null) {
          LoanRequestNotification.onOpen!(
            LoanRequestNotification.payloadFromData(data),
          );
        }
        break;
      case JoinRequestResponseNotification.type:
        if (JoinRequestResponseNotification.onOpen != null) {
          JoinRequestResponseNotification.onOpen!(
            JoinRequestResponseNotification.payloadFromData(data),
          );
        }
        break;
      case LoanRequestResponseNotification.type:
        if (LoanRequestResponseNotification.onOpen != null) {
          LoanRequestResponseNotification.onOpen!(
            LoanRequestResponseNotification.payloadFromData(data),
          );
        }
        break;
      case MemberLeaveNotification.type:
        if (MemberLeaveNotification.onOpen != null) {
          MemberLeaveNotification.onOpen!(
            MemberLeaveNotification.payloadFromData(data),
          );
        }
        break;
      case EventNotification.type:
        if (EventNotification.onOpen != null) {
          EventNotification.onOpen!(
            EventNotification.payloadFromData(data),
          );
        }
        break;
      case LoanReturnNotification.type:
        if (LoanReturnNotification.onOpen != null) {
          LoanReturnNotification.onOpen!(
            LoanReturnNotification.payloadFromData(data),
          );
        }
        break;
      default:
        if (type != null && type.isNotEmpty) {
          AppLogger.instance.info('FCM: type de notif inconnu', {'type': type});
        }
    }
  }

  /// À appeler quand le navigator est prêt (ex: addPostFrameCallback après login).
  /// Traite la notif qui a ouvert l'app si elle était en attente.
  void handlePendingNotificationIfNeeded() {
    if (_pendingInitialMessage == null) return;
    _handleMessage(_pendingInitialMessage!);
    _pendingInitialMessage = null;
  }
}
