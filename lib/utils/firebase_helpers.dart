import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Récupère plusieurs documents utilisateur en batch pour éviter les N+1 queries.
/// Firestore limite whereIn à 10 éléments, donc on fait plusieurs appels si nécessaire.
Future<List<DocumentSnapshot>> fetchUsersBatch(List<String> userIds) async {
  if (userIds.isEmpty) return [];

  final batches = <Future<QuerySnapshot>>[];
  for (var i = 0; i < userIds.length; i += 10) {
    final batch = userIds.sublist(i, math.min(i + 10, userIds.length));
    batches.add(
      FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get(),
    );
  }

  final results = await Future.wait(batches);
  final allDocs = results.expand((snap) => snap.docs).toList();

  // Créer une map pour préserver l'ordre original
  final Map<String, DocumentSnapshot> docsMap = {
    for (var doc in allDocs) doc.id: doc,
  };

  // Retourner dans l'ordre de userIds
  return userIds
      .map((id) => docsMap[id])
      .whereType<DocumentSnapshot>()
      .toList();
}
