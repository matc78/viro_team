// Utilitaire de migration optionnel : reconstruction des agrégats RSVP / présence
// à partir de l'historique Firestore. À lancer manuellement en debug si besoin.
//
// Les délais de réponse avant séance ne peuvent pas être reconstitués pour le passé
// sans [attendanceMeta] ou horodatages par réponse ; seuls les compteurs dérivables
// des documents [events] et [training_attendances] pourraient être estimés.

/// Placeholder : aucun backfill automatique pour l'instant.
Future<void> runPlayerStatsBackfillIfNeeded() async {}
