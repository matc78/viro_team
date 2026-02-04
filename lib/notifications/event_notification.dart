/// Notification "nouvel événement" ou "rappel événement".
/// Payload : clubId, eventId, title, eventType, dateId, startTime, location, clubName, isReminder.
class EventNotification {
  EventNotification._();

  static const String type = 'event';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'clubId': data['clubId']?.toString() ?? '',
      'eventId': data['eventId']?.toString() ?? '',
      'title': data['title']?.toString() ?? '',
      'eventType': data['eventType']?.toString() ?? '',
      'dateId': data['dateId']?.toString() ?? '',
      'startTime': data['startTime']?.toString() ?? '',
      'location': data['location']?.toString() ?? '',
      'clubName': data['clubName']?.toString() ?? '',
      'isReminder': data['isReminder']?.toString() ?? '',
    };
  }
}
