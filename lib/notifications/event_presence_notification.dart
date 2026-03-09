/// Notification "mise à jour de présence" envoyée aux coachs.
/// Payload : clubId, eventId.
class EventPresenceNotification {
  EventPresenceNotification._();

  static const String type = 'event_presence';

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
