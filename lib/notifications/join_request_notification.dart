/// Notification "demande d'adhésion" (ouverture depuis une notif push).
/// Payload : requestId, userId, clubId, clubName, roleRequested, firstName, lastName.
class JoinRequestNotification {
  JoinRequestNotification._();

  static const String type = 'join_request';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'requestId': data['requestId']?.toString() ?? '',
      'userId': data['userId']?.toString() ?? '',
      'clubId': data['clubId']?.toString() ?? '',
      'clubName': data['clubName']?.toString() ?? '',
      'roleRequested': data['roleRequested']?.toString() ?? '',
      'firstName': data['firstName']?.toString() ?? '',
      'lastName': data['lastName']?.toString() ?? '',
    };
  }
}
