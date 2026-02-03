import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Gère FCM : permissions, token, sauvegarde dans users/{uid}, tap sur notif.
final class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Callback appelé quand l'utilisateur ouvre une notif "demande d'adhésion".
  /// Payload : requestId, userId, clubId, clubName, roleRequested, firstName, lastName.
  static void Function(Map<String, String> payload)? onOpenJoinRequest;

  /// Callback appelé quand le token FCM est rafraîchi (pour ré-enregistrer dans Firestore).
  static void Function()? onTokenRefreshed;

  RemoteMessage? _pendingInitialMessage;
  bool _initialized = false;

  /// À appeler une fois au démarrage (après Firebase.initializeApp).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Demander les permissions (iOS)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.instance.info('FCM: permissions refusées');
      return;
    }

    // Message ouvert depuis une notif (app en arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Notif reçue au premier plan (optionnel : afficher in-app)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      AppLogger.instance.info('FCM: token rafraîchi');
      onTokenRefreshed?.call();
    });
  }

  /// Enregistre le token FCM pour l'utilisateur connecté [uid].
  /// Appeler après connexion et quand [uid] change. Passer [null] à la déconnexion.
  Future<void> updateTokenForUser(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
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
    if (data['type'] == 'join_request' && onOpenJoinRequest != null) {
      final payload = <String, String>{
        'requestId': data['requestId'] ?? '',
        'userId': data['userId'] ?? '',
        'clubId': data['clubId'] ?? '',
        'clubName': data['clubName'] ?? '',
        'roleRequested': data['roleRequested'] ?? '',
        'firstName': data['firstName'] ?? '',
        'lastName': data['lastName'] ?? '',
      };
      onOpenJoinRequest!(payload);
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
