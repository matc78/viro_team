# ViroTeam v2 — Spécification Cotisations (Fees)

> **Référence Cursor** — Ce fichier est la spec complète de la feature cotisations.
> Il s'appuie sur le modèle Firestore v2 existant (`viroteam_firestore_model.md`).
> Toujours s'y référer avant de coder quoi que ce soit lié aux cotisations.

---

## 1. Vue d'ensemble

### Objectif
Permettre aux admins de configurer une grille tarifaire par saison, d'assigner des catégories aux membres, et de suivre les paiements. Les joueurs voient leur statut et les consignes de paiement.

### Principes
- **Pas de paiement en ligne** — l'admin confirme manuellement les paiements (virement, chèque, espèces)
- **Pas de bouton "J'ai payé"** côté joueur — seul l'admin change le statut
- **1 saison active à la fois** — pas de multi-saisons au MVP
- **Cohérent avec l'architecture v2** — Riverpod, GoRouter, même structure features/

### Surfaces UI
| Surface | Qui | Quoi |
|---|---|---|
| Bannière rappel (home club) | Joueur avec `status: a_payer` | Montant + deadline + lien |
| Page "Ma cotisation" | Joueur (lecture seule) | Détail complet |
| Page "Cotisations" admin | Admin (2 sections) | Config saison + suivi membres |

---

## 2. Modèle Firestore

### 2.1. `clubs/{clubId}/fee_seasons/{seasonId}`

> Au MVP, un seul document avec `isActive: true`. Le `seasonId` est un ID auto-généré (pas "current" en dur — ça bloque le multi-saisons futur).

| Champ | Type | Obligatoire | Description |
|---|---|---|---|
| `seasonLabel` | `string` | ✅ | Ex: "2025-2026" |
| `isActive` | `bool` | ✅ | Une seule saison active par club |
| `currency` | `string` | ✅ | "EUR" par défaut |
| `paymentDeadlineAt` | `Timestamp?` | ❌ | Date limite (optionnelle) |
| `paymentInstructions` | `string` | ❌ | Texte libre (consignes de paiement) |
| `paymentMethods` | `List<string>` | ❌ | `['virement', 'cheque', 'especes']` — hérité de `clubs.paymentMethods` si existant |
| `iban` | `string?` | ❌ | IBAN du club (bouton copier côté joueur) |
| `tiers` | `List<Map>` | ✅ | Grille tarifaire (voir ci-dessous) |
| `createdAt` | `Timestamp` | ✅ | |
| `updatedAt` | `Timestamp` | ✅ | |
| `createdBy` | `string` | ✅ | UID de l'admin créateur |

#### Structure d'un tier
```json
{
  "tierId": "uuid-auto",
  "label": "U14",
  "amountCents": 18000
}
```

> **Pourquoi `amountCents` (int) et pas `amount` (double) ?**
> Les flottants causent des erreurs d'arrondi. 18000 centimes = 180,00 €. Toujours stocker en centimes, formater à l'affichage.

### 2.2. `clubs/{clubId}/fee_seasons/{seasonId}/member_fees/{memberId}`

> La clé est `memberId` (= `uid` pour les membres avec compte, = `pendingMemberId` pour les invités sans compte). Cohérent avec `members/{uid}` et `pending_members/{docId}`.

| Champ | Type | Obligatoire | Description |
|---|---|---|---|
| `memberId` | `string` | ✅ | Référence au membre |
| `memberDisplayName` | `string` | ✅ | Nom affiché (dénormalisé pour éviter N lectures) |
| `status` | `string` | ✅ | `a_payer` \| `paye` \| `exonere` |
| `tierId` | `string?` | ❌ | Référence vers un tier de la saison |
| `notesAdmin` | `string?` | ❌ | Notes privées admin |
| `paidAt` | `Timestamp?` | ❌ | Date de confirmation du paiement |
| `markedBy` | `string?` | ❌ | UID de l'admin qui a marqué payé |
| `createdAt` | `Timestamp` | ✅ | |
| `updatedAt` | `Timestamp` | ✅ | |

#### Statuts

| Statut stocké | Affichage | Condition |
|---|---|---|
| `a_payer` | "À payer" | Par défaut |
| `a_payer` | "En retard" | Calculé : `a_payer` + `paymentDeadlineAt` < `now` |
| `paye` | "Payé ✓" | Admin a confirmé |
| `exonere` | "Exonéré" | Staff, bénévoles, cas spéciaux |

> **"En retard" n'est PAS stocké** — c'est un état dérivé côté app. Ça évite un batch job / Cloud Function pour mettre à jour les statuts à minuit.

### 2.3. Règles Firestore

```javascript
// clubs/{clubId}/fee_seasons/{seasonId}
match /fee_seasons/{seasonId} {
  // Tout membre du club peut lire la config (montants, consignes)
  allow read: if isClubMember(clubId);
  // Seul un admin peut créer/modifier/supprimer
  allow write: if isClubAdmin(clubId);

  // clubs/{clubId}/fee_seasons/{seasonId}/member_fees/{memberId}
  match /member_fees/{memberId} {
    // Un membre peut lire SA propre fiche
    allow read: if request.auth.uid == memberId || isClubAdmin(clubId);
    // Seul un admin peut écrire
    allow write: if isClubAdmin(clubId);
  }
}
```

---

## 3. Côté joueur

### 3.1. Bannière rappel — `FeeReminderBanner`

**Emplacement** : `HomeMemberScreen`, en haut du contenu, sous le header club.

**Conditions d'affichage** (toutes doivent être vraies) :
1. Une `fee_season` avec `isActive: true` existe pour ce club
2. Un `member_fee` existe pour ce `memberId`
3. Le statut est `a_payer`
4. Le tier référencé a un `amountCents > 0`

**Contenu** :
```
💶 Cotisation {seasonLabel}
{amount} € à régler {avant le {deadline} | — pas de date limite}
                                          [Voir →]
```

**Si en retard** (deadline dépassée) : la bannière passe en couleur warning (orange/rouge), le texte affiche "En retard — {amount} € à régler".

**Si `paye` ou `exonere`** : pas de bannière.

**Si aucun `member_fee` n'existe pour ce joueur** : pas de bannière (l'admin ne l'a pas encore configuré).

### 3.2. Page "Ma cotisation" — `MyFeeScreen`

**Route** : `/club/:clubId/fees/mine`

**Accessible depuis** : la bannière rappel OU le menu du club (entrée "Ma cotisation" visible uniquement si une saison active existe).

**Contenu (lecture seule)** :

#### État : À payer / En retard
- Montant : `{amount} €` (gros, centré)
- Catégorie : `{tierLabel}` (ex: "U14")
- Date limite : `{deadline}` ou "Pas de date limite"
- **Encart "En retard"** si applicable (warning card)
- Consignes de paiement : texte libre de l'admin
- IBAN avec bouton copier (si renseigné)
- Moyens de paiement acceptés (icônes : virement, chèque, espèces)
- Encadré info : *"Le club vérifie manuellement les paiements. Seuls les administrateurs peuvent confirmer qu'une cotisation est réglée."*

#### État : Payé
- Message vert : "Votre cotisation {seasonLabel} est à jour ✓"
- Date de confirmation : `{paidAt}`
- Montant payé : `{amount} €`

#### État : Exonéré
- Message neutre : "Vous êtes exonéré(e) de cotisation pour la saison {seasonLabel}."

---

## 4. Côté admin

### 4.1. Page "Cotisations" admin — `AdminFeesScreen`

**Route** : `/club/:clubId/fees`

**Accessible depuis** : le menu admin du club (remplacer le `showComingSoon` actuel).

**2 sections** (tabs ou sections scrollables, selon le design system v2) :

---

#### Section 1 — Configuration saison

**Si aucune saison active** : bouton "Créer la saison" → formulaire de création.

**Si saison active** : formulaire d'édition avec :

| Champ | Widget | Notes |
|---|---|---|
| Libellé saison | `TextField` | Ex: "2025-2026" |
| Grille tarifaire | Liste éditable | Chaque tier : label + montant. Bouton ajouter/supprimer. |
| Consignes de paiement | `TextField` multiline | Texte libre |
| IBAN | `TextField` | Optionnel, avec validation format |
| Moyens de paiement | `MultiSelect chips` | Virement, Chèque, Espèces |
| Date limite | `DatePicker` | Optionnel |

**Bouton "Sauvegarder"** : met à jour le doc `fee_seasons/{seasonId}`.

**Bouton "Clôturer la saison"** : passe `isActive: false`. Confirmation requise. Les données restent accessibles en lecture.

> **Validation** : au moins 1 tier requis. Un tier ne peut pas être supprimé s'il est assigné à des `member_fees` existants (afficher un warning + demander confirmation).

---

#### Section 2 — Suivi des membres

**Header compteur** :
```
12 / 45 ont payé (27%)  •  8 exonérés  •  25 en attente
```

**Liste des member_fees** :

| Colonne | Contenu |
|---|---|
| Nom | `memberDisplayName` |
| Catégorie | Label du tier (ou "Non assigné") |
| Montant | `amountCents` formaté |
| Statut | Chip coloré : vert (payé), orange (à payer), rouge (en retard), gris (exonéré) |
| Actions | Menu contextuel |

**Filtres** :
- Par défaut : afficher `a_payer` + `en_retard` (les impayés d'abord)
- Toggle "Afficher tous" pour voir payés + exonérés
- Filtre par catégorie/tier (dropdown)
- Recherche par nom

**Actions par membre** (menu contextuel ou swipe) :
- Changer le statut → `a_payer` / `paye` / `exonere`
- Changer la catégorie → dropdown des tiers disponibles
- Ajouter une note admin

**Action en masse** :
- Sélection multiple (checkboxes)
- Actions disponibles : "Assigner catégorie {tier}", "Marquer payé", "Marquer exonéré"
- Confirmation avant exécution (batch write Firestore)

**Bouton "Initialiser les cotisations"** :
- Visible quand la saison est active mais peu/pas de `member_fees` existent
- Crée un `member_fee` avec `status: a_payer` pour chaque membre du club
- Auto-suggestion de tier basée sur `teams.category` du membre (si match avec un `tier.label`), sinon "Non assigné"
- Confirmation : "Créer {N} fiches de cotisation ?"
- Exclure les membres déjà existants dans `member_fees`

---

## 5. Architecture Flutter

### 5.1. Arborescence

```
lib/features/fees/
├── models/
│   ├── fee_season.dart          // FeeSeason (freezed ou immutable)
│   ├── fee_tier.dart            // FeeTier
│   └── member_fee.dart          // MemberFee + MemberFeeStatus enum
├── services/
│   └── fee_service.dart         // CRUD Firestore (pas de logique métier)
├── providers/
│   └── fee_providers.dart       // Riverpod providers (streams + state)
├── screens/
│   ├── my_fee_screen.dart       // Joueur — lecture seule
│   └── admin_fees_screen.dart   // Admin — config + suivi
└── widgets/
    ├── fee_reminder_banner.dart // Bannière home
    ├── fee_status_chip.dart     // Chip coloré par statut
    ├── fee_tier_editor.dart     // Widget édition grille tarifaire
    ├── member_fee_list_tile.dart // Ligne dans la liste admin
    └── fee_bulk_action_sheet.dart // Bottom sheet actions en masse
```

### 5.2. Modèles

```dart
// fee_season.dart
class FeeSeason {
  final String id;
  final String seasonLabel;
  final bool isActive;
  final String currency;
  final DateTime? paymentDeadlineAt;
  final String? paymentInstructions;
  final List<String> paymentMethods;
  final String? iban;
  final List<FeeTier> tiers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
}

// fee_tier.dart
class FeeTier {
  final String tierId;
  final String label;
  final int amountCents;

  /// Formatte le montant en euros : 18000 → "180,00 €"
  String get formattedAmount => '${(amountCents / 100).toStringAsFixed(2)} €';
}

// member_fee.dart
enum MemberFeeStatus { aPayer, paye, exonere }

class MemberFee {
  final String memberId;
  final String memberDisplayName;
  final MemberFeeStatus status;
  final String? tierId;
  final String? notesAdmin;
  final DateTime? paidAt;
  final String? markedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Statut d'affichage tenant compte de la deadline
  MemberFeeDisplayStatus displayStatus(DateTime? deadline) {
    if (status == MemberFeeStatus.paye) return MemberFeeDisplayStatus.paye;
    if (status == MemberFeeStatus.exonere) return MemberFeeDisplayStatus.exonere;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      return MemberFeeDisplayStatus.enRetard;
    }
    return MemberFeeDisplayStatus.aPayer;
  }
}

enum MemberFeeDisplayStatus { aPayer, enRetard, paye, exonere }
```

### 5.3. Providers (Riverpod)

```dart
// fee_providers.dart

/// Stream de la saison active du club
final activeSeasonProvider = StreamProvider.family<FeeSeason?, String>((ref, clubId) {
  return ref.watch(feeServiceProvider).watchActiveSeason(clubId);
});

/// Stream du member_fee du joueur connecté
final myFeeProvider = StreamProvider.family<MemberFee?, ({String clubId, String memberId})>((ref, params) {
  final season = ref.watch(activeSeasonProvider(params.clubId)).valueOrNull;
  if (season == null) return Stream.value(null);
  return ref.watch(feeServiceProvider).watchMemberFee(
    clubId: params.clubId,
    seasonId: season.id,
    memberId: params.memberId,
  );
});

/// Stream de tous les member_fees (admin)
final allMemberFeesProvider = StreamProvider.family<List<MemberFee>, String>((ref, clubId) {
  final season = ref.watch(activeSeasonProvider(clubId)).valueOrNull;
  if (season == null) return Stream.value([]);
  return ref.watch(feeServiceProvider).watchAllMemberFees(
    clubId: clubId,
    seasonId: season.id,
  );
});

/// Stats calculées (compteur admin)
final feeStatsProvider = Provider.family<FeeStats, String>((ref, clubId) {
  final fees = ref.watch(allMemberFeesProvider(clubId)).valueOrNull ?? [];
  final season = ref.watch(activeSeasonProvider(clubId)).valueOrNull;
  return FeeStats.compute(fees, season?.paymentDeadlineAt);
});
```

### 5.4. Service Firestore

```dart
// fee_service.dart — méthodes clés

class FeeService {
  final FirebaseFirestore _db;

  // === Lecture (streams) ===
  Stream<FeeSeason?> watchActiveSeason(String clubId);
  Stream<MemberFee?> watchMemberFee({required String clubId, required String seasonId, required String memberId});
  Stream<List<MemberFee>> watchAllMemberFees({required String clubId, required String seasonId});

  // === Écriture admin ===
  Future<void> createSeason(String clubId, FeeSeason season);
  Future<void> updateSeason(String clubId, String seasonId, Map<String, dynamic> updates);
  Future<void> closeSeason(String clubId, String seasonId);

  Future<void> setMemberFeeStatus(String clubId, String seasonId, String memberId, MemberFeeStatus status);
  Future<void> setMemberFeeTier(String clubId, String seasonId, String memberId, String tierId);
  Future<void> setMemberFeeNote(String clubId, String seasonId, String memberId, String note);

  // === Actions en masse ===
  Future<void> initializeMemberFees(String clubId, String seasonId, List<ClubMember> members, List<FeeTier> tiers);
  Future<void> bulkSetStatus(String clubId, String seasonId, List<String> memberIds, MemberFeeStatus status);
  Future<void> bulkSetTier(String clubId, String seasonId, List<String> memberIds, String tierId);

  // === Export ===
  Future<List<Map<String, dynamic>>> exportCsv(String clubId, String seasonId);
}
```

> **`initializeMemberFees`** : itère sur les membres du club, crée un `member_fee` par membre avec `status: a_payer`. Si le membre est dans une team dont la `category` matche un `tier.label`, pré-assigne le `tierId`. Utilise un `WriteBatch` Firestore (max 500 opérations par batch).

### 5.5. Routes (GoRouter)

```dart
// Dans routes.dart, ajouter sous le scope club :

GoRoute(
  path: 'fees',
  builder: (context, state) => const AdminFeesScreen(),
  routes: [
    GoRoute(
      path: 'mine',
      builder: (context, state) => const MyFeeScreen(),
    ),
  ],
),
```

**Accès** :
- `/club/:clubId/fees` → admin uniquement (vérifier le rôle dans le guard/redirect)
- `/club/:clubId/fees/mine` → tout membre

**Branchement** : dans `club_detail_screen.dart`, remplacer le `showComingSoon` du bouton "Cotisations" par `context.push('/club/$clubId/fees')` pour les admins, `/club/$clubId/fees/mine` pour les joueurs.

---

## 6. Points critiques corrigés par rapport au plan Cursor

### 6.1. ID de saison
**Cursor** : propose `fee_seasons/current` (doc ID fixe).
**Correction** : utiliser un ID auto-généré + `isActive: true`. Un doc "current" empêche de garder l'historique quand tu ajouteras le multi-saisons. Une query `where('isActive', '==', true).limit(1)` fonctionne aussi bien et n'impose pas de migration future.

### 6.2. Dénormalisation du nom
**Cursor** : ne stocke que `memberId` dans `member_fees`.
**Correction** : ajouter `memberDisplayName` dénormalisé. Sans ça, pour afficher la liste admin, il faut faire N lectures sur `members/{uid}` — O(N) reads Firestore, cher et lent. Le coût : mettre à jour le nom si un membre le change (rare, gérable avec un Cloud Function simple ou une mise à jour manuelle).

### 6.3. Traçabilité du paiement
**Cursor** : juste un `status: paye`, sans date ni auteur.
**Correction** : ajouter `paidAt` et `markedBy`. Indispensable pour le trésorier : "qui a validé, quand ?". Ça coûte 2 champs, mais ça évite des litiges.

### 6.4. Initialisation en masse
**Cursor** : mentionne l'assignation en masse mais pas la création initiale des fiches.
**Correction** : bouton "Initialiser les cotisations" qui crée un `member_fee` par membre du club. Sans ça, l'admin doit créer manuellement 45 fiches — rédhibitoire.

### 6.5. Pending members
**Cursor** : mentionne les pending_members mais ne détaille pas.
**Correction** : `initializeMemberFees` doit itérer sur DEUX collections — `members/{uid}` ET `pending_members/{docId}` — pour couvrir les invités sans compte. Le `memberId` est le `uid` ou le `pendingMemberId` selon le cas.

### 6.6. Suppression de tier protégée
**Cursor** : ne mentionne pas la protection.
**Correction** : un tier assigné à des `member_fees` ne peut pas être supprimé silencieusement. Afficher un warning : "Ce tier est assigné à {N} membres. Voulez-vous les réassigner à un autre tier avant de supprimer ?"

### 6.7. Export CSV
**Cursor** : liste en "priorité haute" mais sans spec.
**Correction** : inclus dans le service dès le MVP. Colonnes : Nom, Catégorie, Montant, Statut, Date paiement, Notes admin. Le trésorier en a besoin pour la compta du club — c'est un usage réel et fréquent.

---

## 7. Priorités d'implémentation

### Sprint 1 — Fondations (modèle + service + joueur)
1. Créer les modèles (`FeeSeason`, `FeeTier`, `MemberFee`)
2. Implémenter `FeeService` (CRUD + streams)
3. Créer les providers Riverpod
4. Page `MyFeeScreen` (joueur, lecture seule)
5. `FeeReminderBanner` sur la home club
6. Déployer les règles Firestore

### Sprint 2 — Admin
1. `AdminFeesScreen` — section config saison
2. `AdminFeesScreen` — section suivi membres (liste + filtres)
3. Actions individuelles (changer statut, tier, note)
4. Bouton "Initialiser les cotisations"
5. Actions en masse (bulk status, bulk tier)

### Sprint 3 — Polish
1. Export CSV
2. Compteur stats en header
3. Bouton copier IBAN
4. Validation formulaire (format IBAN, au moins 1 tier)
5. Animations et transitions

### Plus tard (hors MVP)
- Notifications push J-7 / J-1 (Cloud Function)
- Multi-saisons (historique + duplication config)
- Paiement partiel (`amountPaidCents`)
- Vue parent (quand le rôle parent sera implémenté)
- Intégration HelloAsso / Stripe

---

## 8. Checklist avant déploiement

- [ ] Règles Firestore déployées et testées (lecture joueur, écriture admin)
- [ ] `member_fees` créés pour les `pending_members` aussi
- [ ] Montants en centimes partout (pas de double/float)
- [ ] "En retard" calculé côté app, jamais stocké
- [ ] Suppression de tier protégée (warning si assigné)
- [ ] Batch write < 500 documents par opération
- [ ] Formatage montant avec virgule (FR) : `180,00 €`
- [ ] IBAN validé (format, pas existence réelle)
- [ ] Tests : admin crée saison → initialise fees → assigne tiers → marque payé → joueur voit le statut
- [ ] Route guard : `/fees` admin-only, `/fees/mine` tout membre

---

*Dernière mise à jour : mai 2026*
