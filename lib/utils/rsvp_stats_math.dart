import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/player_stats_policy.dart';

/// Référence temporelle pour le délai de réponse : [createdAt] si présent, sinon [date].
DateTime rsvpReferenceTime(Map<String, dynamic> event) {
  final c = event['createdAt'];
  if (c is Timestamp) return c.toDate();
  final d = event['date'];
  if (d is Timestamp) return d.toDate();
  return DateTime.now();
}

int delaySecondsSinceReference(DateTime ref, DateTime now) {
  final s = now.difference(ref).inSeconds;
  if (s < 0) return 0;
  if (s > 86400 * 365 * 2) return 86400 * 365 * 2;
  return s;
}

/// Préfixe du champ d'agrégat sur le user selon le type d'événement.
String? rsvpStatsFieldForEventType(String? type) {
  switch (type) {
    case 'Entraînement':
      return kRsvpTrainingStatsField;
    case 'Match':
      return kRsvpMatchStatsField;
    default:
      return null;
  }
}
