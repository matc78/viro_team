/// Notification "demande de prêt" (ouverture depuis une notif push).
/// Payload : requestId, clubId, clubName, playerId, playerName, equipmentName.
class LoanRequestNotification {
  LoanRequestNotification._();

  static const String type = 'loan_request';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'requestId': data['requestId']?.toString() ?? '',
      'clubId': data['clubId']?.toString() ?? '',
      'clubName': data['clubName']?.toString() ?? '',
      'playerId': data['playerId']?.toString() ?? '',
      'playerName': data['playerName']?.toString() ?? '',
      'equipmentName': data['equipmentName']?.toString() ?? '',
    };
  }
}
