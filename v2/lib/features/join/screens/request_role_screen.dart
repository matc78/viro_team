import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/join/providers/pending_invitation_provider.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class RequestRoleScreen extends ConsumerStatefulWidget {
  const RequestRoleScreen({super.key});

  @override
  ConsumerState<RequestRoleScreen> createState() => _RequestRoleScreenState();
}

class _RequestRoleScreenState extends ConsumerState<RequestRoleScreen> {
  String _roleRequested = MemberRoles.coach;
  final _messageController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pending = ref.read(pendingInvitationProvider);
    final user = ref.read(viroUserProvider).value;
    if (!pending.hasInvitation || user == null) return;

    final currentRole = pending.invitation!.role;
    if (currentRole == _roleRequested) {
      ViroSnackBar.show(context, 'Choisissez un rôle différent.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(joinRequestServiceProvider).createRoleChangeRequest(
            user: user,
            club: pending.club!,
            currentRole: currentRole,
            roleRequested: _roleRequested,
            message: _messageController.text.trim(),
          );
      if (mounted) {
        ViroSnackBar.show(context, 'Demande envoyée aux administrateurs.');
        context.go(AppRoutes.joinPreview);
      }
    } catch (e) {
      if (mounted) {
        ViroSnackBar.show(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingInvitationProvider);

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Demander un rôle'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Votre code vous attribue un rôle initial. Vous pouvez demander un autre rôle aux administrateurs.',
              ),
              const SizedBox(height: ViroSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _roleRequested,
                decoration: const InputDecoration(labelText: 'Rôle souhaité'),
                items: const [
                  DropdownMenuItem(
                    value: MemberRoles.player,
                    child: Text('Joueur'),
                  ),
                  DropdownMenuItem(
                    value: MemberRoles.coach,
                    child: Text('Entraîneur'),
                  ),
                ],
                onChanged: pending.hasInvitation
                    ? (v) {
                        if (v != null) setState(() => _roleRequested = v);
                      }
                    : null,
              ),
              const SizedBox(height: ViroSpacing.md),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message (optionnel)',
                ),
              ),
              const Spacer(),
              ViroPrimaryButton(
                label: 'Envoyer la demande',
                isLoading: _loading,
                onPressed: pending.hasInvitation ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
