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

  /// Callback appelé quand l'utilisateur ouvre une notif "demande de prêt".
  /// Payload : requestId, clubId, clubName, playerId, playerName, equipmentName.
  static void Function(Map<String, String> payload)? onOpenLoanRequest;

  /// Callback appelé quand l'utilisateur ouvre une notif "réponse demande d'adhésion" (acceptée/refusée).
  /// Payload : requestId, clubId, clubName, status (accepted|refused), roleRequested.
  static void Function(Map<String, String> payload)? onOpenJoinRequestResponse;

  /// Callback appelé quand l'utilisateur ouvre une notif "réponse demande de prêt" (acceptée/refusée).
  /// Payload : requestId, clubId, clubName, status (accepted|refused), equipmentName, adminResponse.
  static void Function(Map<String, String> payload)? onOpenLoanRequestResponse;

  /// Callback appelé quand le token FCM est rafraîchi (pour ré-enregistrer dans Firestore).
  static void Function()? onTokenRefreshed;

  RemoteMessage? _pendingInitialMessage;
  bool _initialized = false;

  /// À appeler une fois au démarrage (après Firebase.initializeApp).
  /// Ne demande pas les permissions ici : utiliser [requestPermissionIfNeeded] depuis une home page.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

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
    } else if (data['type'] == 'loan_request' && onOpenLoanRequest != null) {
      final payload = <String, String>{
        'requestId': data['requestId'] ?? '',
        'clubId': data['clubId'] ?? '',
        'clubName': data['clubName'] ?? '',
        'playerId': data['playerId'] ?? '',
        'playerName': data['playerName'] ?? '',
        'equipmentName': data['equipmentName'] ?? '',
      };
      onOpenLoanRequest!(payload);
    } else if (data['type'] == 'join_request_response' &&
        onOpenJoinRequestResponse != null) {
      final payload = <String, String>{
        'requestId': data['requestId'] ?? '',
        'clubId': data['clubId'] ?? '',
        'clubName': data['clubName'] ?? '',
        'status': data['status'] ?? '',
        'roleRequested': data['roleRequested'] ?? '',
      };
      onOpenJoinRequestResponse!(payload);
    } else if (data['type'] == 'loan_request_response' &&
        onOpenLoanRequestResponse != null) {
      final payload = <String, String>{
        'requestId': data['requestId'] ?? '',
        'clubId': data['clubId'] ?? '',
        'clubName': data['clubName'] ?? '',
        'status': data['status'] ?? '',
        'equipmentName': data['equipmentName'] ?? '',
        'adminResponse': data['adminResponse'] ?? '',
      };
      onOpenLoanRequestResponse!(payload);
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
