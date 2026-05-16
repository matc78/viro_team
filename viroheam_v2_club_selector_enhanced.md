# ViroTeam v2: Enhanced Club Selector Screen

## Current State Analysis

Your current screen is minimal:
```
┌────────────────────────────────┐
│ Mes clubs                      │
├────────────────────────────────┤
│ Choisissez le club à consulter │
│                                │
│ [Club 1]                       │  ← Just name + icon
│ [Club 2]                       │
│                                │
│ [Ajouter/rejoindre un club]    │
│                                │
└────────────────────────────────┘
```

**Issues**:
1. Empty state is uninviting
2. No indication of what roles user has at each club
3. No pending invitations visible
4. Limited context about clubs (team count, last event, etc.)
5. Single primary action (add club) — could be more guided

---

## Enhanced Design

### State 1: Multiple Clubs (Busy User)

```
┌────────────────────────────────┐
│ Mes clubs                      │
├────────────────────────────────┤
│                                │
│ ┌──────────────────────────┐   │
│ │ ASM                      │   │
│ │ Football • 15 joueurs    │   │
│ │                          │   │
│ │ ⚽ 🏛️ 👨‍👩‍👧 (your roles)  │   │
│ │                          │   │
│ │ Dernier: Match sam 15h   │   │
│ └──────────────────────────┘   │
│                                │
│ ┌──────────────────────────┐   │
│ │ Aviron Club              │   │
│ │ Aviron • 8 rameuses      │   │
│ │                          │   │
│ │ ⚽ 👨‍👩‍👧 (your roles)     │   │
│ │                          │   │
│ │ Dernier: Entraîn. ven    │   │
│ └──────────────────────────┘   │
│                                │
│ [+ Ajouter un club]            │
│                                │
└────────────────────────────────┘
```

### State 2: No Clubs Yet

```
┌────────────────────────────────┐
│ Mes clubs                      │
├────────────────────────────────┤
│                                │
│  🏛️ Vous n'êtes membre d'aucun│
│     club pour le moment        │
│                                │
│  ┌──────────────────────────┐  │
│  │ 📧 Invitations en attente│  │ ← Shows pending invites
│  │                          │  │
│  │ ✉️ ASM vous a invité     │  │
│  │    Rôle: Joueur          │  │
│  │                          │  │
│  │    [ACCEPTER] [REFUSER]  │  │
│  │                          │  │
│  │ ✉️ Aviron vous a invité  │  │
│  │    Rôle: Entraîneur      │  │
│  │                          │  │
│  │    [ACCEPTER] [REFUSER]  │  │
│  └──────────────────────────┘  │
│                                │
│  [+ Créer ou rejoindre]        │
│                                │
└────────────────────────────────┘
```

### State 3: One Club + Pending Invites

```
┌────────────────────────────────┐
│ Mes clubs                      │
├────────────────────────────────┤
│                                │
│ Mes clubs (1)                  │
│                                │
│ ┌──────────────────────────┐   │
│ │ ASM                      │   │
│ │ Football • 15 joueurs    │   │
│ │                          │   │
│ │ ⚽ 🏛️ 👨‍👩‍👧 (3 rôles)    │   │
│ │                          │   │
│ │ Dernier: Match sam 15h   │   │
│ └──────────────────────────┘   │
│                                │
│ Invitations en attente (2)     │
│                                │
│ ┌──────────────────────────┐   │
│ │ ✉️ Aviron vous a invité  │   │
│ │    Rôle: Entraîneur      │   │
│ │    [ACCEPTER] [REFUSER]  │   │
│ └──────────────────────────┘   │
│                                │
│ ┌──────────────────────────┐   │
│ │ ✉️ Rugby Club invit.     │   │
│ │    Rôle: Joueur          │   │
│ │    [ACCEPTER] [REFUSER]  │   │
│ └──────────────────────────┘   │
│                                │
│ [+ Ajouter un club]            │
│                                │
└────────────────────────────────┘
```

---

## Updated Code

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/invitations/providers/pending_invitations_provider.dart';
import 'package:viro_team_v2/providers/session_provider.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubSelectorScreen extends ConsumerWidget {
  const ClubSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(userClubsProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final theme = Theme.of(context).textTheme;

    return ViroScaffold(
      appBar: const ViroAppBar(title: Text('Mes clubs')),
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (clubs) {
          return invitationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (invitations) {
              return _buildContent(
                context,
                clubs,
                invitations,
                ref,
                theme,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<UserClubEntry> clubs,
    List<ClubInvitation> invitations,
    WidgetRef ref,
    TextTheme theme,
  ) {
    final hasClubs = clubs.isNotEmpty;
    final hasInvitations = invitations.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // EMPTY STATE
          if (!hasClubs && !hasInvitations)
            _EmptyStateWidget(
              onAdd: () => context.go(AppRoutes.entry),
            )
          else ...[
            // EXISTING CLUBS
            if (hasClubs) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ViroSpacing.lg,
                  ViroSpacing.lg,
                  ViroSpacing.lg,
                  ViroSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes clubs (${clubs.length})',
                      style: theme.titleSmall?.copyWith(
                        color: ViroColors.primary800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ViroSpacing.lg,
                ),
                child: Column(
                  spacing: ViroSpacing.md,
                  children: clubs.map((entry) {
                    return _ClubCard(
                      club: entry.$1,
                      membership: entry.$2,
                      onTap: () {
                        ref
                            .read(sessionProvider.notifier)
                            .setActiveClub(entry.$1.id);
                        context.pop();
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: ViroSpacing.lg),
            ],

            // PENDING INVITATIONS
            if (hasInvitations) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ViroSpacing.lg,
                  ViroSpacing.lg,
                  ViroSpacing.lg,
                  ViroSpacing.sm,
                ),
                child: Text(
                  'Invitations en attente (${invitations.length})',
                  style: theme.titleSmall?.copyWith(
                    color: ViroColors.primary800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ViroSpacing.lg,
                ),
                child: Column(
                  spacing: ViroSpacing.md,
                  children: invitations.map((invite) {
                    return _InvitationCard(
                      invitation: invite,
                      onAccept: () {
                        // Handle accept
                        ref
                            .read(sessionProvider.notifier)
                            .acceptInvitation(invite.code);
                      },
                      onDecline: () {
                        // Handle decline
                        ref
                            .read(sessionProvider.notifier)
                            .declineInvitation(invite.code);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: ViroSpacing.lg),
            ],

            // ADD CLUB BUTTON
            Padding(
              padding: const EdgeInsets.all(ViroSpacing.lg),
              child: ViroPrimaryButton(
                label: '+${hasClubs ? ' Ajouter un' : 'Créer ou rejoindre un'} club',
                onPressed: () => context.go(AppRoutes.entry),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// EMPTY STATE WIDGET
class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: ViroSpacing.xl),
          Text(
            '🏛️',
            textAlign: TextAlign.center,
            style: theme.displayMedium,
          ),
          const SizedBox(height: ViroSpacing.lg),
          Text(
            'Vous n\'êtes membre d\'aucun club pour le moment',
            textAlign: TextAlign.center,
            style: theme.titleMedium?.copyWith(
              color: ViroColors.primary800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ViroSpacing.md),
          Text(
            'Rejoignez un club existant ou créez-en un nouveau pour commencer.',
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              color: ViroColors.gray600,
            ),
          ),
          const SizedBox(height: ViroSpacing.xl),
          ViroPrimaryButton(
            label: 'Créer ou rejoindre un club',
            onPressed: onAdd,
          ),
          const SizedBox(height: ViroSpacing.xl),
        ],
      ),
    );
  }
}

/// CLUB CARD (showing roles, last event, member count)
class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.club,
    required this.membership,
    required this.onTap,
  });

  final Club club;
  final Membership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final accentColor = clubAccentColor(
      brandColorHex: club.brandColorHex,
      clubId: club.id,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ViroSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ViroColors.gray200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: Club name + icon
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      club.name[0].toUpperCase(),
                      style: theme.titleMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ViroSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: theme.titleSmall?.copyWith(
                          color: ViroColors.primary800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${club.sport} • ${club.memberCount ?? 0} membres',
                        style: theme.bodySmall?.copyWith(
                          color: ViroColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ViroSpacing.md),

            // ROLES BADGES
            Wrap(
              spacing: ViroSpacing.sm,
              children: [
                if (membership.roles.contains('player'))
                  _RoleBadge(
                    icon: '⚽',
                    label: 'Joueur',
                    color: ViroColors.primary100,
                    textColor: ViroColors.primary800,
                  ),
                if (membership.roles.contains('coach'))
                  _RoleBadge(
                    icon: '🏛️',
                    label: 'Entraîneur',
                    color: ViroColors.amber100,
                    textColor: ViroColors.amber900,
                  ),
                if (membership.roles.contains('admin'))
                  _RoleBadge(
                    icon: '⚙️',
                    label: 'Admin',
                    color: ViroColors.gray100,
                    textColor: ViroColors.gray900,
                  ),
                if (membership.parentLinks?.isNotEmpty ?? false)
                  _RoleBadge(
                    icon: '👨‍👩‍👧',
                    label: 'Parent',
                    color: ViroColors.green100,
                    textColor: ViroColors.green900,
                  ),
              ],
            ),
            const SizedBox(height: ViroSpacing.md),

            // LAST EVENT / STATUS
            if (club.lastEventDate != null)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: ViroColors.gray600,
                  ),
                  const SizedBox(width: ViroSpacing.sm),
                  Text(
                    'Dernier: ${_formatDate(club.lastEventDate!)}',
                    style: theme.bodySmall?.copyWith(
                      color: ViroColors.gray600,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Aucun événement créé',
                style: theme.bodySmall?.copyWith(
                  color: ViroColors.gray500,
                  fontStyle: FontStyle.italic,
                ),
              ),

            // RIGHT ARROW
            const SizedBox(height: ViroSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward,
                size: 20,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'aujourd\'hui';
    } else if (diff.inDays == 1) {
      return 'hier';
    } else if (diff.inDays < 7) {
      return 'il y a ${diff.inDays}j';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'il y a ${weeks}sem';
    } else {
      final months = (diff.inDays / 30).floor();
      return 'il y a ${months}m';
    }
  }
}

/// ROLE BADGE
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.sm,
        vertical: ViroSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: ViroSpacing.xs),
          Text(
            label,
            style: theme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// INVITATION CARD
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  final ClubInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(ViroSpacing.md),
      decoration: BoxDecoration(
        color: ViroColors.primary50,
        border: Border.all(color: ViroColors.primary200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER: Invitation message
          Row(
            children: [
              Text('✉️', style: theme.headlineSmall),
              const SizedBox(width: ViroSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invitation.clubName} vous a invité',
                      style: theme.bodyMedium?.copyWith(
                        color: ViroColors.primary800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rôle: ${_roleLabel(invitation.role)}',
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.primary700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.md),

          // OPTIONAL: Message from inviter
          if (invitation.message != null && invitation.message!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(ViroSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                invitation.message!,
                style: theme.bodySmall?.copyWith(
                  color: ViroColors.primary700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: ViroSpacing.md),
          ],

          // ACTIONS
          Row(
            spacing: ViroSpacing.md,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDecline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: ViroSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: ViroColors.primary300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Refuser',
                      textAlign: TextAlign.center,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.primary700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: ViroSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: ViroColors.primary600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Accepter',
                      textAlign: TextAlign.center,
                      style: theme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'player':
        return 'Joueur';
      case 'coach':
        return 'Entraîneur';
      case 'admin':
        return 'Admin';
      case 'parent':
        return 'Parent';
      default:
        return role;
    }
  }
}
```

---

## Data Models Needed

```dart
class ClubInvitation {
  final String code;
  final String clubId;
  final String clubName;
  final String role;
  final String? message;
  final DateTime createdAt;
  
  ClubInvitation({
    required this.code,
    required this.clubId,
    required this.clubName,
    required this.role,
    this.message,
    required this.createdAt,
  });
}

// Add to Club model:
extension ClubExtensions on Club {
  int? get memberCount => /* query membership count */;
  DateTime? get lastEventDate => /* query last event date */;
}
```

---

## Provider Needed

```dart
final pendingInvitationsProvider = FutureProvider<List<ClubInvitation>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return [];
  
  final user = await ref.read(firebaseServiceProvider).getUser(uid);
  if (user?.email == null) return [];
  
  // Query invitations where email matches
  final invites = await ref.read(firebaseServiceProvider)
    .getPendingInvitations(user!.email!);
  
  return invites;
});
```

---

## Key Improvements

✅ **Shows pending invitations** — User knows they have invites waiting
✅ **Role badges** — Clear what the user can do at each club
✅ **Last event date** — Shows club is active
✅ **Member count** — Social proof
✅ **Empty state** — Friendly, helpful message with clear CTA
✅ **Section headers** — Organized by status (clubs vs invitations)
✅ **Scalable** — Handles 0, 1, or many clubs/invites
✅ **Invitations prominent** — Don't get lost in the UI

---

## Next Steps

1. Create `pendingInvitationsProvider`
2. Create `ClubInvitation` model
3. Add `lastEventDate` and `memberCount` queries to Club
4. Implement accept/decline invitation handlers
5. Test with 0, 1, and 5+ clubs
6. Test with pending invitations
