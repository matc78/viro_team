# ViroTeam v2: Final Design System

## Design Tokens

### Color Palette

**Primary (Deep Blue - Trust, tech, calm)**
- `primary-50`: #E6F1FB (lightest, for backgrounds)
- `primary-100`: #B5D4F4 (light, hover states)
- `primary-200`: #85B7EB (medium-light)
- `primary-400`: #378ADD (main, interactive)
- `primary-600`: #185FA5 (darker, hover on buttons)
- `primary-800`: #0C447C (darkest, text on light backgrounds)
- `primary-900`: #042C53 (absolute darkest)

**Semantic Colors**
- Success: #10B981 (green, for attendance yes/confirmed)
- Warning: #F59E0B (amber, for pending/maybe)
- Error: #EF4444 (red, for absence/denied)
- Neutral: #6B7280 (gray, for secondary text, disabled states)

**Neutral Palette**
- White: #FFFFFF (backgrounds)
- Gray-50: #F9FAFB (subtle backgrounds)
- Gray-100: #F3F4F6 (secondary backgrounds)
- Gray-200: #E5E7EB (borders, dividers)
- Gray-300: #D1D5DB (stronger borders)
- Gray-400: #9CA3AF (secondary text)
- Gray-600: #4B5563 (body text)
- Gray-900: #111827 (darkest text)

**Usage:**
- Buttons, links, badges: Primary color
- Success states (confirmed RSVP): Green
- Pending states (maybe RSVP): Amber
- Error states (absent): Red
- Text: Gray-600 (body), Gray-400 (secondary), Gray-900 (headings)
- Backgrounds: White or Gray-50 for surfaces, Gray-100 for card backgrounds

---

### Typography

**Font Family**: Inter (or Roboto as fallback)
- Clean, professional, highly readable on mobile
- Open source friendly, web safe

**Scale & Weights**

| Use | Size | Weight | Line Height | Example |
|-----|------|--------|-------------|---------|
| H1 (Screen titles) | 32px | 600 | 1.2 | "Votre planning" |
| H2 (Section headers) | 24px | 600 | 1.2 | "Prochains matchs" |
| H3 (Sub-headers) | 18px | 600 | 1.3 | "Samedi 15 mars" |
| Body (Main text) | 16px | 400 | 1.5 | Event descriptions |
| Small (Secondary) | 14px | 400 | 1.5 | Labels, timestamps |
| Tiny (Captions) | 12px | 400 | 1.4 | Hints, meta info |

**Colors:**
- Primary text (headings, body): Gray-900
- Secondary text (labels, hints): Gray-600
- Tertiary text (disabled, placeholders): Gray-400

---

### Spacing & Layout

**Base Unit**: 8px (standard mobile grid)

**Spacing Scale**
- xs: 4px (tight internal spacing, between inline elements)
- sm: 8px (between elements, component padding)
- md: 16px (standard, between sections)
- lg: 24px (spacious, between major blocks)
- xl: 32px (very spacious, rare)

**Safe Area (Mobile)**
- Screen padding: 16px horizontal, 12px vertical
- Content width: ~343px (375px phone - 32px padding)
- Touch targets: minimum 44px height
- Icon size: 20-24px inline, 28-32px standalone

**Grid**
- 12-column responsive grid
- Breakpoints: 375px (mobile default), 768px (tablet), 1024px (desktop)
- Mobile-first: design for 375px, scale up

---

### Components

#### Button

**Sizes:**
- Large (primary CTA): 48px height, 16px padding horizontal
- Medium (secondary): 44px height, 14px padding horizontal
- Small (tertiary): 36px height, 12px padding horizontal

**States:**

*Primary (Main action)*
- Default: Background Primary-400, white text, rounded 8px
- Hover: Background Primary-600, white text
- Pressed: Background Primary-800, white text, slightly inset
- Disabled: Background Gray-200, Gray-400 text

*Secondary (Alternative action)*
- Default: Border 2px Primary-400, Primary-400 text, no background
- Hover: Background Primary-50, Primary-600 text
- Pressed: Background Primary-100, Primary-800 text
- Disabled: Border 2px Gray-300, Gray-400 text

*Tertiary (Low priority)*
- Default: Text only, Primary-400 text
- Hover: Underline
- Pressed: Darker text
- Disabled: Gray-400 text

**Icon buttons**: 40x40px minimum, centered icon

---

#### Input Field

**Height**: 44px
**Padding**: 12px (vertical), 16px (horizontal)
**Border**: 1px solid Gray-300
**Border radius**: 8px
**Focus**: 2px solid Primary-400, light Primary-50 background
**Error**: 1px solid Error, Error text below
**Placeholder**: Gray-400 italic

**Label** (above field):
- Font: 14px, 500, Gray-600
- Margin bottom: 8px

**Helper text** (below field):
- Font: 12px, 400, Gray-500
- Margin top: 4px

---

#### Card

**Container:**
- Background: White
- Border: 1px solid Gray-200
- Border radius: 12px
- Padding: 16px
- Shadow: 0 1px 2px rgba(0,0,0,0.05) (very subtle)

**Hover state:**
- Border: 1px solid Gray-300
- Shadow: 0 4px 6px rgba(0,0,0,0.07)
- Transition: 200ms ease

---

#### Badge / Role Indicator

**Role badges** (sport-focused emojis + text):

*Player*
- Icon: ⚽ (or custom silhouette of player)
- Background: Primary-50
- Text: Primary-800
- Border: 1px Primary-200
- Font: 12px, 500

*Coach*
- Icon: 🏛️ (or custom clipboard/whistle icon)
- Background: Amber-50
- Text: Amber-900
- Border: 1px Amber-200
- Font: 12px, 500

*Parent*
- Icon: 👨‍👩‍👧 (or custom family icon)
- Background: Green-50
- Text: Green-900
- Border: 1px Green-200
- Font: 12px, 500

*Admin*
- Icon: ⚙️ (or custom settings icon)
- Background: Gray-100
- Text: Gray-900
- Border: 1px Gray-300
- Font: 12px, 500

**Sizes:**
- Large (switcher): 40px height, 12px padding
- Medium (list item): 32px height, 10px padding
- Small (inline): 24px height, 8px padding

---

#### Top Bar / Header

**Height**: 56px
**Background**: Primary-50 (very light, subtle)
**Border bottom**: 1px solid Gray-200
**Padding**: 12px horizontal, 8px vertical
**Sticky**: yes, always visible

**Structure (left to right):**
1. Club selector (left, 120px)
2. Title or spacer (center)
3. Current role badge (right, 40px)
4. Settings menu (right, 40px)

**Interaction:**
- Club selector: tap to show dropdown with all clubs
- Role badge: tap to show role picker
- Settings: tap to show menu (preferences, logout)

---

#### Bottom Navigation (if used)

**Height**: 60px
**Background**: White
**Border top**: 1px solid Gray-200
**Icons**: 24px, Primary-400 when active, Gray-400 when inactive
**Labels**: 12px, always visible below icon

**Tabs:**
- Home (primary home screen for role)
- Schedule (all events)
- Team (roster if coach, team info if player)
- Account (profile, settings)

---

### Layout Patterns

#### Event Card (large, for schedule)

```
┌─────────────────────────────────────┐
│ Samedi 15 mars              15:00   │  ← Date/time (small, gray)
│                                     │
│ ⚽ Match - U15 Séniors              │  ← Type icon + title (18px, bold)
│ Stade Municipal                     │  ← Location (14px, gray)
│                                     │
│ [Oui] [Peut-être] [Non]             │  ← RSVP buttons (if player)
│                                     │
│ ou                                  │
│                                     │
│ 12/15 confirmés  ▶                  │  ← Attendance (if coach)
│                                     │
└─────────────────────────────────────┘
```

**Structure:**
- Card container (16px padding)
- Header row: date | time
- Content: icon + title (H3)
- Subtitle: location or team
- Footer: RSVP buttons (player) OR attendance + drilldown (coach)

**Spacing:** 12px between rows

---

#### Stats Mini Card

```
┌──────────────────┐
│ Matchs: 12       │  ← Stat label
│ 10 titulaire     │  ← Stat value (14px, secondary)
└──────────────────┘

┌──────────────────┐
│ Buts: 3          │
└──────────────────┘

etc.
```

**Structure:**
- Gray-50 background
- 12px padding
- 12px border radius
- 14px text, Gray-600 label
- 16px text, Primary-800 value

---

#### Roster List Item

```
┌──────────────────────────────────────┐
│ 👤 Marie Dupont           #7         │  ← Avatar | Name | Number
│ Attaquant • Présente                 │  ← Position | Status
│                                      │
│ (edit icon →)                        │  ← Coach only: edit
└──────────────────────────────────────┘
```

**Structure:**
- 44px height minimum
- Avatar (32px circle) | Name (bold) | Number (right-aligned, small)
- Position + Status (14px gray, below name)
- Edit icon (right, for coaches only)

---

## The Three Home Screens (Detailed)

### Screen 1: Player Home

**URL**: `/app/player/home` or just `/app` when role=player

**Top Bar:**
- Left: Club selector (ASM ▼)
- Right: ⚽ badge | ⚙️ settings

**Body (scroll):**

**Section 1: Greeting (16px padding)**
```
Bienvenue, Marie
Vous êtes joueur à l'ASM
```
- H3 greeting, Gray-900
- Small subtitle, Gray-600
- Margin bottom: 24px

**Section 2: Next Event Card (16px padding)**
```
Samedi 15 mars                    15:00
⚽ Match - U15 Séniors
Stade Municipal

[Oui ✓] [Peut-être] [Non]
```
- Card (16px padding)
- RSVP buttons: Primary for "Yes" (with checkmark), Secondary for "Maybe", Secondary for "No"
- Margin bottom: 16px

**Section 3: Upcoming Events List (16px padding)**

Header: "PROCHAINS ÉVÉNEMENTS" (12px, uppercase, Gray-600)

Repeat Event Card for each event (next 5):
- Same as Section 2
- Margin bottom: 12px between cards

**Section 4: Quick Stats (16px padding)**

Header: "VOS STATS" (12px, uppercase, Gray-600)

Four mini cards in 2x2 grid:
```
┌──────────────┬──────────────┐
│ Matchs: 12   │ Buts: 3      │
│ 10 titulaire │              │
├──────────────┼──────────────┤
│ Assists: 1   │ Présence:    │
│              │ 92%          │
└──────────────┴──────────────┘
```
- Each 12px gap between cards
- Margin bottom: 24px

**Section 5: Role Switcher (16px padding)**

Header: "VOS AUTRES RÔLES" (12px, uppercase, Gray-600)

Buttons (full width, stacked):
```
[🏛️ En tant qu'entraîneur]
[👨‍👩‍👧 En tant que parent]
```
- Secondary button style
- 44px height
- Full width - 32px padding
- 8px gap between buttons
- Margin bottom: 24px (safe area for scrolling)

---

### Screen 2: Coach Home

**URL**: `/app/coach/home` or just `/app` when role=coach

**Top Bar:**
- Left: Club selector (ASM ▼)
- Right: 🏛️ badge | ⚙️ settings

**Body (scroll):**

**Section 1: Role Context (16px padding)**
```
Entraîneur - Équipe U15
15 joueurs inscrits
```
- H3 role, Gray-900
- Small subtitle, Gray-600
- Margin bottom: 24px

**Section 2: Primary CTA (16px padding)**
```
[+ CRÉER UN ÉVÉNEMENT]
```
- Primary button
- Full width - 32px padding
- 48px height
- Margin bottom: 16px

**Section 3: My Events (16px padding)**

Header: "MES ÉVÉNEMENTS (3)" (12px, uppercase, Gray-600)

Repeat Event Card for each event:
```
Samedi 15 mars              15:00
⚽ Match - U15 Séniors
12/15 confirmés  [Voir détails →]
```
- Card (16px padding)
- Last line: attendance count + right-arrow link
- Margin bottom: 12px between cards

**Section 4: Roster (16px padding)**

Header: "EFFECTIF (15)" (12px, uppercase, Gray-600)

**Titulaires (11)** subheader
Repeat Roster Item for each starting player:
```
👤 Marie Dupont           #7
Attaquant • Présente
```
- Margin bottom: 8px between items

**Remplaçants (4)** subheader
Repeat Roster Item for each sub:
```
👤 Jean Moreau            
Défenseur • Absent
```

**Section 5: Role Switcher (16px padding)**

Header: "VOS AUTRES RÔLES" (12px, uppercase, Gray-600)

Buttons (full width, stacked):
```
[⚽ En tant que joueur]
[👨‍👩‍👧 En tant que parent]
```
- Secondary button style
- 44px height
- Full width - 32px padding
- 8px gap between buttons
- Margin bottom: 24px (safe area)

---

### Screen 3: Parent Home

**URL**: `/app/parent/home` or just `/app` when role=parent

**Top Bar:**
- Left: Club selector (ASM ▼)
- Right: 👨‍👩‍👧 badge | ⚙️ settings

**Body (scroll):**

**Section 1: Context (16px padding)**
```
Calendrier des enfants
2 enfants inscrits
```
- H3 context, Gray-900
- Small subtitle, Gray-600
- Margin bottom: 24px

**Section 2: Child 1 Events (16px padding)**

Header: "SARAH (U13 Filles)" (14px, 600, Primary-800)
- Margin bottom: 12px

Repeat Event Card for Sarah:
```
Samedi 15 mars              14:00
⚽ Match - U13 Filles
Stade Municipal

[Oui ✓] [Peut-être] [Non]
```
- Quick RSVP (no drilldown needed)
- Margin bottom: 12px between cards

**Section 3: Child 2 Events (16px padding)**

Header: "LUCAS (U15 Garçons)" (14px, 600, Primary-800)
- Margin bottom: 12px

Repeat Event Card for Lucas:
```
Same format as Sarah
```

**Section 4: Quick Team Info (16px padding)**

Header: "VIS-À-VIS" (12px, uppercase, Gray-600)

Card with team info:
```
Équipe: U13 Filles
Coach: Marie Dupont

Classement: 2ème/8
Prochain match: Samedi 15:00
```
- Gray-100 background
- 14px text
- 16px padding
- Margin bottom: 24px

**Section 5: Role Switcher (16px padding)**

Header: "VOS AUTRES RÔLES" (12px, uppercase, Gray-600)

Buttons:
```
[⚽ En tant que joueur]
[🏛️ En tant qu'entraîneur]
```
- Secondary button style
- 44px height
- Full width - 32px padding
- 8px gap between buttons
- Margin bottom: 24px (safe area)

---

## The Switcher UX (Interaction Flows)

### Club Selector (Top left)

**Default (closed):**
```
[ASM ▼]
```
- Background: Gray-50
- Border: 1px Gray-200
- Padding: 8px 12px
- Border radius: 8px
- Font: 14px, 600, Primary-800

**Tap to open:**
```
┌──────────────────────────────┐
│ Mes clubs                    │  ← 12px gray, uppercase
├──────────────────────────────┤
│                              │
│ ✓ ASM (👥 🏛️ 👨‍👩‍👧)          │  ← Current (primary-50 bg)
│                              │
│ Aviron (👥)                  │  ← Other (tap to switch)
│                              │
│ [+ Ajouter un club]          │  ← Join new club
│                              │
└──────────────────────────────┘
```
- Dropdown width: match button width, min 180px
- Appears below button (positioned)
- Padding: 12px
- Each item: 44px height, tap area

**Behavior:**
- Tap current club: close dropdown
- Tap other club: switch club, close dropdown, reload body with new club's data
- Tap "+ Ajouter": navigate to join/create club screen
- Escape key: close dropdown

---

### Role Picker (On badge or when role == null)

**Tap role badge:**
```
┌──────────────────────────────┐
│ Vos rôles à l'ASM            │  ← 12px gray, uppercase
├──────────────────────────────┤
│                              │
│ ✓ ⚽ En tant que joueur      │  ← Current (primary-400 bg)
│                              │
│ 🏛️ En tant qu'entraîneur    │  ← Alternative (tap to switch)
│                              │
│ 👨‍👩‍👧 En tant que parent     │  ← Alternative (tap to switch)
│                              │
│ [Fermer]                     │  ← Secondary button
│                              │
└──────────────────────────────┘
```
- Dropdown width: ~200px
- Positioned: right-aligned from badge
- Padding: 12px
- Each role: 44px height, tap area
- Checkmark next to current role

**Behavior:**
- Tap role: switch role, close dropdown, rebuild body (instant, ~200ms)
- Tap [Fermer]: close dropdown
- Escape key: close dropdown
- No page reload, just setState

---

## Icons (Sport-focused)

**Role icons:**
- Player: ⚽ (ball) or custom player silhouette
- Coach: 🏛️ (building) or custom whistle/clipboard
- Parent: 👨‍👩‍👧 (family) or custom family icon
- Admin: ⚙️ (settings) or custom gear

**Action icons:**
- Add: ➕ (plus)
- Edit: ✏️ (pencil)
- Delete: 🗑️ (trash)
- Forward: ➡️ (arrow right)
- Back: ⬅️ (arrow left)
- Menu: ☰ (hamburger)
- Settings: ⚙️ (gear)
- Search: 🔍 (magnifying glass)

**Event icons:**
- Training: 🏃 (runner)
- Match: ⚽ (ball)
- Tournament: 🏆 (trophy)
- Other: 📅 (calendar)

**Status icons:**
- Confirmed: ✅ (checkmark)
- Pending: ❓ (question mark)
- Absent: ❌ (cross)
- Injured: 🏥 (hospital)

**All icons are emoji for simplicity and platform consistency.**

---

## Animation & Transitions

**Duration**: 200ms standard, 300ms for modals

**Easing**: `ease-out` for entrances, `ease-in-out` for state changes

**What animates:**
- Hover state transitions (buttons, cards)
- Color changes (role switch)
- Opacity (fade in/out for modals)
- Transform (slight scale on button press)

**What doesn't animate:**
- Screen transitions (instant, no slide)
- Loading states (show spinner, but app should be fast enough to avoid this)
- Scrolling (native, not custom)

---

## Dark Mode (Future)

Currently: Light mode only.

When dark mode is added:
1. Invert backgrounds (White → Gray-900, Gray-50 → Gray-800, etc.)
2. Invert text colors (Gray-900 → White, Gray-600 → Gray-300)
3. Primary color lightens (Primary-400 → Primary-300)
4. Borders become slightly lighter (Gray-200 → Gray-700)

All components are designed to adapt cleanly when dark mode is enabled.

---

## Responsive Breakpoints

**Mobile (375px - default):**
- Full-width buttons, stacked layout
- 16px side padding
- Single-column for most content

**Tablet (768px - future, if web/desktop support):**
- 2-column layout for stats
- Sidebar for navigation
- Side-by-side children calendars (parent view)

**Desktop (1024px+ - future):**
- 3-column layout
- Persistent sidebar
- Full dashboard mode

---

## Accessibility

**Color contrast:**
- All text meets WCAG AA (4.5:1 minimum)
- Avoid color-only indicators (pair with icons or text)

**Touch targets:**
- Minimum 44x44px for interactive elements
- 8px padding around buttons on mobile

**Text:**
- Max line length: 60 characters on mobile, 80 on desktop
- Line height: 1.5 for body text
- Avoid small text (<14px) for body content

**Images & icons:**
- All icons have alt text (via aria-label if emoji)
- Avoid relying on color alone for state

**Forms:**
- Labels always visible (not placeholder-only)
- Error messages clear and helpful
- Focus indicators visible (2px border)

---

## Design File (Figma)

When Figma file is created, it should include:

1. **Tokens page:** All colors, typography, spacing values
2. **Components page:** Buttons, cards, inputs, badges (with variants)
3. **Patterns page:** Event card, roster item, stats card layouts
4. **Three Home Screens:** Player, Coach, Parent (at 375px mobile)
5. **Switcher/Role Picker:** Interactive prototypes
6. **Icon set:** All 20+ icons used
7. **Annotations:** For developers (padding, spacing, font sizes)

---

## Implementation Checklist

- [ ] Import Inter font (Google Fonts or local)
- [ ] Set up Tailwind config with custom colors
- [ ] Create Button component (3 sizes × 3 variants × 4 states)
- [ ] Create Card component (with optional padding/border options)
- [ ] Create Input component (with label, error, focus states)
- [ ] Create Badge component (4 role types)
- [ ] Create responsive layout grid (12-column, mobile-first)
- [ ] Create TopBar component (club selector, role badge, settings)
- [ ] Create RolePickerPopover component
- [ ] Create ClubSelectorDropdown component
- [ ] Create EventCard component (reusable for all screens)
- [ ] Create RosterItem component (with edit button for coaches)
- [ ] Create StatsMiniCard component
- [ ] Build PlayerHome screen
- [ ] Build CoachHome screen
- [ ] Build ParentHome screen
- [ ] Test on iPhone SE (375px) and iPad (768px)
- [ ] Verify all touch targets are 44px+
- [ ] Verify color contrast (WCAG AA)

---

## Notes for Developer

1. **Mobile-first:** All layouts start at 375px. Don't assume larger screens.
2. **No dark mode yet:** Light only. Use CSS variables for future dark mode support.
3. **Sporty, not corporate:** Icons are emoji (⚽🏛️👨‍👩‍👧), not minimalist. Embrace the sport.
4. **Speed matters:** Instant role switching = no spinners. Keep state management tight.
5. **French first:** All text in French. No i18n needed yet.
6. **Provider/Riverpod:** Use for state management. SessionContext at top level.
7. **No deep nesting:** Flat component hierarchy, easy to debug.

---

## What's Next After Design System

1. **Onboarding screen** (create/join club, role selection)
2. **Login/auth flow** (Firebase integration)
3. **Club selector flow** (first time setup)
4. **Role picker flow** (interactable, real logic)
5. **Build PlayerHome** (fetch real events, RSVP logic)
6. **Build CoachHome** (fetch roster, create event logic)
7. **Build ParentHome** (fetch children's events)
8. **Notifications** (FCM integration, local notifications)
9. **Polish & test** (accessibility, performance, edge cases)
10. **Launch** 🚀
