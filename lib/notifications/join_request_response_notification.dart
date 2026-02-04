/// Notification "réponse demande d'adhésion" (acceptée/refusée).
/// Payload : requestId, clubId, clubName, status (accepted|refused), roleRequested.
class JoinRequestResponseNotification {
  JoinRequestResponseNotification._();

  static const String type = 'join_request_response';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'requestId': data['requestId']?.toString() ?? '',
      'clubId': data['clubId']?.toString() ?? '',
      'clubName': data['clubName']?.toString() ?? '',
      'status': data['status']?.toString() ?? '',
      'roleRequested': data['roleRequested']?.toString() ?? '',
    };
  }
}
