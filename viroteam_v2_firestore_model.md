# ViRoTeam — Modèle de données Firestore (v2 simplifié)

> **Référence Cursor** — Ce fichier décrit l'architecture Firestore de l'app ViRoTeam.
> Il remplace tous les schémas legacy. Toujours s'y référer avant d'écrire ou de lire des données.

---

## Philosophie générale

- **Source de vérité du rôle** : `clubs/{clubId}/members/{uid}` — jamais `users/{uid}`
- **Pas de duplication** : les listes `admins[]`, `coaches[]`, `members[]` dans le doc club sont supprimées
- **Une page par club** : on charge `members/{uid}` une seule fois pour connaître le rôle, puis on affiche/masque les sections
- **Streams temps réel** : utiliser les streams Firestore pour les scores, présences, et brackets de tournoi

---

## Collections et schémas

---

### `users/{uid}`
> Profil global uniquement. Ne contient rien de spécifique à un club.

| Champ | Type | Description |
|---|---|---|
| `uid` | string | Identifiant Firebase Auth |
| `email` | string | Email brut |
| `emailNorm` | string | Email normalisé (lowercase) |
| `firstName` | string | |
| `lastName` | string | |
| `displayName` | string | |
| `phone` | string | |
| `avatarUrl` | string | URL Firebase Storage |
| `fcmToken` | string | Token push notifications |
| `clubMemberships` | array | `[{ clubId, role }]` — liste des clubs et rôle dans chacun |
| `notificationPreferences` | map | Préférences par type de notif |
| `flags` | map | `{ profileCompleted, disabled }` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |
| `lastConnectionAt` | timestamp | |

**⚠️ Champs supprimés (legacy) :**
- `roles` (map legacy multi-rôles)
- `profileSummaries` → remplacé par `clubMemberships`
- `trainingStats` → calculé depuis `events.attendance`
- `activeContext` → géré en mémoire côté app
- `hasPendingRequest`, `lastClubRequested` → géré dans `join_requests`

---

### `clubs/{clubId}`
> Informations générales du club.

| Champ | Type | Description |
|---|---|---|
| `name` | string | Nom du club |
| `city` | string | |
| `postalCode` | string | |
| `address` | string | |
| `sport` | string | |
| `contactEmail` | string | |
| `phone` | string | |
| `description` | string | |
| `logoUrl` | string? | Logo du club (Firebase Storage) |
| `brandColorHex` | string? | Couleur d'identité (ex. `#1E88E5`) |
| ~~`objectives`~~ | — | Déplacé vers `retour_user` (type `club_setup_objectives`) |
| `practiceLocations` | array | `[{ name, address? }]` — lieux de pratique |
| `adminIds` | array | Liste des uids ayant le rôle admin |
| `memberCount` | number | Compteur membres actifs |
| `seasonEndDate` | timestamp | Fin de saison |
| `paymentMethods` | map | Moyens de paiement configurés |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp? | |

**⚠️ Champs supprimés (legacy) :**
- `admins[]`, `coaches[]`, `members[]` → tout est dans la sous-collection `members/{uid}`

---

### `clubs/{clubId}/members/{uid}`
> **Source de vérité** : rôle et données d'un membre dans un club spécifique.

| Champ | Type | Description |
|---|---|---|
| `userId` | string | Référence à `users/{uid}` |
| `role` | string | `'admin'` \| `'coach'` \| `'player'` |
| `status` | string | `'active'` \| `'inactive'` |
| `teamIds` | array | Équipes du membre dans ce club |
| `snapshot` | map | `{ displayName, avatarUrl, email }` dénormalisé |
| `joinedAt` | timestamp | |
| `updatedAt` | timestamp | |

**Sous-objet conditionnel pour les joueurs :**
```
playerInfo: {
  license: string,
  categories: string[]
}
```

**Sous-objet conditionnel pour les coachs :**
```
coachInfo: {
  headCoach: bool
}
```

> Les admins n'ont pas de sous-objet — leur pouvoir vient uniquement du champ `role`.

---

### `clubs/{clubId}/teams/{teamId}`
> Équipes du club.

| Champ | Type | Description |
|---|---|---|
| `name` | string | Nom de l'équipe |
| `category` | string | Ex: U12, Seniors… |
| `playerIds` | array | UIDs des joueurs |
| `coachIds` | array | UIDs des coachs |
| `pendingPlayerIds` | array | Invités sans compte (`pending_members`) |
| `avatarUrl` | string | |
| `createdAt` | timestamp | |

---

### `clubs/{clubId}/events/{eventId}`
> Entraînements, matchs, tournois, autres.

| Champ | Type | Description |
|---|---|---|
| `type` | string | `'training'` \| `'match'` \| `'tournament'` \| `'other'` |
| `title` | string | |
| `location` | string | |
| `teamIds` | array | Équipes concernées |
| `allTeams` | bool | Si l'event concerne tout le club |
| `date` | timestamp | |
| `startTime` | string | Format HH:mm |
| `endTime` | string | Format HH:mm |
| `teamMemberIds` | array | Audience de l'événement |
| `rsvp` | map | `uid → 'yes' \| 'no' \| 'none'` |
| `attendance` | map | `uid → { status, lateMinutes, markedBy, markedAt }` |
| `creatorId` | string | |
| `createdAt` | timestamp | |

> **`attendance`** est le seul map de présence — `sessionAttendance` et la collection `training_attendances` sont supprimés.

---

### `clubs/{clubId}/tournaments/{tournamentId}`
> Tournoi ou championnat.

| Champ | Type | Description |
|---|---|---|
| `name` | string | |
| `type` | string | `'tournament'` \| `'championship'` |
| `status` | string | `'draft'` \| `'active'` \| `'finished'` |
| `linkedEventId` | string? | Événement club lié (optionnel) |
| `matchFormat` | map | `{ type: 'time'\|'points'\|'sets', value: number }` |
| `playersPerTeam` | number | Nb de joueurs par équipe |
| `structure` | map | Voir détail ci-dessous |
| `teamGeneration` | map | `{ method: 'window'\|'manual', driftFactor: number, swapHistory: [] }` |
| `createdBy` | string | UID admin |
| `createdAt` | timestamp | |

**Détail `structure` :**
```
structure: {
  phases: [
    { type: 'group', groups: [], nbQualifiedPerGroup: number },
    { type: 'group', groups: [], nbQualifiedPerGroup: number },  // phase inter (optionnel)
    { type: 'knockout', rounds: [] }
  ],
  loserBracket: {
    enabled: bool,
    type: 'knockout',
    rounds: []
  }
}
```

#### Sous-collection : `tournament_teams/{teamId}`

| Champ | Type | Description |
|---|---|---|
| `name` | string | Nom de l'équipe |
| `playerIds` | array | UIDs des membres du club |
| `colorHex` | string | Couleur d'affichage |

#### Sous-collection : `tournament_matches/{matchId}`

| Champ | Type | Description |
|---|---|---|
| `phaseId` | string | Phase à laquelle appartient ce match |
| `teamAId` | string | |
| `teamBId` | string | |
| `scoreA` | number | |
| `scoreB` | number | |
| `status` | string | `'scheduled'` \| `'inProgress'` \| `'finished'` |
| `scheduledAt` | timestamp | |

#### Sous-collection : `tournament_phases/{phaseId}`

| Champ | Type | Description |
|---|---|---|
| `type` | string | `'group'` \| `'knockout'` |
| `order` | number | Position dans le tableau phases[] |
| `groups` | array | Groupes / poules de cette phase |
| `nbQualifiedPerGroup` | number | |

---

### `clubs/{clubId}/pending_members/{docId}`
> Invités sans compte utilisateur.

| Champ | Type | Description |
|---|---|---|
| `email` | string | |
| `firstName` | string | |
| `lastName` | string | |
| `invitationStatus` | string | `'pending'` \| `'accepted'` \| `'declined'` |
| `teamIds` | array | Équipes dans lesquelles ils sont invités |
| `invitedBy` | string | UID admin |
| `invitedAt` | timestamp | |

---

### `clubs/{clubId}/announcements/{docId}`

| Champ | Type | Description |
|---|---|---|
| `senderId` | string | |
| `senderFirstName` | string | |
| `senderLastName` | string | |
| `message` | string | |
| `targetType` | string | `'all'` \| `'team'` |
| `targetIds` | array | |
| `durationDays` | number | |
| `createdAt` | timestamp | |

---

### `retour_user/{docId}` (collection racine)
> Retours et intentions utilisateur (hors doc club).

| Champ | Type | Description |
|---|---|---|
| `userId` | string | Auteur |
| `clubId` | string? | Club concerné (après création) |
| `type` | string | Ex. `club_setup_objectives` |
| `objectives` | array | Clés objectifs (`planning`, `attendance`, …) |
| `objectivesLabels` | array | Libellés FR dénormalisés |
| `clubName` | string? | |
| `clubSport` | string? | |
| `createdAt` | timestamp | |

> Les objectifs d'onboarding ne sont **pas** dupliqués sur `clubs/{clubId}` — ils vivent ici.

---

### `join_requests/{requestId}` (collection racine)
> Demandes d'adhésion à un club.

| Champ | Type | Description |
|---|---|---|
| `userId` | string | |
| `clubId` | string | |
| `clubName` | string | |
| `clubSport` | string | |
| `roleRequested` | string | `'player'` \| `'coach'` |
| `firstName` | string | |
| `lastName` | string | |
| `phone` | string | |
| `message` | string | |
| `status` | string | `'pending'` \| `'accepted'` \| `'refused'` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

---

### `clubs/{clubId}/invitations/{inviteId}`
> Codes d'invitation partageables (rejoindre un club en joueur ou coach).

| Champ | Type | Description |
|---|---|---|
| `code` | string | Code partageable (ex. `ASMP1K2E`, uppercase) |
| `role` | string | `'player'` \| `'coach'` — rôle accordé à l'acceptation |
| `email` | string? | Si défini, seul cet email peut accepter |
| `status` | string | `'pending'` \| `'accepted'` \| `'declined'` \| `'expired'` |
| `sentBy` | string | UID admin/coach créateur |
| `sentAt` | timestamp | |
| `expiresAt` | timestamp | |
| `acceptedAt` | timestamp? | |
| `acceptedBy` | string? | UID ayant accepté |

> Requête join : `collectionGroup('invitations').where('code', ==).where('status', == 'pending')` — index composite requis.

---

### `clubs/{clubId}/invite_links/{token}`
> Liens d'invitation (docId = token).

| Champ | Type | Description |
|---|---|---|
| `token` | string | |
| `pendingMemberId` | string | |
| `email` | string | |
| `firstName` | string | |
| `lastName` | string | |
| `teams` | array | `[{ teamId, teamName, category }]` |
| `expiresAt` | timestamp | |
| `usedAt` | timestamp? | |

---

## Collections supprimées (legacy)

| Collection | Raison |
|---|---|
| `users.roles` (map) | Remplacé par `users.clubMemberships` |
| `users.trainingStats` | Calculé depuis `events.attendance` |
| `users.activeContext` | Géré en mémoire côté app |
| `clubs.admins[]` / `coaches[]` / `members[]` | Tout dans `members/{uid}` |
| `training_attendances/{docId}` | Fusionné dans `events.attendance` |
| `fee_settings/default` | Remplacé par `fee_seasons` uniquement |
| `member_fees/{uid}` (racine club) | Remplacé par `fee_seasons/.../member_fees` |

---

## Logique d'affichage par rôle (une page par club)

Charger `clubs/{clubId}/members/{uid}` une seule fois à l'ouverture du club.
Afficher/masquer les sections selon `member.role` :

| Section | Player | Coach | Admin |
|---|:---:|:---:|:---:|
| Mes matchs / entraînements | ✅ | ✅ | ✅ |
| Voir les tournois | ✅ | ✅ | ✅ |
| Pointer les présences | ❌ | ✅ | ✅ |
| Gérer les équipes | ❌ | ✅ | ✅ |
| Gérer les tournois | ❌ | ❌ | ✅ |
| Gérer les membres | ❌ | ❌ | ✅ |
| Cotisations | ❌ | ❌ | ✅ |

> Le rôle **Parent** n'est pas encore implémenté. Prévoir le champ `role: 'parent'` dans `members/{uid}` pour une future itération.

---

## Cotisations (multi-saisons)

```
clubs/{clubId}/fee_seasons/{seasonId}
  ├── seasonLabel, isActive, tiers[], paymentInstructions
  ├── paymentDeadlineAt, currency
  └── member_fees/{uid}
        ├── status: 'non_configure' | 'exonere' | 'a_payer' | 'partiel' | 'paye' | 'en_retard'
        ├── tierId, amountPaidCents, customAmountCents
        └── notesAdmin
```

---

## Équipement (inchangé)

```
equipment/{id}              → stock : name, category, condition, quantity, prix, caution
equipmentCatalog/{id}       → catalogue prêtable : maxQuantity, price, maxLoanDurationDays
equipment_loans/{id}        → prêts actifs : status, dates
equipment_loan_requests/{id}→ demandes joueurs : status
equipment_loan_change_requests/{id} → modifications en cours
```

---

*Dernière mise à jour : mai 2026*
