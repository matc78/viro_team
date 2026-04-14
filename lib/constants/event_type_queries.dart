/// Valeurs du champ Firestore `type` pour les requêtes agrégées (compteurs, etc.).
///
/// L’app utilise officiellement [kEventTypeTraining] ; des données plus anciennes
/// peuvent avoir une orthographe différente pour le même concept.
const String kEventTypeTraining = 'Entraînement';
const String kEventTypeMatch = 'Match';

/// Inclut les variantes rencontrées en base pour ne pas exclure des entraînements.
const List<String> kTrainingEventTypesForQuery = [
  kEventTypeTraining,
  'Entrainement', // variante sans accent (anciennes saisies)
];

/// Types match (extension possible si besoin).
const List<String> kMatchEventTypesForQuery = [
  kEventTypeMatch,
];
