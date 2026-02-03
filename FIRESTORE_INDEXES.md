# Index Firestore Requis

Ce document liste les index Firestore composites nécessaires pour optimiser les requêtes côté serveur.

## Index pour les Événements

### 1. Filtrage par date et équipe

**Collection:** `clubs/{clubId}/events`
**Champs indexés:**

- `date` (Ascending)
- `teamId` (Ascending)

**Requête exemple:**

```dart
FirebaseFirestore.instance
    .collection('clubs')
    .doc(clubId)
    .collection('events')
    .where('date', isGreaterThanOrEqualTo: startDate)
    .where('date', isLessThanOrEqualTo: endDate)
    .where('teamId', isEqualTo: teamId)
    .snapshots();
```

### 2. Filtrage par date et membres

**Collection:** `clubs/{clubId}/events`
**Champs indexés:**

- `date` (Ascending)
- `teamMemberIds` (Array)

**Requête exemple:**

```dart
FirebaseFirestore.instance
    .collection('clubs')
    .doc(clubId)
    .collection('events')
    .where('date', isGreaterThanOrEqualTo: startDate)
    .where('teamMemberIds', arrayContains: userId)
    .snapshots();
```

## Index pour les demandes de prêt (joueur)

### 3. Filtrage par joueur et tri par date

**Collection:** `clubs/{clubId}/equipment_loan_requests`
**Champs indexés:**

- `playerId` (Ascending)
- `createdAt` (Descending)

**Usage:** Requête dans l’onglet « Mes demandes » du catalogue de prêt joueur (`where('playerId', isEqualTo: currentUserId)`). Si un `orderBy('createdAt', descending: true)` est ajouté côté requête, cet index sera requis. Le tri est actuellement fait côté client.

**Requête exemple:**

```dart
FirebaseFirestore.instance
    .collection('clubs')
    .doc(clubId)
    .collection('equipment_loan_requests')
    .where('playerId', isEqualTo: currentUserId)
    .snapshots();
```

## Comment créer les index

1. Aller dans la console Firebase
2. Sélectionner Firestore Database
3. Aller dans l'onglet "Indexes"
4. Cliquer sur "Create Index"
5. Sélectionner la collection
6. Ajouter les champs dans l'ordre spécifié
7. Créer l'index

## Note importante

Les index composites sont nécessaires quand vous utilisez plusieurs `where()` ou une combinaison de `where()` et `orderBy()` sur des champs différents.

Pour les requêtes avec `arrayContains`, un seul index simple est nécessaire.
