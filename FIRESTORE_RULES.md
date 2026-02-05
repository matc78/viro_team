# Règles de sécurité Firestore – ViroTeam (Production)

Ce document décrit les règles Firestore pour l’application et la stratégie de sécurité en production.

## Principes

1. **Authentification obligatoire** : toutes les collections sensibles ne sont accessibles qu’aux utilisateurs connectés (`request.auth != null`).
2. **Propriété des données** :
   - **users** : chaque utilisateur ne peut **écrire** que son propre document ; la **lecture** est ouverte à tout connecté (nécessaire pour liste membres / demandes d’adhésion).
3. **Rôles côté club** : l’accès en **écriture** aux clubs et sous-collections est réservé aux **admins** (champs `adminId` ou `admins[]`) et aux **coaches** (tableau **`coaches`** sur le document club, déjà maintenu par l’app lors de l’acceptation d’une demande ou du retrait d’un membre).
4. **join_requests** : création par le demandeur uniquement (`userId == request.auth.uid`) ; lecture et mise à jour par le demandeur ou un admin du club concerné.

## Structure des données (référence)

| Chemin | Description |
|--------|-------------|
| `users/{userId}` | Profil, rôles (player, coach, admin, admin_fondateur), activeContext, hasPendingRequest, fcmToken. |
| `clubs/{clubId}` | Infos club : name, sport, adminId, admins[], coaches[], etc. |
| `clubs/{clubId}/members` | Membres du club. |
| `clubs/{clubId}/teams` | Équipes (playerIds, coachIds, etc.). |
| `clubs/{clubId}/events` | Événements. |
| `clubs/{clubId}/equipment`, `equipmentCatalog` | Matériel et catalogue. |
| `clubs/{clubId}/equipment_loans`, `equipment_loan_requests`, `equipment_loan_change_requests` | Prêts et demandes. |
| `clubs/{clubId}/member_leaves`, `member_removals` | Départs et retraits. |
| `clubs/{clubId}/announcements` | Annonces. |
| `join_requests/{requestId}` | Demandes d’adhésion (clubId, userId, status, roleRequested, message, createdAt, …). |

## Règles par ressource

### users

- **Lecture** : tout utilisateur connecté (nécessaire pour l’écran membres et les demandes d’adhésion).
- **Création** : uniquement pour son propre `userId`.
- **Mise à jour / suppression** : uniquement sur son propre document.

**Renforcement futur** : pour limiter la fuite de profils, on peut restreindre la lecture à son propre document et exposer la liste des membres d’un club via une **Cloud Function** (ex. `getMembersOfClub(clubId)`) qui vérifie les rôles côté serveur.

### clubs

- **Lecture** : tout utilisateur connecté (recherche de club, accès au club actif).
- **Création** : tout utilisateur connecté.
- **Mise à jour / suppression** : uniquement si l’utilisateur est admin du club (`adminId` ou présent dans `admins[]`).

### Sous-collections d’un club (members, teams, events, equipment, equipment_loans, …)

- **Lecture** : tout utilisateur connecté (l’app n’affiche que les clubs auxquels l’utilisateur appartient).
- **Écriture** : uniquement si l’utilisateur peut écrire dans le club, c’est-à-dire s’il est **admin** (`adminId` ou `admins[]`) ou **coach** (présent dans `club.coaches[]`).

### join_requests

- **Création** : utilisateur connecté, avec `request.resource.data.userId == request.auth.uid`.
- **Lecture / mise à jour / suppression** : le demandeur (`resource.data.userId == request.auth.uid`) ou un admin du club (`resource.data.clubId`).

## Champ `coaches` sur le document club

Les règles d’écriture sur les sous-collections du club utilisent **`canWriteClub(clubId)`**, qui autorise les **admins** (`adminId` ou `admins[]`) et les **coaches** (présent dans **`club.coaches[]`**).

L’app maintient déjà ce tableau : lors de l’acceptation d’une demande d’adhésion en tant que coach (`admin_home_page`, `profil_request_page`), un `FieldValue.arrayUnion([userId])` est appliqué au champ `coaches` du club ; lors du retrait d’un membre ou du départ d’un coach (`admin_members_page`, `player_profil_page`), un `FieldValue.arrayRemove([uid])` est appliqué. Aucune migration supplémentaire n’est nécessaire pour les coaches.

## Déploiement

```bash
firebase deploy --only firestore
```

## Index

Les index composites requis sont documentés dans **FIRESTORE_INDEXES.md**.

## Maintenabilité

- Utiliser les constantes de `lib/constants/firebase_collections.dart` pour tous les noms de collections.
- Privilégier les services (`UserService`, `TeamService`, `EventService`, etc.) plutôt que des accès Firestore directs dans les pages.
