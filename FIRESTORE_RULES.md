# Règles de sécurité Firestore – ViroTeam

Ce document décrit les règles Firestore recommandées pour l’application et la stratégie de sécurité.

## Principes

1. **Accès par authentification** : toutes les collections sensibles ne sont accessibles qu’aux utilisateurs connectés (`request.auth != null`).
2. **Données utilisateur** : chaque utilisateur ne peut lire/écrire que son propre document dans `users/{userId}`.
3. **Données club** : l’accès aux clubs et sous-collections est conditionné par le rôle (admin, coach, player) et l’appartenance au club.
4. **Centralisation** : les opérations Firestore côté app passent par les services (`lib/services/`) pour faciliter la maintenance et l’évolution des règles.

## Structure des données (référence)

- **`users`** : profil et rôles (player, coach, admin, activeContext, hasPendingRequest).
- **`clubs`** : infos club (name, sport, logo, etc.).
- **`clubs/{clubId}/members`** : membres du club.
- **`clubs/{clubId}/teams`** : équipes.
- **`clubs/{clubId}/events`** : événements.
- **`clubs/{clubId}/equipment`**, **equipmentCatalog**, **equipment_loans**, **equipment_loan_requests**, **equipment_loan_change_requests** : matériel et prêts.
- **`clubs/{clubId}/member_leaves`**, **member_removals** : départs et retraits.
- **`clubs/{clubId}/announcements`** : annonces.
- **`join_requests`** (racine) : demandes d’adhésion (clubId, userId, status).

## Fichier `firestore.rules`

Le fichier `firestore.rules` à la racine du projet peut être déployé avec :

```bash
firebase deploy --only firestore
```

Les règles ci-dessous sont un **modèle minimal** à adapter selon vos besoins (rôles stockés dans `users`, vérification d’appartenance au club via `members`, etc.). En production, il est recommandé de vérifier les rôles côté Firestore (champs dans `users` ou dans `clubs/{clubId}/members`).

## Index

Les index composites requis sont documentés dans `FIRESTORE_INDEXES.md`.

## Maintenabilité

- Utiliser les constantes de `lib/constants/firebase_collections.dart` pour tous les noms de collections.
- Éviter les accès Firestore directs dans les pages ; privilégier les services (`UserService`, `TeamService`, `EventService`, etc.).
