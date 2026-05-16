# ViroTeam v2: UX Journey (Detailed)

## Overview

**Your north star**: One person, one session, multiple roles. No app reloads. No shell switching. Instant transitions.

This document traces every screen, every button, every decision a user makes from launch to productivity.

---

## Part 1: Authentication Journey

### 1.1 App Launch

**Screen**: Splash screen (1 second, then evaluate auth state)

**Flow**:
```
User taps app icon
  ↓
Splash screen appears (ViroTeam logo + deep blue background)
  ↓
Check Firebase Auth: isLoggedIn?
  ├─ NO → Go to LoginScreen
  └─ YES → Go to ClubSelectorScreen
```

**Timing**: 1 second (flutter default splash)

**What's happening behind the scenes**:
- `AuthService.checkAuthStatus()` → Firebase Auth token check
- If token exists and valid → load user profile
- If expired or null → clear session

---

### 1.2 NOT Logged In → Login Screen

**Screen**: `LoginScreen` (or `AuthScreen` with tabs)

**Visual**:
```
┌────────────────────────────────┐
│                                │
│  ViroTeam                      │  ← Logo/branding
│  (deep blue color)             │
│                                │
│  [Email input field]           │  ← Standard text input
│                                │
│  [Password input field]        │  ← Standard text input
│                                │
│  [LOGIN button]                │  ← Primary button (blue)
│                                │
│  Pas de compte? [Sign up →]    │  ← Link to SignUpScreen
│                                │
│  (error message if login fails)│  ← Red text, dismissible
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Type email + password** → both fields validate on blur
   - Email: standard format check
   - Password: ≥8 chars
   - [LOGIN] button enabled only when both valid

2. **Tap [LOGIN]**
   - Show loading spinner inside button
   - Disable field inputs (grayed out)
   - Call Firebase Auth.signInWithEmailAndPassword(email, password)

3. **Success** → Auto-navigate to ClubSelectorScreen
   - Store token in SharedPreferences (auto-login next time)
   - Load user profile (name, avatar)

4. **Error** (wrong password, user not found)
   - Show red error message below password field
   - Re-enable inputs
   - Keep focus in password field (user can retry)
   - Example errors: "Wrong password" or "Account not found"

5. **Tap [Sign up →]** → Navigate to SignUpScreen

**No timeout, but handle network errors gracefully**:
- Network error → "No internet. Check connection."
- Firebase error → "Login failed. Try again."

**Edge case**: User exists but hasn't set up club yet
- Still login successfully
- Next screen will be ClubSelectorScreen

---

### 1.3 New User → Sign Up Screen

**Screen**: `SignUpScreen` (or tab within AuthScreen)

**Visual**:
```
┌────────────────────────────────┐
│                                │
│  Create Account                │  ← H2 heading
│                                │
│  [Name input field]            │  ← "Jean Dupont"
│                                │
│  [Email input field]           │  ← "jean@example.com"
│                                │
│  [Password input field]        │  ← "••••••••"
│                                │
│  [Confirm password field]      │  ← "••••••••"
│                                │
│  Password strength indicator   │  ← Visual feedback
│  ████░░░░ Medium              │
│                                │
│  [CREATE ACCOUNT button]       │  ← Primary button
│                                │
│  Already have account?         │  ← Link back to LoginScreen
│  [Log in →]                    │
│                                │
└────────────────────────────────┘
```

**Validations** (on blur or keystroke):

1. **Name**: ≥2 chars, no leading/trailing spaces
2. **Email**: valid email format, check if already registered (query Firestore)
3. **Password**: ≥8 chars, recommend mix of upper/lower/numbers
4. **Confirm password**: must match password field
5. **[CREATE ACCOUNT]** button: only enabled when all fields valid and passwords match

**Interactions**:

1. **Type name** → Trim spaces, show validation checkmark when valid

2. **Type email** → Validate format, check if exists in Firestore
   - If exists: show "Email already registered" error, highlight field

3. **Type password** → Show strength meter
   - Weak (< 8 chars): gray
   - Medium (8+ chars, mixed case): blue
   - Strong (12+ chars, mixed, numbers, special): green

4. **Type confirm** → Check match with password
   - If mismatch: show "Passwords don't match"

5. **Tap [CREATE ACCOUNT]**
   - Show loading spinner in button
   - Disable all fields
   - Call Firebase Auth.createUserWithEmailAndPassword(email, password)
   - Create `users/{uid}/profile` Firestore document with name, avatar (empty), etc.

6. **Success** → Auto-navigate to ClubSelectorScreen
   - Store token
   - New user starts from club setup

7. **Error** (email exists, weak password, network error)
   - Show error message
   - Re-enable fields
   - Don't clear form (user can fix and retry)

8. **Tap [Log in →]** → Back to LoginScreen (keep email in cache?)

---

## Part 2: Club & Role Setup

### 2.1 Club Selector Screen

**Precondition**: User is logged in, but hasn't selected a club yet
- `isLoggedIn = true`
- `activeClubId = null` → triggers this screen

**Screen**: `ClubSelectorScreen` (or first screen in AppShell flow)

**Visual**:
```
┌────────────────────────────────┐
│                                │
│  Mes clubs                     │  ← H2 heading
│                                │
│  ┌──────────────────────────┐  │
│  │ ASM (Foot)               │  │  ← Card, tap to select
│  │ Club • Football •        │  │
│  │ Île-de-France            │  │
│  │                          │  │
│  │ You're: Player, Coach    │  │  ← Your roles at this club
│  └──────────────────────────┘  │
│                                │
│  ┌──────────────────────────┐  │
│  │ Aviron Club (Rowing)     │  │
│  │ Club • Aviron •          │  │
│  │ Boulogne-Billancourt     │  │
│  │                          │  │
│  │ You're: Player           │  │
│  └──────────────────────────┘  │
│                                │
│  [+ Ajouter/Créer un club] │  ← Secondary button (full width)
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Fetch clubs** on screen load
   - Query `users/{uid}/memberships` collection
   - Get all clubs user is member of
   - Display as cards

2. **Tap a club card** → `setState(activeClubId = clubId)` → Auto-navigate to RolePickerScreen
   - No delay, instant
   - Store activeClubId in session provider + SharedPreferences

3. **Tap [+ Ajouter un club]**
   - Show modal or navigate to new screen: `JoinOrCreateClubScreen`
   - Options: "Join with code" or "Create new club"

---

### 2.2 Join or Create Club (Modal/Screen)

**Triggered from**: ClubSelectorScreen → [+ Ajouter un club]

**Screen**: `JoinOrCreateClubScreen` (two-tab or choice screen)

#### Option A: Join with Code

**Visual**:
```
┌────────────────────────────────┐
│ Rejoindre un club              │  ← Tab or heading
│                                │
│ Demandez le code d'invitation  │  ← Instructions
│ à votre entraîneur ou admin.   │
│                                │
│ [Code d'invitation input]      │  ← 6-char code (e.g., "ASM123")
│                                │
│ [REJOINDRE button]             │  ← Primary
│                                │
│ ou [CRÉER]                     │  ← Switch to create tab
│                                │
└────────────────────────────────┘
```

**Flow**:
1. User pastes/types code (e.g., "ASM123")
2. Tap [REJOINDRE]
3. Validate code → Query `clubs` collection for matching code
4. If found:
   - Create membership: `users/{uid}/memberships/{clubId}`
   - Auto-set role based on what was created with code (e.g., "player")
   - Show success → Return to ClubSelectorScreen
5. If invalid:
   - Show error "Code not found" or "Code expired"
   - Let user retry

#### Option B: Create Club

**Visual**:
```
┌────────────────────────────────┐
│ Créer un club                  │  ← Tab or heading
│                                │
│ [Club name input]              │  ← "ASM Football"
│                                │
│ [Sport selector dropdown]      │  ← "Football"
│                                │
│ [City input]                   │  ← "Île-de-France"
│                                │
│ [CRÉER button]                 │  ← Primary
│                                │
└────────────────────────────────┘
```

**Flow**:
1. User fills form
2. Tap [CRÉER]
3. Create in Firestore:
   - `clubs/{clubId}` → new club document
   - `clubs/{clubId}/info` → name, sport, city, created_by (user), created_at
   - `users/{uid}/memberships/{clubId}` → initial role "admin" (creator is admin)
4. Auto-navigate to RolePickerScreen with new club selected
5. User can then invite others via code

---

### 2.3 Role Picker Screen

**Precondition**: 
- `isLoggedIn = true`
- `activeClubId` set (e.g., "asm")
- `activeRole = null` → triggers this screen

**Screen**: `RolePickerScreen`

**Visual**:
```
┌────────────────────────────────┐
│                                │
│  Vos rôles à l'ASM             │  ← H2 heading
│                                │
│  Choisissez un rôle            │  ← Subtitle
│                                │
│  [⚽ En tant que joueur]        │  ← Button (full width, secondary)
│  [🏛️ En tant qu'entraîneur]    │  ← Button (full width, secondary)
│  [👨‍👩‍👧 En tant que parent]     │  ← Button (full width, secondary)
│                                │
│  (or just one button if user   │
│   has only one role)           │
│                                │
│  [Changer de club] ← back link │  ← Tertiary button
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Fetch user's roles** at selected club
   - Query `users/{uid}/memberships/{activeClubId}`
   - Get `roles` array (e.g., ["player", "coach"])
   - Filter to only show available roles

2. **Tap a role button**
   - `setState(activeRole = 'player')` (or coach, parent)
   - This triggers AppShell body rebuild
   - **No navigation.push, no new screen overlay**
   - Screen updates to home screen for that role (instant, ~200ms)

3. **Tap [Changer de club]** → Back to ClubSelectorScreen

**Edge case**: User has only 1 role → Auto-select it and proceed (no choice needed)

---

## Part 3: Home Screens (Daily Use)

### 3.1 App Shell (The Container)

**Structure**:
```
┌────────────────────────────────┐
│ [ASM ▼]      ⚽      ⚙️         │  ← TopBar (always visible)
├────────────────────────────────┤
│                                │
│                                │
│  BODY: PlayerHome or CoachHome │  ← Changes based on activeRole
│  (Scrollable)                  │
│                                │
│                                │
│                                │
└────────────────────────────────┘
```

**TopBar interactions** (always available):

1. **Tap [ASM ▼]** (Club selector)
   - Popover appears below the button
   - Shows: ✓ ASM, Aviron, [+ Add club]
   - Tap a club → `setState(activeClubId = clubId)` → Body updates to home screen of that club
   - Tap [+ Add club] → Navigate to JoinOrCreateClubScreen

2. **Tap [⚽]** (Role badge)
   - Popover appears to the right
   - Shows: ✓ ⚽ Player, 🏛️ Coach, 👨‍👩‍👧 Parent (only available roles)
   - Tap a role → `setState(activeRole = role)` → Body updates instantly to that home screen
   - **This is THE key interaction: instant switching, no reload**

3. **Tap [⚙️]** (Settings)
   - Navigate to SettingsScreen
   - Options: preferences, logout, about, etc.

---

### 3.2 Player Home Screen

**Precondition**: `activeRole = 'player'` AND `activeClubId` is set

**Visual** (from earlier mockups):
```
┌────────────────────────────────┐
│ [ASM ▼]      ⚽      ⚙️         │  ← TopBar
├────────────────────────────────┤
│                                │
│  Bienvenue, Marie              │  ← Greeting
│  Vous êtes joueur à l'ASM      │
│                                │
│  Samedi 15 mars        15:00   │
│  ⚽ Match - U15 Séniors        │  ← Next event card
│  Stade Municipal               │
│  [Oui ✓] [Peut-être] [Non]    │
│                                │
│  Mardi 18 mars         19:30   │
│  🏃 Entraînement               │  ← Event list continues
│  [Oui] [Peut-être] [Non]      │
│                                │
│  VOS STATS                     │
│  Matchs: 12 | Buts: 3          │
│  Assists: 1 | Présence: 92%    │
│                                │
│  VOS AUTRES RÔLES              │
│  [🏛️ En tant qu'entraîneur]   │  ← Tap to switch roles
│  [👨‍👩‍👧 En tant que parent]  │
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Tap event card** → Navigate to EventDetailsScreen
   - Shows full event info, attendance list, map
   - Buttons to RSVP or view details

2. **Tap RSVP button** ([Oui], [Peut-être], [Non])
   - `setState(attendance[eventId][userId] = 'present')`
   - Update Firestore: `clubs/{clubId}/events/{eventId}/attendance/{userId}`
   - Show visual feedback (button color changes to primary)
   - Optional: toast "RSVP saved"

3. **Tap role button** ([🏛️ Coach], [👨‍👩‍👧 Parent])
   - `setState(activeRole = 'coach')`
   - Body instantly switches to CoachHome (~200ms)
   - Smooth transition, no flash

4. **Scroll** → Standard iOS/Android scroll behavior
   - Pull-to-refresh to reload events (optional)

**Data fetching**:
- On screen load: `EventsProvider.fetchEvents(clubId)` → filtered for this club
- Real-time updates via Firestore listeners (if implemented)
- Cached locally in state

---

### 3.3 Coach Home Screen

**Precondition**: `activeRole = 'coach'` AND `activeClubId` is set

**Visual**:
```
┌────────────────────────────────┐
│ [ASM ▼]      🏛️      ⚙️        │  ← TopBar
├────────────────────────────────┤
│                                │
│  Entraîneur                    │  ← Role context
│  Équipe U15 • 15 joueurs       │
│                                │
│  [+ CRÉER UN ÉVÉNEMENT]        │  ← Primary CTA (full width)
│                                │
│  MES ÉVÉNEMENTS (3)            │
│  Samedi 15 mars        15:00   │  ← Event card (coach version)
│  ⚽ Match - U15 Séniors        │
│  12/15 confirmés  [DÉTAILS →] │
│                                │
│  EFFECTIF (15)                 │
│  Titulaires (11)               │
│  👤 Marie Dupont       #7      │  ← Roster item
│  Attaquant • Présente          │
│                                │
│  👤 Jean Moreau        #4      │
│  Défenseur • Présent           │
│                                │
│  Remplaçants (4)               │
│  👤 Luc Benoit         #12     │
│  Milieu • Blessé               │
│                                │
│  VOS AUTRES RÔLES              │
│  [⚽ En tant que joueur]        │  ← Switch roles
│  [👨‍👩‍👧 En tant que parent]  │
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Tap [+ CRÉER UN ÉVÉNEMENT]**
   - Navigate to CreateEventScreen (modal or full screen)
   - Form: type, date, time, location, opponent (for matches)
   - On submit: create in Firestore, auto-notify all players

2. **Tap event card** → EventDetailsScreen (coach version)
   - Shows attendance (who RSVPd, who pending)
   - Option to mark attendance manually
   - Option to set lineup (for matches)

3. **Tap roster item** → EditRosterItemScreen (optional, for later versions)
   - Edit position, number, status
   - Delete player from team

4. **Tap role buttons** → Same as player (switch roles instantly)

---

### 3.4 Parent Home Screen

**Precondition**: `activeRole = 'parent'` AND `activeClubId` is set

**Visual**:
```
┌────────────────────────────────┐
│ [ASM ▼]      👨‍👩‍👧    ⚙️        │  ← TopBar
├────────────────────────────────┤
│                                │
│  Calendrier                    │  ← Title
│  2 enfants inscrits            │
│                                │
│  SARAH (U13 Filles)            │  ← Child name
│  Samedi 15 mars        14:00   │  ← Event card
│  ⚽ Match - U13 Filles         │
│  Stade Municipal               │
│  [Oui ✓] [Peut-être] [Non]    │
│                                │
│  Jeudi 13 mars         17:30   │
│  🏃 Entraînement               │
│  [Oui] [Peut-être ✓] [Non]    │
│                                │
│  LUCAS (U15 Garçons)           │  ← Second child
│  Samedi 15 mars        15:30   │
│  ⚽ Match - U15 Garçons        │
│  [Oui ✓] [Peut-être] [Non]    │
│                                │
│  VIS-À-VIS                     │  ← Team info summary
│  Équipe: U13 Filles            │
│  Coach: Marie Dupont           │
│  Classement: 2ème/8            │
│  Prochain: Samedi 15:00        │
│                                │
│  VOS AUTRES RÔLES              │
│  [⚽ En tant que joueur]        │
│  [🏛️ En tant qu'entraîneur]   │
│                                │
└────────────────────────────────┘
```

**Interactions**:

1. **Tap RSVP button** (for each child's event)
   - `setState(attendance[eventId][childId] = 'present')`
   - Update Firestore for child's attendance
   - Show visual feedback (button highlights)

2. **Tap event card** → EventDetailsScreen (read-only for parents)
   - See full event details, roster, coach contact

3. **Tap role buttons** → Switch roles instantly (same as player/coach)

---

## Part 4: The Magic: Role Switching

### 4.1 Instant Transition (the core differentiator)

**Scenario**: Marie is viewing PlayerHome, sees coach schedule

**Flow**:
```
1. User taps [🏛️ Coach] badge in TopBar
   ↓
2. Popover appears with role options
   ↓
3. User taps "En tant qu'entraîneur"
   ↓
4. setState(activeRole = 'coach') fires
   ↓
5. AppShell.build() re-renders with activeRole = 'coach'
   ↓
6. Body switches from PlayerHome to CoachHome
   ↓
   ✓ Screen shows roster, events, + CREATE button
   ✓ Time: ~200ms (feels instant)
   ✓ No app reload
   ✓ No navigation.push
   ✓ No shell swap
```

**Visual feedback**:
- Role badge color changes (⚽ blue → 🏛️ amber)
- Body content fades briefly (optional 100ms opacity animation)
- TopBar stays visible (no jank)

**What's NOT happening**:
- ❌ No navigation.pushAndRemoveUntil
- ❌ No new screen overlay
- ❌ No Firebase network request (data already cached)
- ❌ No "Loading..." spinner
- ❌ No delay

**Why this is different from competitors**:
- SportEasy: Switching roles = different app profile = reload
- FFA: Switching roles = new tabs, but still some navigation delay
- ViroTeam: setState + hot rebuild = instant

---

### 4.2 Club Switching

**Scenario**: Marie has two clubs (ASM, Aviron), wants to check Aviron schedule

**Flow**:
```
1. Tap [ASM ▼] club selector
   ↓
2. Popover shows: ✓ ASM, Aviron, [+ Add]
   ↓
3. Tap "Aviron"
   ↓
4. setState(activeClubId = 'aviron') fires
   ↓
5. EventsProvider fetches events for Aviron
   ↓
6. If activeRole valid for Aviron (e.g., 'player'):
   → Body stays in PlayerHome, but now shows Aviron's events
   If activeRole NOT valid for Aviron (e.g., user is only coach there):
   → Auto-switch to valid role (e.g., coach) + home screen updates
```

**Timing**: ~300-500ms (includes Firestore fetch for new club's events)

**Visual feedback**:
- Club selector shows new club ([Aviron ▼])
- Body starts loading skeleton screens (optional)
- Events appear once fetched

---

## Part 5: Edge Cases & Error Handling

### 5.1 Network Errors

**Scenario**: User in metro, loses network, taps RSVP

**Expected behavior**:
- Button click still works (optimistic UI)
- Local state updates immediately: `attendance[eventId][userId] = 'present'`
- Button shows "✓ RSVP saved (offline)"
- When network returns: sync to Firestore automatically
- No error dialog unless sync actually fails

---

### 5.2 Session Expires

**Scenario**: User was logged in 48h ago, opens app

**Expected behavior**:
- Firebase Auth token expired
- AppShell detects: `isLoggedIn = false`
- Redirect to LoginScreen
- Prefill email (from SharedPreferences) for convenience
- Clear all session state (activeClubId, activeRole)

---

### 5.3 User Removed from Club

**Scenario**: Admin removes Marie from ASM club

**Expected behavior**:
- If Marie is currently viewing ASM:
  - Next sync: error from Firestore rules
  - Show toast: "You've been removed from ASM"
  - Auto-switch to another club if available
  - If no other clubs: show ClubSelectorScreen
- If Marie is logged out:
  - On login: simply won't show ASM in club list

---

### 5.4 Multiple Roles with Conflicting Data

**Scenario**: Marie switches from coach to player mid-action (e.g., was creating event)

**Expected behavior**:
- Creating event form gets dismissed (user is no longer in coach mode)
- PlayerHome loads fresh (safe state)
- No data loss (event creation wasn't submitted)
- If event WAS submitted before role switch: it exists and is visible in coach mode

---

## Part 6: First-Time User Walkthrough (Optional)

If you want to add onboarding:

**Screens** (in order):
1. "Welcome to ViroTeam" (logo, tagline)
2. "Manage multiple roles" (explainer: coach + player + parent together)
3. "Join your club" (explain invite codes)
4. "Switch roles instantly" (show the switching UI)
5. "You're ready!" (button to start)

**Alternatively**: Skip onboarding, let the UI teach by doing.

---

## Summary: The User Journey in One Sentence

> **From app open to productivity in <2 minutes: Login → Join club → Pick role → See home screen. Switch roles in 200ms. Switch clubs in 500ms. No reloads, ever.**

---

## Metrics That Matter

If you want to measure success:

| Metric | Target | Why it matters |
|--------|--------|----------------|
| Auth to home screen | <30 seconds | User doesn't bounce |
| Role switch latency | <300ms | Feels native |
| Club switch latency | <1s | User doesn't think app is slow |
| Time to first RSVP | <2 minutes | Onboarding → action |
| Crash rate | <0.1% | App stability |
| Notification delivery | 95%+ | Users trust push |

---

## Prototype Testing Checklist

Before launch, test this journey on real devices:

- [ ] Login on slow 3G network (should not timeout)
- [ ] RSVP offline, then reconnect (should sync)
- [ ] Switch roles 5x in a row (no crashes, no delays)
- [ ] Switch clubs 5x in a row (events update correctly)
- [ ] Role buttons show only valid roles (no orphaned options)
- [ ] TopBar stays visible when scrolling (no jank)
- [ ] Dropdowns dismiss on backdrop tap
- [ ] Back button (Android) navigates correctly
- [ ] Session persists across app kills
- [ ] Logout clears all state
- [ ] Test on iPhone SE (small screen), iPad (large)
- [ ] Test with slow Firebase (throttle network in DevTools)

---

## Key Principles (Revisited)

1. **One shell, always**: AppShell stays mounted. Only body content changes.
2. **setState, not navigation**: Role/club switches are state changes, not screen navigations.
3. **Instant feedback**: Every button tap should feel responsive (~<300ms total).
4. **No reloads**: User should never see a splash screen or loading screen after initial auth.
5. **Offline-first**: UI works offline, syncs when network returns.
6. **Clear identity**: TopBar always shows (club, role) so user knows where they are.

Follow these, and you've got a world-class UX.
