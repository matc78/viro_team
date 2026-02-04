/// Notification "retour de matériel" (prêt marqué retourné).
/// Payload : clubId, loanId, borrowerName, equipmentName, returnedAt.
class LoanReturnNotification {
  LoanReturnNotification._();

  static const String type = 'loan_return';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'clubId': data['clubId']?.toString() ?? '',
      'loanId': data['loanId']?.toString() ?? '',
      'borrowerName': data['borrowerName']?.toString() ?? '',
      'equipmentName': data['equipmentName']?.toString() ?? '',
      'returnedAt': data['returnedAt']?.toString() ?? '',
    };
  }
}
