import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/invitations/providers/pending_invitations_provider.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_invitation.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/providers/session_provider.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/features/clubs/widgets/add_club_sheet.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubSelectorScreen extends ConsumerWidget {
  const ClubSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(userClubsWithEventsProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final theme = Theme.of(context).textTheme;

    return ViroScaffold(
      appBar: const ViroAppBar(title: Text('Mes clubs')),
      body: SafeArea(
        child: clubsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (clubs) {
            return invitationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (invitations) => _ClubSelectorBody(
                clubs: clubs,
                invitations: invitations,
                theme: theme,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ClubSelectorBody extends ConsumerWidget {
  const _ClubSelectorBody({
    required this.clubs,
    required this.invitations,
    required this.theme,
  });

  final List<UserClubWithEvent> clubs;
  final List<ClubInvitation> invitations;
  final TextTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClubs = clubs.isNotEmpty;
    final hasInvitations = invitations.isNotEmpty;

    if (!hasClubs && !hasInvitations) {
      return _EmptyStateWidget(
        onAdd: () => showAddClubSheet(context, ref),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasClubs) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ViroSpacing.lg,
                ViroSpacing.lg,
                ViroSpacing.lg,
                ViroSpacing.sm,
              ),
              child: Text(
                'Mes clubs (${clubs.length})',
                style: theme.titleSmall?.copyWith(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ViroSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < clubs.length; i++) ...[
                    if (i > 0) const SizedBox(height: ViroSpacing.md),
                    _ClubCard(
                      entry: clubs[i],
                      onTap: () {
                        final club = clubs[i].club;
                        final membership = clubs[i].membership;
                        ref.read(sessionProvider.notifier).setActiveClub(
                              club.id,
                              role: membership.role,
                            );
                        context.push(AppRoutes.clubDetailPath(club.id));
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ViroSpacing.lg),
          ],
          if (hasInvitations) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                ViroSpacing.lg,
                hasClubs ? 0 : ViroSpacing.lg,
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
              padding: const EdgeInsets.symmetric(horizontal: ViroSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < invitations.length; i++) ...[
                    if (i > 0) const SizedBox(height: ViroSpacing.md),
                    _InvitationCard(invitation: invitations[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ViroSpacing.lg),
          ],
          Padding(
            padding: const EdgeInsets.all(ViroSpacing.lg),
            child: ViroPrimaryButton(
              label: hasClubs
                  ? '+ Ajouter un club'
                  : 'Créer ou rejoindre un club',
              outlined: hasClubs,
              onPressed: () => showAddClubSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      child: Column(
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
            style: theme.bodyMedium?.copyWith(color: ViroColors.gray600),
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

class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.entry,
    required this.onTap,
  });

  final UserClubWithEvent entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final club = entry.club;
    final membership = entry.membership;
    final accentColor = clubAccentColor(
      brandColorHex: club.brandColorHex,
      clubId: club.id,
    );
    final memberLabel = club.memberCount == 1 ? 'membre' : 'membres';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ViroSpacing.md),
        decoration: BoxDecoration(
          color: ViroColors.white,
          border: Border.all(color: ViroColors.gray200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ClubAvatar(
                  logoUrl: club.logoUrl,
                  name: club.name,
                  accentColor: accentColor,
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
                        '${club.sport} • ${club.memberCount} $memberLabel',
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
            Wrap(
              spacing: ViroSpacing.sm,
              runSpacing: ViroSpacing.sm,
              children: _roleBadgesFor(membership.role),
            ),
            const SizedBox(height: ViroSpacing.md),
            if (entry.highlightEvent != null)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: ViroColors.gray600,
                  ),
                  const SizedBox(width: ViroSpacing.sm),
                  Expanded(
                    child: Text(
                      _eventHighlightLabel(entry.highlightEvent!),
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.gray600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Aucun événement à venir',
                style: theme.bodySmall?.copyWith(
                  color: ViroColors.gray400,
                  fontStyle: FontStyle.italic,
                ),
              ),
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

  List<Widget> _roleBadgesFor(String role) {
    final badges = <Widget>[];
    if (MemberRoleHierarchy.satisfies(role, MemberRoles.player)) {
      badges.add(const ViroRoleBadge(role: ViroRole.player, compact: true));
    }
    if (MemberRoleHierarchy.satisfies(role, MemberRoles.coach) &&
        role != MemberRoles.player) {
      badges.add(const ViroRoleBadge(role: ViroRole.coach, compact: true));
    }
    if (role == MemberRoles.admin) {
      badges.add(const ViroRoleBadge(role: ViroRole.admin, compact: true));
    }
    return badges;
  }
}

class _ClubAvatar extends StatelessWidget {
  const _ClubAvatar({
    required this.logoUrl,
    required this.name,
    required this.accentColor,
  });

  final String? logoUrl;
  final String name;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        image: logoUrl != null
            ? DecorationImage(
                image: NetworkImage(logoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: logoUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.invitation});

  final ClubInvitation invitation;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _loading = false;
  String? _error;

  String _roleLabel(String role) => switch (role) {
        MemberRoles.coach => 'Entraîneur',
        MemberRoles.admin => 'Admin',
        MemberRoles.player => 'Joueur',
        _ => role,
      };

  Future<void> _accept() async {
    final user = ref.read(viroUserProvider).value;
    if (user == null) {
      context.push('${AppRoutes.signup}?intent=join');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(invitationServiceProvider).acceptInvitation(
            invitation: widget.invitation,
            user: user,
          );
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(userClubsProvider);
      ref.invalidate(userClubsWithEventsProvider);
      ref.invalidate(viroUserFutureProvider);
      ref.read(sessionProvider.notifier).setActiveClub(
            widget.invitation.clubId,
            role: widget.invitation.role,
          );
      if (mounted) {
        context.push(AppRoutes.clubDetailPath(widget.invitation.clubId));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(invitationServiceProvider)
          .declineInvitation(widget.invitation);
      ref.invalidate(pendingInvitationsProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final invite = widget.invitation;
    final clubName = invite.clubName ?? 'Un club';

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✉️', style: theme.headlineSmall),
              const SizedBox(width: ViroSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$clubName vous a invité',
                      style: theme.bodyMedium?.copyWith(
                        color: ViroColors.primary800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rôle : ${_roleLabel(invite.role)}',
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.primary600,
                      ),
                    ),
                    if (invite.clubSport != null && invite.clubSport!.isNotEmpty)
                      Text(
                        invite.clubSport!,
                        style: theme.bodySmall?.copyWith(
                          color: ViroColors.gray600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: ViroSpacing.sm),
            Text(
              _error!,
              style: theme.bodySmall?.copyWith(color: ViroColors.error),
            ),
          ],
          const SizedBox(height: ViroSpacing.md),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _loading ? null : _decline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: ViroSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: ViroColors.white,
                      border: Border.all(color: ViroColors.primary200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Refuser',
                      textAlign: TextAlign.center,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.primary600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ViroSpacing.md),
              Expanded(
                child: GestureDetector(
                  onTap: _loading ? null : _accept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: ViroSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: ViroColors.primary600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ViroColors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            'Accepter',
                            textAlign: TextAlign.center,
                            style: theme.bodySmall?.copyWith(
                              color: ViroColors.white,
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
}

String _eventHighlightLabel(ClubEvent event) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  final isUpcoming = !eventDay.isBefore(today);

  final typeLabel = switch (event.type) {
    EventTypes.match => 'Match',
    EventTypes.training => 'Entraînement',
    EventTypes.tournament => 'Tournoi',
    _ => event.title.isNotEmpty ? event.title : 'Événement',
  };

  if (isUpcoming) {
    const weekdays = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    final w = weekdays[event.date.weekday - 1];
    final time = event.startTime?.trim();
    if (time != null && time.isNotEmpty) {
      return 'Prochain : $typeLabel $w $time';
    }
    return 'Prochain : $typeLabel $w';
  }

  return 'Dernier : $typeLabel ${_relativeDate(event.date)}';
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) return 'aujourd\'hui';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
  if (diff.inDays < 30) return 'il y a ${(diff.inDays / 7).floor()}sem';
  return 'il y a ${(diff.inDays / 30).floor()}m';
}
