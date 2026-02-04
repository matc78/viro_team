/// Notification "réponse demande de prêt" (acceptée/refusée).
/// Payload : requestId, clubId, clubName, status (accepted|refused), equipmentName, adminResponse.
class LoanRequestResponseNotification {
  LoanRequestResponseNotification._();

  static const String type = 'loan_request_response';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'requestId': data['requestId']?.toString() ?? '',
      'clubId': data['clubId']?.toString() ?? '',
      'clubName': data['clubName']?.toString() ?? '',
      'status': data['status']?.toString() ?? '',
      'equipmentName': data['equipmentName']?.toString() ?? '',
      'adminResponse': data['adminResponse']?.toString() ?? '',
    };
  }
}
