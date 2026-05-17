import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/invitations/providers/pending_invitations_provider.dart';
import 'package:viro_team_v2/features/join/providers/pending_invitation_provider.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/providers/session_provider.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class InvitationPreviewScreen extends ConsumerStatefulWidget {
  const InvitationPreviewScreen({super.key});

  @override
  ConsumerState<InvitationPreviewScreen> createState() =>
      _InvitationPreviewScreenState();
}

class _InvitationPreviewScreenState
    extends ConsumerState<InvitationPreviewScreen> {
  bool _loading = false;
  String? _error;

  String _roleLabel(String role) => switch (role) {
        MemberRoles.coach => 'Entraîneur',
        MemberRoles.player => 'Joueur',
        _ => role,
      };

  ViroRole _badge(String role) => switch (role) {
        MemberRoles.coach => ViroRole.coach,
        _ => ViroRole.player,
      };

  Future<void> _accept() async {
    final pending = ref.read(pendingInvitationProvider);
    final user = ref.read(viroUserProvider).value;
    if (!pending.hasInvitation || user == null) {
      context.push('${AppRoutes.signup}?intent=join');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(invitationServiceProvider).acceptInvitation(
            invitation: pending.invitation!,
            user: user,
          );
      ref.invalidate(userClubsProvider);
      ref.invalidate(userClubsWithEventsProvider);
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(viroUserFutureProvider);
      ref.read(pendingInvitationProvider.notifier).clear();
      ref.read(sessionProvider.notifier).setActiveClub(
            pending.club!.id,
            role: pending.invitation!.role,
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    final pending = ref.read(pendingInvitationProvider);
    if (pending.invitation != null) {
      await ref.read(invitationServiceProvider).declineInvitation(
            pending.invitation!,
          );
    }
    ref.read(pendingInvitationProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.entry);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingInvitationProvider);
    final theme = Theme.of(context).textTheme;

    if (!pending.hasInvitation) {
      return ViroScaffold(
        appBar: const ViroAppBar(title: Text('Invitation')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.join),
            child: const Text('Saisir un code'),
          ),
        ),
      );
    }

    final club = pending.club!;
    final invite = pending.invitation!;

    return ViroScaffold(
      appBar: const ViroAppBar(title: Text('Invitation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vous êtes invité à rejoindre',
                style: theme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ViroSpacing.md),
              Text(
                club.name,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                club.sport,
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
              const SizedBox(height: ViroSpacing.lg),
              Center(child: ViroRoleBadge(role: _badge(invite.role))),
              const SizedBox(height: ViroSpacing.sm),
              Text(
                'Rôle proposé : ${_roleLabel(invite.role)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ViroSpacing.sm),
              Text(
                'En tant que membre du club, vous aurez aussi accès aux fonctions joueur.',
                style: theme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: ViroSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              ViroPrimaryButton(
                label: 'Accepter l\'invitation',
                isLoading: _loading,
                onPressed: _accept,
              ),
              const SizedBox(height: ViroSpacing.sm),
              ViroPrimaryButton(
                label: 'Refuser',
                outlined: true,
                onPressed: _decline,
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.joinRequestRole),
                child: const Text('Demander un autre rôle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
