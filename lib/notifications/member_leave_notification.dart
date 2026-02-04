/// Notification "départ du club" (ouverture depuis une notif push).
/// Payload : clubId, leaveId, userId, firstName, lastName, role.
class MemberLeaveNotification {
  MemberLeaveNotification._();

  static const String type = 'member_leave';

  /// Callback appelé quand l'utilisateur ouvre cette notif.
  static void Function(Map<String, String> payload)? onOpen;

  /// Construit le payload à partir des [data] FCM.
  static Map<String, String> payloadFromData(Map<String, dynamic> data) {
    return <String, String>{
      'clubId': data['clubId']?.toString() ?? '',
      'leaveId': data['leaveId']?.toString() ?? '',
      'userId': data['userId']?.toString() ?? '',
      'firstName': data['firstName']?.toString() ?? '',
      'lastName': data['lastName']?.toString() ?? '',
      'role': data['role']?.toString() ?? '',
    };
  }
}
