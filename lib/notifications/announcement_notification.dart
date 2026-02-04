/// Notification "nouvelle annonce club".
/// Payload : clubId, announcementId, senderFirstName, senderLastName, message.
class AnnouncementNotification {
  AnnouncementNotification._();

  static const String type = 'announcement';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'clubId': data['clubId']?.toString() ?? '',
      'announcementId': data['announcementId']?.toString() ?? '',
      'senderFirstName': data['senderFirstName']?.toString() ?? '',
      'senderLastName': data['senderLastName']?.toString() ?? '',
      'message': data['message']?.toString() ?? '',
    };
  }
}
