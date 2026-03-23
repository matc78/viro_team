# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ViroTeam is a Flutter sports team management app supporting multiple roles (player, coach, admin) across multiple clubs. The app uses Firebase as its backend (Firestore, Auth, Storage, FCM, Crashlytics) and is deployed to Android, iOS, and Web. The UI and all strings are in **French**.

Firebase Project ID: `viroteam-75303`

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug)
flutter run

# Analyze code
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Run a single test file
flutter test test/my_test.dart

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions
```

Cloud Functions are in `functions/` (Node.js 20). Run `npm install` inside that directory before deploying.

## Architecture

### State Management

`UserSession` (`lib/services/user_session.dart`) is the central state provider (via the `provider` package). It holds the currently authenticated user, their active role/club context, and exposes methods like `loadUser()`, `watchUser()`, `switchProfile()`, and `logout()`. It is injected at the app root in `main.dart`.

### Data Model

The key concept is **multi-role, multi-club membership**:

- A user (`users/{uid}`) has `roles` (player, coach, admin) across different clubs and an `activeContext: { role, clubId }` that determines which view they see.
- Club membership details are stored in `clubs/{clubId}/members/{uid}` (the `ClubMembership` model).
- Team, event, join request, and announcement data are subcollections under `clubs/{clubId}/`.

### Navigation & Pages

Pages are split into two domains:
- `lib/pages/player_pages/` — views for players and coaches in member mode
- `lib/pages/admin_coach_pages/` — views for admins and coaches managing a club

Navigation uses `MaterialPageRoute` directly (despite `go_router` being a dependency). The app starts at `SplashPage` → `AuthPage` → role-specific home page based on `UserSession.currentRole`.

### Services

Business logic lives in `lib/services/`. Each service interacts with Firestore directly. Key services:

| Service | Responsibility |
|---|---|
| `UserService` | Read/write user documents |
| `MembershipService` | Club membership lifecycle |
| `EventService` | Events, attendance |
| `JoinRequestService` | Join request workflow |
| `NotificationService` | FCM token management |
| `InviteApplyService` | Invite link processing |

Firestore collection name constants are in `lib/constants/firebase_collections.dart`.

### Cloud Functions

`functions/index.js` handles server-side logic including avatar moderation (Google Cloud Vision API), and notification triggers on Firestore writes.

### Firestore Databases

Two databases are configured: `test` and `prod`. The active database is configured via `lib/utils/firestore_instance.dart`.

## Key Technical Notes

- **Streams**: Real-time updates use `StreamBuilder` throughout. Be careful to dispose stream subscriptions properly in `StatefulWidget.dispose()`.
- **N+1 queries**: Known issue — ListViews sometimes trigger individual Firestore fetches per item. Prefer batching with `whereIn` or denormalizing data.
- **Client-side filtering**: Some queries fetch broad data and filter in Dart. Prefer Firestore `where` clauses and composite indexes (see `firestore.indexes.json`).
- **Audio**: `lib/utils/buzzer_sound.dart` — whistle (`son_sifflet.mp3`) and buzzer (`son_buzzer.mp3`) assets.
- **Avatar moderation**: Upload triggers a Cloud Function; moderation state is tracked in `users/{uid}/avatar_moderation/state`.
- **Migrations**: One-shot data migration utilities in `lib/utils/migration_*.dart` (run in debug mode only).
