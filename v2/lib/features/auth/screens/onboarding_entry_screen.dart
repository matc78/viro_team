import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class OnboardingEntryScreen extends StatelessWidget {
  const OnboardingEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ViroScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Bienvenue sur ViroTeam',
                style: theme.headlineMedium?.copyWith(
                  color: ViroColors.primary800,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ViroSpacing.md),
              Text(
                'Gérez votre club sportif : planning, présences, tournois et communication — tout en un seul endroit.',
                style: theme.bodyLarge?.copyWith(color: ViroColors.gray600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ViroSpacing.xl),
              _BenefitRow(
                icon: Icons.event_available_outlined,
                text: 'Organisez entraînements et matchs',
              ),
              _BenefitRow(
                icon: Icons.groups_outlined,
                text: 'Suivez les présences en temps réel',
              ),
              _BenefitRow(
                icon: Icons.emoji_events_outlined,
                text: 'Animez des tournois et championnats',
              ),
              const Spacer(),
              ViroPrimaryButton(
                label: 'Créer mon club',
                onPressed: () => context.push(
                  '${AppRoutes.signup}?intent=founder',
                ),
              ),
              const SizedBox(height: ViroSpacing.sm),
              ViroPrimaryButton(
                label: 'J\'ai un code d\'invitation',
                outlined: true,
                onPressed: () => context.push(AppRoutes.join),
              ),
              const SizedBox(height: ViroSpacing.md),
              TextButton(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text('Déjà un compte ? Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: ViroColors.primary600, size: 22),
          const SizedBox(width: ViroSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
