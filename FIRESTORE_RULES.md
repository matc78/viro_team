# Règles de sécurité Firestore – ViroTeam (Production)

Ce document décrit les règles Firestore pour l’application et la stratégie de sécurité en production.

## Principes

1. **Authentification obligatoire** : toutes les collections sensibles ne sont accessibles qu’aux utilisateurs connectés (`request.auth != null`).
2. **Propriété des données** :
   - **users** : chaque utilisateur peut écrire son propre document ; un **admin** d’un club peut aussi mettre à jour le document d’un autre utilisateur lorsque le payload contient `_adminClubId` (voir section users ci‑dessous) ; la **lecture** est ouverte à tout connecté (nécessaire pour liste membres / demandes d’adhésion).
3. **Rôles côté club** : l’accès en **écriture** aux clubs et sous-collections est réservé aux **admins** (champs `adminId` ou `admins[]`) et aux **coaches** (tableau **`coaches`** sur le document club, déjà maintenu par l’app lors de l’acceptation d’une demande ou du retrait d’un membre).
4. **join_requests** : création par le demandeur uniquement (`userId == request.auth.uid`) ; lecture et mise à jour par le demandeur ou un admin du club concerné.

## Structure des données (référence)

| Chemin | Description |
|--------|-------------|
| `users/{userId}` | Profil, rôles (player, coach, admin, admin_fondateur), activeContext, hasPendingRequest, fcmToken. Optionnel : `_adminClubId`, `lastProcessedJoinRequestClubId` (utilisés par les règles). |
| `clubs/{clubId}` | Infos club : name, sport, adminId, admins[], coaches[], etc. |
| `clubs/{clubId}/members` | Membres du club. |
| `clubs/{clubId}/teams` | Équipes (playerIds, coachIds, etc.). |
| `clubs/{clubId}/events` | Événements. |
| `clubs/{clubId}/equipment`, `equipmentCatalog` | Matériel et catalogue. |
| `clubs/{clubId}/equipment_loans`, `equipment_loan_requests`, `equipment_loan_change_requests` | Prêts et demandes. |
| `clubs/{clubId}/member_leaves`, `member_removals` | Départs et retraits. |
| `clubs/{clubId}/pending_members` | Membres en attente de création de compte (email, firstName, lastName, addedAt, addedBy). |
| `clubs/{clubId}/announcements` | Annonces. |
| `join_requests/{requestId}` | Demandes d’adhésion (clubId, userId, status, roleRequested, message, createdAt, …). |

## Règles par ressource

### users

- **Lecture** : tout utilisateur connecté (nécessaire pour l’écran membres et les demandes d’adhésion).
- **Création** : uniquement pour son propre `userId`.
- **Mise à jour / suppression** : propriétaire du document **ou** admin du club dans les cas suivants :
  - **Acceptation** de demande d’adhésion : le document mis à jour contient `activeContext.clubId` ; l’appelant doit être admin de ce club.
  - **Refus** de demande d’adhésion : le document peut contenir `lastProcessedJoinRequestClubId` ; l’appelant doit être admin de ce club (ce champ est envoyé par l’app lors du refus pour que la règle puisse vérifier).
  - **Gestion membre par un admin** (transfert de propriété du club, retrait d’équipe/club, changement de rôle) : le document mis à jour contient `_adminClubId` égal au `clubId` du club ; l’appelant doit être admin de ce club. L’app envoie ce champ pour toutes les écritures « admin → document d’un autre user » (transfert, équipes, membres). Le champ peut être conservé dans le document (audit).

**Renforcement futur** : pour limiter la fuite de profils, on peut restreindre la lecture à son propre document et exposer la liste des membres d’un club via une **Cloud Function** (ex. `getMembersOfClub(clubId)`) qui vérifie les rôles côté serveur.

### clubs

- **Lecture** : tout utilisateur connecté (recherche de club, accès au club actif).
- **Création** : tout utilisateur connecté.
- **Mise à jour** : si l’utilisateur est admin du club **ou** s’il ne fait que se retirer lui-même des champs `members`/`coaches` (cas de la suppression de compte depuis `player_profil_page`). La règle `isSelfRemovalFromClub` garantit qu’aucune autre modification n’est autorisée.
- **Suppression** : uniquement si l’utilisateur est admin du club (`adminId` ou présent dans `admins[]`).

### Sous-collections d’un club (members, teams, events, equipment, equipment_loans, pending_members, …)

- **Lecture** : tout utilisateur connecté (l’app n’affiche que les clubs auxquels l’utilisateur appartient).
- **Écriture** : uniquement si l’utilisateur peut écrire dans le club, c’est-à-dire s’il est **admin** (`adminId` ou `admins[]`) ou **coach** (présent dans `club.coaches[]`).

La sous-collection **`pending_members`** stocke les membres ajoutés par un admin (email, prénom, nom) en attente de création de compte ; lecture et écriture suivent les mêmes règles que les autres sous-collections du club (`canWriteClub(clubId)`).

### join_requests

- **Création** : utilisateur connecté, avec `request.resource.data.userId == request.auth.uid`.
- **Lecture / mise à jour / suppression** : le demandeur (`resource.data.userId == request.auth.uid`) ou un admin du club (`resource.data.clubId`).

## Champ `coaches` sur le document club

Les règles d’écriture sur les sous-collections du club utilisent **`canWriteClub(clubId)`**, qui autorise les **admins** (`adminId` ou `admins[]`) et les **coaches** (présent dans **`club.coaches[]`**).

L’app maintient déjà ce tableau : lors de l’acceptation d’une demande d’adhésion en tant que coach (`admin_home_page`, `profil_request_page`), un `FieldValue.arrayUnion([userId])` est appliqué au champ `coaches` du club ; lors du retrait d’un membre ou du départ d’un coach (`admin_members_page`, `player_profil_page`), un `FieldValue.arrayRemove([uid])` est appliqué. Aucune migration supplémentaire n’est nécessaire pour les coaches.

## Suppression de compte

- **Depuis la page joueur** (`player_profil_page`) : l’app met à jour le document club pour retirer l’utilisateur de `members` ou `coaches` via `arrayRemove`. Les règles autorisent cette mise à jour grâce à `isSelfRemovalFromClub` (un utilisateur peut se retirer lui-même, sans pouvoir modifier d’autres champs).
- **Depuis la page admin/coach** (`admin_profil_page._deleteAccount`) : l’app met à jour les équipes de tous les clubs pour retirer son `uid` des champs `playerIds`/`coachIds`. L’écriture sur `clubs/{clubId}/teams/{teamId}` est autorisée uniquement si l’utilisateur est **admin ou coach** du club (`canWriteClub(clubId)`). Si l’utilisateur a déjà **transféré** le club à quelqu’un d’autre, il n’est plus admin ni coach ; les mises à jour sur les équipes de ce club peuvent alors être refusées. En pratique : ne pas transférer le club avant de supprimer son compte, ou effectuer le nettoyage des équipes avant le transfert. Une alternative est de déléguer ce nettoyage à une Cloud Function déclenchée par la suppression du compte.

## Déploiement

Le projet est configuré pour trois bases Firestore : **(default)** (base principale), **test** et **prod** (même fichier `firestore.rules` pour toutes). Les bases **test** et **prod** doivent exister dans la console Firebase (Firestore > Ajouter une base) avant le premier déploiement.

- **Toutes les bases** ((default) + test + prod) :
  ```bash
  firebase deploy --only firestore
  ```
- **Base principale (default) uniquement** (sous PowerShell, mettre la cible entre guillemets) :
  ```bash
  firebase deploy --only "firestore:(default)"
  ```
- **Base test uniquement** :
  ```bash
  firebase deploy --only firestore:test
  ```
- **Base prod uniquement** :
  ```bash
  firebase deploy --only firestore:prod
  ```

## Index

Les index composites requis sont documentés dans **FIRESTORE_INDEXES.md**.

## Maintenabilité

- Utiliser les constantes de `lib/constants/firebase_collections.dart` pour tous les noms de collections.
- Privilégier les services (`UserService`, `TeamService`, `EventService`, etc.) plutôt que des accès Firestore directs dans les pages.
