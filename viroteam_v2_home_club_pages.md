# ViRoTeam — Pages Home Membre & Page Club

> **Référence Cursor** — Spec fonctionnelle et technique des pages Home globale et Page Club.
> Lire aussi `viroteam_firestore_model.md` pour le schéma de données complet.

---

## Navigation globale

```
Home membre (page d'accueil)
  ├── Barre clubs (haut) ──tap──→ Page Club
  ├── Section "À répondre"
  └── Planning complet (tous clubs)
```

---

## PAGE 1 — Home globale membre

### Layout (scroll vertical, pas de tabs)

```
┌─────────────────────────────────────┐
│  [Tous] [ClubA 🔴2] [ClubB] [ClubC] │  ← barre scrollable horizontale (fixe)
├─────────────────────────────────────┤
│  ⚡ À répondre (si events en attente)│
│  ┌─────────────────────────────────┐│
│  │ Entraînement · ClubA · Jeu 12/06││
│  │ 20h00 · Salle Municipale        ││
│  │      [✅ Présent] [❌ Absent]    ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  📅 Planning à venir                │
│  ┌─────────────────────────────────┐│
│  │ 🏃 Entraînement  [ClubA]        ││
│  │ Jeu 12/06 · 20h00 · Salle Mun. ││
│  │ ✅ Présent                      ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

---

### Bloc 1 — Barre des clubs

- Scroll horizontal, sticky en haut de page
- Item **"Tous"** sélectionné par défaut (vue globale)
- Pour chaque club : logo (ou initiales dans cercle coloré) + nom court
- **Badge rouge** avec le nombre d'events sans réponse dans ce club
- Tap sur un club → naviguer vers **Page Club** (pas de filtre sur la home)

---

### Bloc 2 — Section "À répondre"

**Condition d'affichage :** uniquement si `rsvp[uid] == 'none'` sur au moins un event à venir.

Chaque card affiche :
- Type d'event + nom
- Chip coloré avec le nom du club (couleur unique par club)
- Date, heure, lieu
- **Deux boutons côte à côte : ✅ Présent / ❌ Absent**
  - Action immédiate, sans confirmation, sans navigation
  - Feedback visuel instantané (bouton sélectionné)
  - La card disparaît avec une animation après réponse

Quand toutes les cards sont répondues → la section entière disparaît (animation de collapse).

---

### Bloc 3 — Planning complet à venir

Tous les events à venir du membre, **tous clubs confondus**, triés par date croissante.

Chaque card affiche :
- Icône du type (🏃 entraînement, ⚽ match, 🏆 tournoi)
- Chip coloré avec le nom du club
- Titre, date, heure, lieu
- Statut RSVP actuel avec possibilité de changer en 1 tap :
  - Sans réponse → affiche les deux boutons
  - Présent ✅ → tap pour passer à Absent
  - Absent ❌ → tap pour passer à Présent

---

### Chargement des données

```
1. Lire users/{uid}.clubMemberships  →  liste des clubId du membre

2. Pour chaque clubId (en parallèle via Future.wait) :
   Requête : clubs/{clubId}/events
   Filtres  : teamMemberIds contient uid
              date >= aujourd'hui
   Ordonné  : date ASC

3. Fusionner toutes les listes → trier par date

4. Séparer :
   - rsvp[uid] == 'none'  →  Section "À répondre"
   - rsvp[uid] != 'none'  →  Section "Planning à venir"

5. Sur tap Présent/Absent :
   Écrire : clubs/{clubId}/events/{eventId}.rsvp[uid] = 'yes' | 'no'
```

**Chargement :** afficher un shimmer sur les deux sections pendant `Future.wait`.
**Temps réel :** utiliser des streams Firestore — pas de pull-to-refresh nécessaire.

---

## PAGE 2 — Page Club

Ouverte au tap sur un club dans la barre du haut. Page dédiée, scroll vertical.

### Données à charger à l'entrée

```
clubs/{clubId}                    →  infos générales
clubs/{clubId}/members/{uid}      →  rôle du membre (source de vérité)
clubs/{clubId}/events             →  events à venir + events sans réponse
clubs/{clubId}/announcements      →  3 dernières annonces
```

---

### Bloc 1 — Header du club

- Logo (grande taille) + nom + sport + ville
- Badge rôle du membre : `Joueur` / `Coach` / `Admin`
- Bouton ⚙️ paramètres (visible Admin uniquement) → page gestion club

---

### Bloc 2 — À répondre (ce club uniquement)

Même logique que la home globale, filtré sur ce club.
Disparaît si tous les events sont répondus.

---

### Bloc 3 — Planning du club

Events à venir filtrés sur ce club. Même format de card que la home globale.

---

### Bloc 4 — Stats rapides

Cards horizontales scrollables, visibles par tous les rôles :

| Stat | Source |
|---|---|
| Taux de présence (30 derniers jours) | `events.attendance[uid].status` sur events passés |
| Prochain event | Premier event à venir de ce club |
| Membres actifs | `clubs/{clubId}.memberCount` |

> Pour le taux de présence : compter les events passés où `attendance[uid]` existe, calculer `present / total * 100`.

---

### Bloc 5 — Annonces

Les 3 dernières annonces de `clubs/{clubId}/announcements`, triées par `createdAt DESC`.

Chaque item affiche :
- Auteur (prénom nom) + date relative (ex : "il y a 2 jours")
- Message tronqué à 2 lignes
- Tap → bottom sheet ou modal avec le texte complet

---

### Bloc 6 — Accès rapides (selon rôle)

Afficher **uniquement** les actions accessibles au rôle. Ne pas afficher les actions désactivées.

| Action | Player | Coach | Admin |
|---|:---:|:---:|:---:|
| Mes équipes | ✅ | ✅ | ✅ |
| Pointer les présences | ❌ | ✅ | ✅ |
| Gérer les équipes | ❌ | ✅ | ✅ |
| Tournois (voir) | ✅ | ✅ | ✅ |
| Gérer les tournois | ❌ | ❌ | ✅ |
| Gérer les membres | ❌ | ❌ | ✅ |
| Cotisations | ❌ | ❌ | ✅ |

> **Règle :** lire le rôle depuis `clubs/{clubId}/members/{uid}.role` — jamais depuis `users/{uid}`.

---

## Règles UX globales

- **Aucune confirmation** après un tap Présent/Absent → action immédiate
- **Aucune navigation** pour répondre à un event → tout se fait inline
- **Shimmer** pendant le chargement initial des deux sections
- **Streams Firestore** pour la mise à jour temps réel (pas de refresh manuel)
- Les events **passés** ne sont pas affichés sur la home (uniquement à venir)
- Les sections vides s'affichent avec un message neutre (ex : *"Aucun event à venir"*)

---

## Fichiers à créer (un composant par fichier)

```
lib/
  pages/
    home_member_page.dart         ← Page 1 complète
    club_detail_page.dart         ← Page 2 complète
  widgets/
    club_selector_bar.dart        ← Barre clubs scrollable
    event_rsvp_card.dart          ← Card avec boutons Présent/Absent
    event_planning_card.dart      ← Card planning (statut modifiable)
    club_stats_row.dart           ← Bloc stats horizontales
    announcement_preview.dart     ← Item annonce avec modal
    quick_actions_grid.dart       ← Grille accès rapides selon rôle
```

---

*Dernière mise à jour : mai 2026*
