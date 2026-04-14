// Politique d'affichage des statistiques joueur (référence produit, non utilisée par le moteur Firestore).
//
// Période par défaut : saison sportive (juillet → juin), clé technique "{clubId}_{YYYY-YYYY}".
//
// Présence réelle à l'entraînement : le taux affiché utilise (présent + retard) / total des
// pointages de séance, sauf mention contraire dans l'UI (libellés séparés pour retard).
//
// Réponses avant séance : un « événement répondu » est une convocation où le joueur a au moins
// une fois indiqué présent ou absent. Le délai moyen concerne uniquement les réponses « présent »,
// mesuré depuis la création de l'événement (createdAt) ou à défaut depuis la date/heure de l'événement.
//
// Matchs : mêmes indicateurs de réponse (présent/absent annoncé) sur les événements type Match.
//
// Visibilité : le joueur voit ses propres agrégats ; coach/admin voient les mêmes chiffres sur
// la fiche membre, avec possibilité de comparer à une moyenne d'équipe lorsque l'UI l'affiche.

/// Préfixe des champs d'agrégat RSVP entraînement sur `users/{uid}`.
const String kRsvpTrainingStatsField = 'rsvpTrainingStats';

/// Préfixe des champs d'agrégat RSVP match sur `users/{uid}`.
const String kRsvpMatchStatsField = 'rsvpMatchStats';
