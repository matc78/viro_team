import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/app_logger.dart';

/// Types de notifications (clés utilisées dans Firestore et Cloud Functions).
const List<String> kNotificationTypes = [
  'join_request',
  'loan_request',
  'join_request_response',
  'loan_request_response',
  'member_leave',
  'loan_return',
  'announcement',
  'event',
  'event_update',
  'event_deleted',
  'event_presence',
];

/// Types reçus par un joueur (player).
const List<String> kNotificationTypesPlayer = [
  'join_request_response',
  'loan_request_response',
  'announcement',
  'event',
  'event_update',
  'event_deleted',
];

/// Types reçus par un admin ou coach.
const List<String> kNotificationTypesAdmin = [
  'join_request',
  'loan_request',
  'member_leave',
  'loan_return',
  'announcement',
  'event',
  'event_update',
  'event_deleted',
  'event_presence',
];

/// Libellés français pour l'UI.
const Map<String, String> kNotificationTypeLabels = {
  'join_request': "Demandes d'adhésion",
  'loan_request': 'Demandes de prêt',
  'join_request_response': "Réponse à ma demande d'adhésion",
  'loan_request_response': 'Réponse à ma demande de prêt',
  'member_leave': "Départ d'un membre",
  'loan_return': 'Retour de matériel',
  'announcement': 'Annonces du club',
  'event': 'Nouveaux événements et rappels',
  'event_update': 'Modifications d\'événements',
  'event_deleted': 'Annulations d\'événements',
  'event_presence': 'Récapitulatif des présences',
};

/// Service pour lire/écrire les préférences de notifications dans Firestore.
/// Champ : users/{uid}.notificationPreferences (map type -> bool).
/// Absence de clé ou true = activé ; false = désactivé.
class NotificationPreferencesService {
  NotificationPreferencesService._();

  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  final FirebaseFirestore _db = appFirestore;

  /// Récupère les préférences actuelles. Les types absents sont considérés activés (true).
  Future<Map<String, bool>> getPreferences(String uid) async {
    if (uid.isEmpty) return _defaultsAllEnabled();
    try {
      final doc = await _db
          .collection(FirebaseCollections.users)
          .doc(uid)
          .get();
      final data = doc.data();
      final prefs = data?['notificationPreferences'] as Map<String, dynamic>?;
      if (prefs == null) return _defaultsAllEnabled();
      final result = <String, bool>{};
      for (final type in kNotificationTypes) {
        final v = prefs[type];
        result[type] = v == false ? false : true;
      }
      return result;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lecture préférences notifications',
        error: e,
        context: {'uid': uid},
      );
      return _defaultsAllEnabled();
    }
  }

  /// Met à jour plusieurs préférences en une fois. Lit, fusionne, réécrit.
  Future<void> setPreferences(String uid, Map<String, bool> updates) async {
    if (uid.isEmpty || updates.isEmpty) return;
    try {
      final current = await getPreferences(uid);
      for (final e in updates.entries) {
        if (kNotificationTypes.contains(e.key)) {
          current[e.key] = e.value;
        }
      }
      final map = <String, dynamic>{};
      for (final e in current.entries) {
        map[e.key] = e.value;
      }
      await _db
          .collection(FirebaseCollections.users)
          .doc(uid)
          .set({'notificationPreferences': map}, SetOptions(merge: true));
    } catch (e) {
      AppLogger.instance.error(
        'Erreur écriture préférences notifications',
        error: e,
        context: {'uid': uid},
      );
      rethrow;
    }
  }

  /// Met à jour une préférence pour un type. Lit les préférences actuelles, met à jour la map, réécrit (merge document).
  Future<void> setPreference(String uid, String type, bool enabled) async {
    if (uid.isEmpty) return;
    if (!kNotificationTypes.contains(type)) return;
    try {
      final current = await getPreferences(uid);
      current[type] = enabled;
      final map = <String, dynamic>{};
      for (final e in current.entries) {
        map[e.key] = e.value;
      }
      await _db
          .collection(FirebaseCollections.users)
          .doc(uid)
          .set({'notificationPreferences': map}, SetOptions(merge: true));
    } catch (e) {
      AppLogger.instance.error(
        'Erreur écriture préférence notification',
        error: e,
        context: {'uid': uid, 'type': type, 'enabled': enabled},
      );
      rethrow;
    }
  }

  Map<String, bool> _defaultsAllEnabled() {
    return Map.fromEntries(
      kNotificationTypes.map((t) => MapEntry(t, true)),
    );
  }
}
