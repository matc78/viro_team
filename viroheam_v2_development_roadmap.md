# ViroTeam v2: Development Roadmap

## Overview

**Launch date**: No timeline pressure — ship when ready, but with structured milestones.

**Total estimate**: 8-10 weeks for full MVP (flexible).

**Team**: Solo (you).

**Stack**: Flutter, Dart, Firestore, Firebase Auth, FCM.

---

## Phase 1: Foundation (Weeks 1-2)

### Week 1: Setup + Design System Implementation

**Goal**: Have a clean Flutter project with all design tokens and components ready.

**Tasks:**

**Day 1-2: Project Setup**
- [ ] Create new Flutter project (viroheam_v2)
- [ ] Set up folder structure:
  ```
  lib/
    ├── config/
    │   ├── theme.dart (colors, typography)
    │   └── routes.dart
    ├── models/
    │   ├── user.dart
    │   ├── club.dart
    │   ├── membership.dart
    │   ├── team.dart
    │   ├── event.dart
    │   └── attendance.dart
    ├── providers/ (Riverpod)
    │   ├── auth_provider.dart
    │   ├── session_provider.dart
    │   ├── user_provider.dart
    │   ├── club_provider.dart
    │   ├── events_provider.dart
    │   └── roster_provider.dart
    ├── screens/
    │   ├── auth/
    │   │   ├── login_screen.dart
    │   │   ├── signup_screen.dart
    │   │   └── onboarding_screen.dart
    │   ├── app/
    │   │   ├── app_shell.dart
    │   │   ├── player/
    │   │   │   └── player_home.dart
    │   │   ├── coach/
    │   │   │   └── coach_home.dart
    │   │   └── parent/
    │   │       └── parent_home.dart
    │   └── settings/
    │       └── settings_screen.dart
    ├── widgets/ (Reusable components)
    │   ├── buttons/
    │   │   ├── primary_button.dart
    │   │   ├── secondary_button.dart
    │   │   └── tertiary_button.dart
    │   ├── cards/
    │   │   ├── event_card.dart
    │   │   ├── stats_card.dart
    │   │   └── roster_item.dart
    │   ├── headers/
    │   │   ├── top_bar.dart
    │   │   ├── club_selector.dart
    │   │   └── role_badge.dart
    │   └── common/
    │       ├── section_header.dart
    │       └── error_state.dart
    └── services/
        ├── firebase_service.dart
        ├── auth_service.dart
        └── firestore_service.dart
  ```
- [ ] Add dependencies:
  - firebase_core, firebase_auth, cloud_firestore
  - riverpod, flutter_riverpod
  - go_router (routing)
- [ ] Initialize Firebase (development & production configs)

**Day 3-4: Design Tokens**
- [ ] Create `lib/config/theme.dart`:
  - [ ] Color palette (all 11 colors with hex values)
  - [ ] TextTheme (H1-H3, body, small, tiny)
  - [ ] ThemeData configuration
  - [ ] Custom color classes
- [ ] Verify theme on test screen

**Day 5: Component Library (Part 1)**
- [ ] Build PrimaryButton widget
- [ ] Build SecondaryButton widget
- [ ] Build TertiaryButton widget
- [ ] Build Badge widget (4 role variants)
- [ ] Build Input widget
- [ ] Build Card widget
- [ ] Test all components with live reload

**Deliverable**: 
- Flutter project structure ready
- Design system implemented (colors, typography)
- Button + Card components working
- Can see components in Storybook-style screen

---

### Week 2: Firebase Setup + More Components

**Goal**: Firebase ready, all components built, auth scaffold ready.

**Tasks:**

**Day 1-2: Firebase Setup**
- [ ] Create Firestore collections:
  - [ ] `users/{uid}/profile`
  - [ ] `users/{uid}/memberships/{clubId}`
  - [ ] `clubs/{clubId}/info`
  - [ ] `clubs/{clubId}/teams/{teamId}`
  - [ ] `clubs/{clubId}/events/{eventId}`
  - [ ] `clubs/{clubId}/invitations/{inviteId}`
  - [ ] `memberships/{clubId}/{uid}` (inverted index)
- [ ] Create Firestore security rules (from design blueprint)
- [ ] Create Firebase Auth custom claims setup (for admin identification)
- [ ] Test manually with Firebase Console

**Day 3: Component Library (Part 2)**
- [ ] Build EventCard widget (for all three roles)
- [ ] Build RosterItem widget
- [ ] Build StatsCard widget
- [ ] Build TopBar widget
- [ ] Build ClubSelector dropdown
- [ ] Build RoleBadge widget
- [ ] Build RolePicker popover

**Day 4-5: Service Layer**
- [ ] Create FirebaseService (wrapper around Firebase)
  - [ ] signUp(email, password)
  - [ ] signIn(email, password)
  - [ ] signOut()
  - [ ] getCurrentUser()
- [ ] Create AuthService (business logic)
- [ ] Create FirestoreService (CRUD for all models)
- [ ] Create Riverpod providers for auth

**Deliverable**:
- Firebase project fully set up
- All 12+ components built and tested
- Auth service skeleton ready
- Providers initialized

---

## Phase 2: Authentication & Session (Weeks 3)

### Week 3: Auth Flow + Session Management

**Goal**: User can sign up, log in, and session persists.

**Tasks:**

**Day 1-2: Auth Screens**
- [ ] Build LoginScreen
  - [ ] Email input
  - [ ] Password input
  - [ ] [Login] button
  - [ ] "Don't have account?" link to SignUpScreen
  - [ ] Error handling (wrong password, etc.)
  - [ ] Loading state
- [ ] Build SignUpScreen
  - [ ] Email input
  - [ ] Password input (with strength indicator)
  - [ ] Confirm password input
  - [ ] Name input
  - [ ] [Create account] button
  - [ ] Validation (email format, password length, etc.)
- [ ] Test with Firebase (real sign up/login)

**Day 3: Session Provider**
- [ ] Build SessionProvider (Riverpod):
  - [ ] userId (current logged-in user)
  - [ ] activeClubId (selected club)
  - [ ] activeRole (selected role: player/coach/parent/admin)
  - [ ] isLoggedIn (derived)
  - [ ] isClubSelected (derived)
  - [ ] isRoleSelected (derived)
- [ ] Implement token persistence (SharedPreferences)
- [ ] Auto-login on app launch if token exists

**Day 4-5: App Shell Routing**
- [ ] Build AppShell (the main navigation hub)
  - [ ] If not logged in → show LoginScreen
  - [ ] If logged in but no club → show ClubSelectorScreen
  - [ ] If club selected but no role → show RolePickerScreen
  - [ ] If fully set up → show home screen based on role
- [ ] Implement basic routing with go_router
- [ ] Test flow: login → club selector → role picker → player home

**Deliverable**:
- Users can sign up and log in
- Session persists across app restarts
- AppShell correctly routes based on session state

---

## Phase 3: Club Management (Weeks 4)

### Week 4: Club Selector + Onboarding

**Goal**: User can join or create a club, select their role(s).

**Tasks:**

**Day 1-2: Club Selector Screen**
- [ ] Build ClubSelectorScreen
  - [ ] List of user's clubs (fetched from Firestore)
  - [ ] [+ Join or create club] button
  - [ ] Tap a club → navigates to RolePickerScreen (sets activeClubId)
- [ ] Build JoinClubScreen (modal or new screen)
  - [ ] Text input for invite code
  - [ ] [Join] button
  - [ ] Handle invalid codes
  - [ ] Automatically set as member
- [ ] Build CreateClubScreen (modal or new screen)
  - [ ] Club name input
  - [ ] Sport selector dropdown
  - [ ] City input
  - [ ] [Create] button
  - [ ] Auto-set creator as admin

**Day 3: Role Picker Screen**
- [ ] Build RolePickerScreen
  - [ ] Show user's roles at selected club (from membership.roles)
  - [ ] [⚽ As player], [🏛️ As coach], [👨‍👩‍👧 As parent], etc.
  - [ ] Tap a role → setState(activeRole = role), navigate to home
  - [ ] If only 1 role, auto-select it

**Day 4-5: Integration**
- [ ] Connect ClubSelectorScreen to Firebase (fetch user's clubs)
- [ ] Connect RolePickerScreen to Firebase (fetch roles from membership)
- [ ] Test flow: login → join club → select role → player home
- [ ] Handle edge cases (user with 0 clubs, user with 1 club, etc.)

**Deliverable**:
- Users can join/create clubs
- Users can select roles
- Full auth + club + role flow works

---

## Phase 4: Player Features (Weeks 5-6)

### Week 5: Player Home Screen

**Goal**: Player can see schedule, RSVP to events.

**Tasks:**

**Day 1-2: PlayerHome Screen**
- [ ] Build PlayerHome screen (from mockup)
  - [ ] Greeting section (Welcome, {name})
  - [ ] Next event card with RSVP buttons
  - [ ] List of upcoming events (next 5)
  - [ ] Stats mini cards (matches, goals, assists, attendance %)
  - [ ] Role switcher (buttons to switch to coach/parent if applicable)
- [ ] Connect to EventsProvider (fetch events from Firestore)
- [ ] Display real data from database

**Day 3: RSVP Logic**
- [ ] Build RSVP handler:
  - [ ] Tap [Yes/Maybe/No] → updates attendance in Firestore
  - [ ] Show confirmation (visual feedback, color change)
  - [ ] Optimistic UI (update locally, then sync)
- [ ] Build AttendanceProvider (manage attendance state)
- [ ] Test RSVP flow

**Day 4: Stats Calculation**
- [ ] Build StatsProvider:
  - [ ] Fetch all events user is registered for
  - [ ] Count matches, confirmed, goals (if tracked), assists
  - [ ] Calculate attendance % (confirmed / total)
  - [ ] Display on PlayerHome
- [ ] Add filtering (this month, this season, all-time)

**Day 5: Scroll & Polish**
- [ ] Ensure scroll area works correctly
- [ ] Safe area padding for home indicator
- [ ] Loading states (skeleton screens for events)
- [ ] Error states (no events, network error)

**Deliverable**:
- PlayerHome fully functional
- Player can see schedule and RSVP
- Stats calculate and display correctly

---

### Week 6: Event Details + Navigation

**Goal**: Player can drill down into event details, see attendance.

**Tasks:**

**Day 1-2: Event Details Screen**
- [ ] Build EventDetailsScreen
  - [ ] Full event info (date, time, location, description)
  - [ ] Attendance list (who's confirmed, who's maybe, who's absent)
  - [ ] Map view of location (if coordinates available)
  - [ ] RSVP status and buttons
  - [ ] Back button
- [ ] Connect to EventProvider (fetch single event)

**Day 3: Role Switcher UX**
- [ ] Build RoleSwitcherPopover (from design)
  - [ ] Tap role badge → show popover with available roles
  - [ ] Tap a role → setState(activeRole = role), close popover, rebuild body
  - [ ] Smooth transition (~200ms)
- [ ] Test on actual phone (latency, animation smoothness)

**Day 4-5: Bottom Navigation (Optional)**
- [ ] Build BottomNav widget
  - [ ] Home, Schedule, Team, Account tabs
  - [ ] Tap a tab → show corresponding content
- [ ] Or: Use drawer instead (simpler for now)
- [ ] Polish navigation flow

**Deliverable**:
- Player can drill down to event details
- Role switcher works smoothly
- Navigation feels responsive

---

## Phase 5: Coach Features (Weeks 7-8)

### Week 7: Coach Home + Roster

**Goal**: Coach can see roster, manage players, create events.

**Tasks:**

**Day 1-2: CoachHome Screen**
- [ ] Build CoachHome screen (from mockup)
  - [ ] Role context header (Entraîneur - Équipe U15)
  - [ ] [+ Create event] button (primary)
  - [ ] My events section (upcoming coaching duties)
  - [ ] Roster section (titulaires, remplaçants)
  - [ ] Role switcher
- [ ] Connect to RosterProvider (fetch team members)
- [ ] Display real roster data

**Day 3: Create Event Modal**
- [ ] Build CreateEventScreen (full-screen or modal)
  - [ ] Event type selector (training, match, tournament, other)
  - [ ] Title input
  - [ ] Date/time pickers
  - [ ] Location input (with search)
  - [ ] Opponent name (for matches)
  - [ ] [Create] button
- [ ] Handle Firestore write
- [ ] Real-time update to coach's event list

**Day 4-5: Roster Management**
- [ ] Build RosterItem with edit capability (for coaches)
  - [ ] Tap item → edit screen (position, number, status)
  - [ ] Add/remove players
  - [ ] Bulk actions (mark all present, mark all absent)
- [ ] Connect to RosterProvider (CRUD)

**Deliverable**:
- Coach can see roster
- Coach can create events
- Coach can edit roster (basic)

---

### Week 8: Attendance Tracking + Lineups

**Goal**: Coach can track attendance, set lineups for matches.

**Tasks:**

**Day 1-2: Attendance Marking**
- [ ] Build AttendanceScreen (accessed from event details)
  - [ ] List of team members
  - [ ] [Present], [Absent], [Maybe], [Injured] buttons for each
  - [ ] Batch actions (select all, mark all present)
  - [ ] [Save] button
- [ ] Real-time sync to Firestore (or bulk update)

**Day 3: Lineup Builder (Basic)**
- [ ] For matches: allow coach to set starting XI
  - [ ] Drag players into starting vs bench
  - [ ] Set formation (optional, for v2.1)
  - [ ] Save lineup
- [ ] Display lineup on EventDetailsScreen

**Day 4-5: Match Results**
- [ ] After match: allow coach to log result
  - [ ] Final score
  - [ ] Goal scorers (if tracked)
  - [ ] Player performances (optional)
  - [ ] Notes
- [ ] Store in event document

**Deliverable**:
- Coach can mark attendance
- Coach can set lineups
- Coach can log match results

---

## Phase 6: Parent Features (Week 9)

### Week 9: Parent Home + Quick RSVP

**Goal**: Parent can see kids' schedules, quick RSVP.

**Tasks:**

**Day 1-2: ParentHome Screen**
- [ ] Build ParentHome screen (from mockup)
  - [ ] Children calendars (tabbed or stacked)
  - [ ] Events for each child
  - [ ] Quick RSVP buttons (Oui/Peut-être/Non)
  - [ ] Team info cards (coach, standings, etc.)
  - [ ] Role switcher
- [ ] Connect to ParentProvider (fetch children's events)
- [ ] Display real data

**Day 3-4: Parent Permissions**
- [ ] Verify Firestore rules: parents can only see their children's events
- [ ] Handle privacy (parents can't edit roster, just RSVP for kids)
- [ ] Notifications for parents (kids' events reminders)

**Day 5: Polish**
- [ ] Error states (no children registered, no events)
- [ ] Loading states
- [ ] Responsive layout (multiple children)

**Deliverable**:
- Parent can see kids' schedules
- Parent can RSVP for kids
- Privacy and permissions correct

---

## Phase 7: Notifications (Week 10)

### Week 10: Push Notifications

**Goal**: Users receive notifications for upcoming events, status changes.

**Tasks:**

**Day 1-2: FCM Setup**
- [ ] Configure Firebase Cloud Messaging
- [ ] Set up notification handlers (foreground, background, terminated)
- [ ] Request user permission for notifications (iOS/Android)
- [ ] Store FCM token in Firestore (users/{uid}/fcm_tokens)

**Day 3-4: Notification Triggers**
- [ ] Coach creates event → players get notification
- [ ] Event reminder (24h, 1h, 15m before)
- [ ] Attendance status change (someone RSVP'd)
- [ ] Match result posted (for parents)

**Day 5: Local Notifications**
- [ ] For reminders that need to be reliable (use local scheduling)
- [ ] Set up local notification plugin (flutter_local_notifications)

**Deliverable**:
- Push notifications work end-to-end
- Users can opt in/out
- Reminders sent reliably

---

## Phase 8: Polish & Launch Prep (Weeks 11-12)

### Week 11: Testing + Edge Cases

**Goal**: App is stable, handles errors gracefully.

**Tasks:**

**Day 1-2: Manual Testing**
- [ ] Test all flows on real device (iPhone + Android)
- [ ] Test on slow network (throttle in dev tools)
- [ ] Test offline (kill network, then restore)
- [ ] Test edge cases:
  - [ ] User with 0 clubs
  - [ ] User with 1 club
  - [ ] User with 5+ clubs
  - [ ] User with 0 roles
  - [ ] User with 4 roles
  - [ ] Coach with 0 players
  - [ ] Coach with 50 players
  - [ ] Event with 0 attendees
  - [ ] Event 2 days away vs 2 weeks away

**Day 3-4: Error Handling**
- [ ] Network errors (show toast/snackbar)
- [ ] Firestore errors (permissions denied, quota exceeded)
- [ ] Auth errors (session expired, re-login)
- [ ] Graceful degradation (show cached data if network fails)

**Day 5: Performance**
- [ ] Profile app (check for jank)
- [ ] Optimize image loading (club logos, avatars)
- [ ] Lazy load events (paginate after 10)
- [ ] Cache Firestore queries where appropriate

**Deliverable**:
- App handles edge cases
- Error messages are helpful
- No crashes

---

### Week 12: Design Review + Polish

**Goal**: App is polished and ready to share.

**Tasks:**

**Day 1-2: Design Review**
- [ ] Compare against mockups
- [ ] Spacing, colors, typography match
- [ ] Icons are correct (emoji or custom)
- [ ] Animations/transitions smooth (no jank)
- [ ] Safe area respected on all screens

**Day 3: Accessibility**
- [ ] Color contrast check (WCAG AA)
- [ ] Text sizes are readable (min 14px for body)
- [ ] Touch targets 44px+ minimum
- [ ] Semantic labels for screen readers

**Day 4-5: Final Polish**
- [ ] App icon + splash screen (branding)
- [ ] Review copy (spelling, grammar in French)
- [ ] Deep links working (if implemented)
- [ ] Shortcuts working (Home, Create Event, etc.)

**Deliverable**:
- App is visually polished
- Accessible and ready for users
- App store ready (screenshots, description, etc.)

---

## Milestones & Checkpoints

| Week | Milestone | Status |
|------|-----------|--------|
| 2 | Design system + components done | ⏳ |
| 3 | Auth flow working | ⏳ |
| 4 | Club management done | ⏳ |
| 6 | Player features 100% | ⏳ |
| 8 | Coach features 100% | ⏳ |
| 9 | Parent features 100% | ⏳ |
| 10 | Notifications working | ⏳ |
| 12 | App polished & ready to test | ⏳ |

---

## Optional Features (Post-MVP)

These are great additions but NOT required for launch:

- [ ] Calendar view (vs list view)
- [ ] Team standings/league table
- [ ] Player performance stats (goals, assists, yellow cards)
- [ ] Custom match formations
- [ ] Photo gallery (from matches)
- [ ] Team chat (in-app messaging)
- [ ] Integration with external calendar (iCal export)
- [ ] Web app (progressive web app version)
- [ ] Dark mode
- [ ] Multi-language (EN, ES, etc.)

---

## Daily Standup Template

Each morning, ask yourself:

1. **What did I ship yesterday?** (feature, fix, or learning)
2. **What am I building today?** (specific task, 1-3 things max)
3. **What's blocking me?** (technical debt, unclear spec, bug)

Keep a simple log (notes or git commits) so you can track progress.

---

## Decision Log

Use this to record important decisions you make:

- **Design choice**: Why? (e.g., "Used emoji icons instead of custom SVG for faster iteration")
- **Architecture**: Why? (e.g., "Chose Riverpod instead of BLoC for simplicity")
- **Scope cut**: Why? (e.g., "Deferred dark mode to v2.1 to launch faster")

---

## What Success Looks Like

At the end of week 12:

1. ✅ User can sign up and log in
2. ✅ User can join/create a club
3. ✅ User can select roles and see the right home screen
4. ✅ Player can see schedule and RSVP
5. ✅ Coach can manage roster and create events
6. ✅ Parent can see kids' schedules and RSVP
7. ✅ App is fast, responsive, and handles errors gracefully
8. ✅ Notifications work (if time permits)
9. ✅ Design is polished (colors, spacing, typography match)
10. ✅ Ready to invite first real clubs to test

---

## Flexibility

This roadmap is a guide, not a prison. If you discover:
- A feature takes much longer than estimated → cut scope, move to v2.1
- A feature is easier than expected → add another one
- A architecture decision doesn't work → pivot (you have time)

Ship MVP at week 10-12, not earlier. Quality > speed.

---

## Next Step

**This week:**
1. Review this roadmap
2. Adjust estimates based on your experience
3. Clone/fork the Flutter template if you have one
4. Start Week 1, Day 1: Project setup

You've got this. 🚀
