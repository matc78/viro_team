import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/join/providers/pending_invitation_provider.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class JoinCodeScreen extends ConsumerStatefulWidget {
  const JoinCodeScreen({super.key});

  @override
  ConsumerState<JoinCodeScreen> createState() => _JoinCodeScreenState();
}

class _JoinCodeScreenState extends ConsumerState<JoinCodeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    final ok =
        await ref.read(pendingInvitationProvider.notifier).lookupCode(code);
    setState(() => _loading = false);

    if (!mounted) return;
    if (!ok) return;

    final auth = ref.read(authStateProvider).value;
    if (auth != null) {
      context.go(AppRoutes.joinPreview);
    } else {
      context.push('${AppRoutes.signup}?intent=join&code=$code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingInvitationProvider);
    final theme = Theme.of(context).textTheme;

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Rejoindre un club'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Demandez le code d\'invitation à votre entraîneur ou à l\'administrateur du club.',
                style: theme.bodyLarge,
              ),
              const SizedBox(height: ViroSpacing.xl),
              TextField(
                controller: _codeController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Code d\'invitation',
                  hintText: 'Ex. ASMP1K2E',
                ),
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                onSubmitted: (_) => _validate(),
              ),
              if (pending.error != null) ...[
                const SizedBox(height: ViroSpacing.md),
                Text(
                  pending.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const Spacer(),
              ViroPrimaryButton(
                label: 'Valider le code',
                isLoading: _loading,
                onPressed: _validate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
