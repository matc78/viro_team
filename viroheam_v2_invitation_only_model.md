# ViroTeam v2: Invitation-Only Onboarding

## The Change

**Old model**: 
- Anyone signs up → joins club with code → picks role
- Problem: Spam, unvetted members, cluttered rosters

**New model**:
- Only admin/coach can invite players
- Players sign up with app, get invited, accept/decline
- Much cleaner, controlled roster

---

## New Flow

### Phase 1: Club Admin/Coach (Already in club)

**Admin creates an invitation code** (or generates one per invite):

```
Admin opens ViroTeam
  ↓
Goes to: [Club settings] or [Team roster] → [+ Invite player]
  ↓
Sees: "Invite by email" or "Generate code"
  ↓
Option A: Types email (player@example.com)
  → System sends invite link via email
  → "Check your email for the link"
  
Option B: Generates code (e.g., "ASMP1K2E")
  → Code shows on screen + QR code option
  → "Share this code with your player"
  
OR: Get shareable link (e.g., viroheam.app/join/ASMP1K2E)
```

**Behind the scenes**:
- Create in Firestore: `clubs/{clubId}/invitations/{inviteId}`
  ```
  {
    email: "player@example.com",
    code: "ASMP1K2E",
    sentBy: "admin_uid",
    sentAt: timestamp,
    role: "player", // what role they're invited as
    status: "pending" | "accepted" | "declined" | "expired",
    expiresAt: timestamp + 7 days,
    acceptedAt: timestamp (null until accepted)
  }
  ```
- Firestore rule: Only admin/coach can create invitations

---

### Phase 2: Player (Not yet in ViroTeam)

**Case A: Player receives email invite**

```
Player gets email:
  Subject: "You're invited to join ASM on ViroTeam"
  Body: "Coach Marie invited you to play for ASM U15"
  
  [ACCEPT INVITE] button (link)
  ↓
Opens app (or web) at: /join?code=ASMP1K2E&email=player@example.com
```

**Case B: Player gets shared code**

```
Player opens ViroTeam app
  ↓
At login/signup screen, sees:
  "Already have an invite code?"
  [Join with code] link
  ↓
Types/pastes: ASMP1K2E
  ↓
"You've been invited to join ASM!"
  Shows: Team name, coach, what role
  [ACCEPT] [DECLINE]
```

---

### Phase 3: New Player Signup (First Time)

**Player taps [ACCEPT INVITE]**:

```
1. Check if player already has account
   ├─ YES → Show login screen, then show acceptance
   └─ NO → Show signup screen first

2. If signup needed:
   ┌────────────────────────────────┐
   │ Créer mon compte               │
   │ (You're being invited by Marie)│
   │                                │
   │ [Name]                         │
   │ [Email] (pre-filled)           │
   │ [Password]                     │
   │ [Confirm password]             │
   │                                │
   │ [CRÉER ACCOUNT]                │
   └────────────────────────────────┘

3. After signup:
   ┌────────────────────────────────┐
   │ Confirmer l'invitation         │
   │                                │
   │ ✓ You're invited to ASM        │
   │   Role: Joueur (U15 Séniors)   │
   │   Coach: Marie Dupont          │
   │                                │
   │ [ACCEPTER]  [DÉCLINER]         │
   └────────────────────────────────┘

4. If accept:
   → Update: invitations/{inviteId}.status = "accepted"
   → Create: users/{uid}/memberships/{clubId}
               {roles: ["player"], playerInfo: {...}}
   → Auto-login
   → Navigate to: RolePickerScreen (player auto-selected)
   → Show: PlayerHome for ASM

5. If decline:
   → Update: invitations/{inviteId}.status = "declined"
   → Go to: ClubSelectorScreen (no clubs yet, can request or wait)
```

---

## Updated Firestore Schema

### Invitations Collection

```
clubs/{clubId}/invitations/{inviteId}
├─ email: string (who to invite)
├─ code: string (shareable code, e.g., "ASMP1K2E")
├─ role: string (player, coach, admin - what role they're invited as)
├─ status: enum ("pending", "accepted", "declined", "expired")
├─ createdBy: string (uid of admin/coach who sent invite)
├─ createdAt: timestamp
├─ expiresAt: timestamp (typically +7 days)
├─ acceptedAt: timestamp (null until accepted)
├─ acceptedBy: string (null until accepted)
│
└─ Optional fields:
   ├─ teamId: string (if invited to specific team, not club-wide)
   ├─ season: string (2024-2025, etc.)
   ├─ message: string (custom message from coach)
```

### Firestore Rules

```javascript
// Create invitation: Only admin or coach of the club
match /clubs/{clubId}/invitations/{inviteId} {
  allow create: if isClubAdmin(clubId, request.auth.uid)
               || isTeamCoach(clubId, request.auth.uid);
  
  allow read: if isClubAdmin(clubId, request.auth.uid)
            || request.auth.token.email == resource.data.email;
  
  allow update: if isClubAdmin(clubId, request.auth.uid);
  allow delete: if isClubAdmin(clubId, request.auth.uid);
}

// Accept invitation: The invited person (via email match)
match /users/{uid}/... {
  // When accepting, update invitation status
  // Handled via Cloud Function (see below)
}
```

### Cloud Function: Accept Invitation

When a user accepts an invite, trigger a Cloud Function to:

```javascript
// acceptInvitation(uid, inviteCode)
// 1. Verify invitation exists and matches email
// 2. Check not expired
// 3. Create membership
// 4. Update invitation status
// 5. Send confirmation email to admin

exports.acceptInvitation = functions.https.onCall(async (data, context) => {
  const { uid, inviteCode } = data;
  const userEmail = context.auth.token.email;
  
  // Find invitation by code + email
  const inviteSnap = await db.collectionGroup('invitations')
    .where('code', '==', inviteCode)
    .where('email', '==', userEmail)
    .limit(1)
    .get();
  
  if (inviteSnap.empty) throw new Error('Invitation not found');
  
  const invite = inviteSnap.docs[0];
  if (invite.data().status !== 'pending') throw new Error('Already processed');
  if (new Date() > invite.data().expiresAt.toDate()) throw new Error('Expired');
  
  const { clubId } = invite.ref.parent.parent.id;
  
  // Create membership
  await db.doc(`users/${uid}/memberships/${clubId}`).set({
    roles: [invite.data().role],
    joinedAt: FieldValue.serverTimestamp(),
    playerInfo: invite.data().role === 'player' ? { status: 'active' } : null,
    // ... etc
  });
  
  // Update invitation
  await invite.ref.update({
    status: 'accepted',
    acceptedAt: FieldValue.serverTimestamp(),
    acceptedBy: uid
  });
  
  // Send confirmation email to admin
  await sendEmail({
    to: invite.data().createdBy,
    subject: `${userEmail} accepted your invite to ${clubName}`
  });
});
```

---

## Updated UX Flow

### For Admin/Coach (Existing)

**New screen**: "Invite players" (or tab in Team roster screen)

```
┌────────────────────────────────┐
│ Inviter des joueurs            │  ← H2
│                                │
│ [Invite by email] [Invite list]│  ← Tabs or buttons
│                                │
│ INVITE BY EMAIL                │
│ [Email input: user@ex.com]    │  ← Email of new player
│ [Role selector: Player]        │  ← What role
│ [ENVOYER INVITE]               │  ← Send button
│                                │
│ PENDING INVITES                │  ← List of sent invites
│ ✓ marie@example.com (accepted) │  ← Status shows
│ ⏳ jean@example.com (pending)   │
│ ✗ luc@example.com (declined)   │
│ 🕐 sophie@example.com (expired)│
│                                │
│ [REVOKE] [RESEND] buttons      │  ← Actions per invite
│                                │
└────────────────────────────────┘
```

**Interactions**:
1. Type email → Auto-check if user exists in ViroTeam
   - If exists: "User already in app, invite as [role]"
   - If new: "New user, they'll sign up when they accept"

2. Tap [ENVOYER INVITE]
   - Generate code (e.g., "ASMP1K2E")
   - Send email with link
   - OR: Show code + copy button + QR code
   - Add to pending list

3. Tap [RESEND] → Re-send email to pending invite
4. Tap [REVOKE] → Delete invite (can't be accepted anymore)

---

### For New Player (First Time)

**Simpler path** (no self-signup discovery):

```
Player receives invite → taps link → Opens app
  ↓
If not logged in:
  Show signup screen (pre-filled with email from invite)
  ↓
If logged in:
  Show "Accept invite" confirmation screen
  ↓
Tap [ACCEPTER]
  ↓
Auto-join club with invited role
  ↓
See: RolePickerScreen (role pre-selected, can confirm or back)
  ↓
See: Home screen (PlayerHome if player, CoachHome if coach, etc.)
```

**Key**: No "join with code" visible to random people. Code only works if it matches the email the coach invited.

---

### For Existing Player Joining New Club

**Already has account, gets invited to another club**:

```
Player receives invite → taps link
  ↓
Sees: "You're invited to join Aviron"
      Role: Coach
      Coach: Jean Martin
  ↓
[ACCEPTER] [DÉCLINER]
  ↓
If accept:
  → Add to users/{uid}/memberships/{aviron_id}
  → Auto-navigate to: ClubSelectorScreen (now shows both ASM + Aviron)
  → Can pick which club's home to view
```

---

## What Doesn't Change

✅ **Top bar**: Club selector + role switcher still works same way
✅ **Home screens**: Same (PlayerHome, CoachHome, ParentHome)
✅ **Role switching**: Still instant (setState)
✅ **Club switching**: Still works
✅ **Notifications**: On invite, on accept, etc.

---

## Firestore Permissions Summary

| Action | Who can do it | Condition |
|--------|-------------|-----------|
| Create invitation | Admin, coach | Must be member of club |
| Accept invitation | The invited person | Code + email match, not expired |
| Decline invitation | The invited person | Code + email match |
| List invitations (sent) | Admin of club | Only for this club |
| List invitations (received) | The invited person | For their email |
| Revoke invitation | Admin of club | Only not-yet-accepted |

---

## New Player Email Template

Subject: "You're invited to play for **ASM** on ViroTeam"

Body:
```
Hi Maria,

Coach Marie Dupont has invited you to join **ASM** as a **Joueur** (Player).

Team: U15 Séniors
League: Île-de-France Youth Football

To accept or decline, tap the button below:

[ACCEPT INVITE] ← This links to:
viroheam.app/join?code=ASMP1K2E&email=maria@example.com

If you don't have a ViroTeam account, you'll be prompted to create one.

Questions? Reply to this email or contact Coach Marie directly.

---
ViroTeam: One app, all your roles.
```

---

## Edge Cases Handled

1. **Email typo by coach** → Invite sent to wrong person
   - Solution: [REVOKE] button, coach sends new invite to correct email

2. **Player gets invite, doesn't sign up** → Invite expires after 7 days
   - Coach can [RESEND] to remind them

3. **Player already in club, coach invites again** → 
   - System checks: "User already in ASM as player, they can't be invited again"
   - Coach sees message: "This person is already a member"

4. **Coach creates multiple invite codes for same player** →
   - Both are valid, either one can be used
   - Once first is accepted, second becomes "duplicate" (revoke if needed)

5. **Player has multiple roles at same club** →
   - Coach invites as "coach", player is already "player"
   - On acceptance: Firestore adds "coach" to existing roles array
   - User now has ["player", "coach"] at this club

---

## Implementation Checklist

- [ ] Create `invitations` collection in Firestore
- [ ] Build Cloud Function: `acceptInvitation`
- [ ] Build invite screen (coach side): email input, pending list
- [ ] Build accept screen (player side): confirmation with club/role/coach info
- [ ] Update signup flow: pre-fill email from invite link
- [ ] Build email template + send via Firebase Cloud Messaging or SendGrid
- [ ] Test: Coach invites → player signs up → joins club
- [ ] Test: Coach invites → existing player accepts → roles merge
- [ ] Test: Invite expires, coach resends
- [ ] Test: Player declines, can still sign up later
- [ ] Add Firestore rules for invitations

---

## Summary: Invitation-Only Benefits

✅ **Controlled rosters** — Only verified players join
✅ **No spam** — Can't randomly sign up and request
✅ **Better onboarding** — Player knows they're invited, by whom
✅ **Clear intent** — Admin/coach commits to wanting this person
✅ **Simpler UX** — No "request pending" states, no rejections
✅ **Cleaner email** — Invite email is personal, from coach

This is the model used by:
- Slack (invite to workspace)
- GitHub (invite to org)
- Sports management apps (invitation only for teams)

You're moving from "open signup" to "closed club" model. Much better for your use case. 👍
