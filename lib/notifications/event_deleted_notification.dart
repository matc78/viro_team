/// Notification "événement supprimé".
/// Payload : clubId, eventId.
class EventDeletedNotification {
  EventDeletedNotification._();

  static const String type = 'event_deleted';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'clubId': data['clubId']?.toString() ?? '',
      'eventId': data['eventId']?.toString() ?? '',
    };
  }
}
