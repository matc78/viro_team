import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/club_setup/providers/club_setup_provider.dart';

/// Propose de créer un club ou d'en rejoindre un via code d'invitation.
Future<void> showAddClubSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx).textTheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ViroSpacing.lg,
            ViroSpacing.md,
            ViroSpacing.lg,
            ViroSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajouter un club',
                style: theme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ViroColors.primary800,
                ),
              ),
              const SizedBox(height: ViroSpacing.sm),
              Text(
                'Créez un nouveau club ou rejoignez-en un avec un code.',
                style: theme.bodyMedium?.copyWith(color: ViroColors.gray600),
              ),
              const SizedBox(height: ViroSpacing.lg),
              _AddClubOptionTile(
                icon: Icons.groups_outlined,
                title: 'Créer un club',
                subtitle: 'Devenez administrateur d\'un nouveau club',
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clubSetupProvider.notifier).reset();
                  context.push(AppRoutes.clubSetup);
                },
              ),
              const SizedBox(height: ViroSpacing.sm),
              _AddClubOptionTile(
                icon: Icons.vpn_key_outlined,
                title: 'Rejoindre avec un code',
                subtitle: 'Code fourni par votre entraîneur ou admin',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.join);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AddClubOptionTile extends StatelessWidget {
  const _AddClubOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Material(
      color: ViroColors.gray50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ViroColors.primary50,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: ViroColors.primary600, size: 24),
              ),
              const SizedBox(width: ViroSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ViroColors.primary800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.bodySmall?.copyWith(
                        color: ViroColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              ViroIcon(
                ViroIcons.chevronRight,
                size: 18,
                color: ViroColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
