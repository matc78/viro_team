import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/join/providers/pending_invitation_provider.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    this.intentParam,
    this.codeParam,
  });

  final String? intentParam;
  final String? codeParam;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _prefillApplied = false;

  void _applyInvitationPrefill(PendingInvitationState pending) {
    if (_prefillApplied || !pending.hasInvitation) return;

    final inv = pending.invitation!;
    var applied = false;

    final first = inv.firstName?.trim();
    if (first != null && first.isNotEmpty && _firstNameController.text.isEmpty) {
      _firstNameController.text = first;
      applied = true;
    }

    final last = inv.lastName?.trim();
    if (last != null && last.isNotEmpty && _lastNameController.text.isEmpty) {
      _lastNameController.text = last;
      applied = true;
    }

    final email = inv.email?.trim();
    if (email != null && email.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = email;
      applied = true;
    }

    if (applied) _prefillApplied = true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final intent = widget.intentParam == 'join'
          ? SignUpIntent.join
          : SignUpIntent.founder;
      ref.read(signUpIntentProvider.notifier).setIntent(intent);
      final code = widget.codeParam;
      if (code != null && code.isNotEmpty) {
        ref.read(pendingInviteCodeProvider.notifier).setCode(code);
        ref.read(pendingInvitationProvider.notifier).lookupCode(code);
      }
      if (intent == SignUpIntent.join) {
        _applyInvitationPrefill(ref.read(pendingInvitationProvider));
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final cred = await auth.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final uid = cred.user!.uid;
      final email = _emailController.text.trim();
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();

      final profile = ViroUser(
        uid: uid,
        email: email,
        emailNorm: email.toLowerCase(),
        firstName: first,
        lastName: last,
        displayName: '$first $last'.trim(),
        profileCompleted: false,
      );
      await ref.read(userServiceProvider).createUserProfile(profile);

      if (!mounted) return;
      final intent = ref.read(signUpIntentProvider);
      final pending = ref.read(pendingInvitationProvider);

      if (intent == SignUpIntent.join && pending.hasInvitation) {
        context.go(AppRoutes.joinPreview);
      } else if (intent == SignUpIntent.founder) {
        context.go(AppRoutes.clubSetup);
      } else {
        context.go(AppRoutes.entry);
      }
    } catch (e) {
      setState(() => _error = 'Impossible de créer le compte. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intent = ref.watch(signUpIntentProvider);
    final isJoin = intent == SignUpIntent.join;

    ref.listen(pendingInvitationProvider, (_, next) {
      if (isJoin) _applyInvitationPrefill(next);
    });

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(isJoin ? 'Créer un compte' : 'Compte fondateur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (v) =>
                      v != null && v.trim().length >= 2 ? null : 'Requis',
                ),
                const SizedBox(height: ViroSpacing.md),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) =>
                      v != null && v.trim().length >= 2 ? null : 'Requis',
                ),
                const SizedBox(height: ViroSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Email invalide',
                ),
                const SizedBox(height: ViroSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  validator: (v) =>
                      v != null && v.length >= 8 ? null : '8 caractères minimum',
                ),
                if (_error != null) ...[
                  const SizedBox(height: ViroSpacing.md),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: ViroSpacing.xl),
                ViroPrimaryButton(
                  label: 'Créer mon compte',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
