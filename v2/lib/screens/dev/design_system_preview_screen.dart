import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_theme.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_floating_icon_button.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

/// Aperçu local du design system (écran dev, à retirer en prod).
class DesignSystemPreviewScreen extends StatelessWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ViroScaffold(
      appBar: const ViroAppBar(title: Text('ViroTeam v2')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: ViroSpacing.screenHorizontal,
          vertical: ViroSpacing.lg,
        ),
        children: [
          Text('Design system', style: textTheme.headlineLarge),
          const SizedBox(height: ViroSpacing.sm),
          Text(
            'Bleu profond, surfaces flottantes.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: ViroSpacing.lg),
          Text('ICÔNES PHOSPHOR', style: ViroTypography.sectionHeader),
          const SizedBox(height: ViroSpacing.sm),
          Text(
            'Via ViroIcons — pas de Material Icons.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: ViroSpacing.sm),
          const _IconsCatalog(),
          const SizedBox(height: ViroSpacing.lg),
          Text('BOUTONS FLOTTANTS', style: ViroTypography.sectionHeader),
          const SizedBox(height: ViroSpacing.sm),
          Row(
            children: [
              ViroFloatingIconButton(
                icon: ViroIcons.menu,
                tooltip: 'Menu',
                onPressed: () => _showSampleMenu(context),
              ),
              const SizedBox(width: ViroSpacing.sm),
              ViroFloatingIconButton(
                icon: ViroIcons.settings,
                tooltip: 'Réglages',
                onPressed: () {},
              ),
              const Spacer(),
              ViroFloatingActionButton(
                icon: ViroIcons.add,
                label: 'Créer',
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.lg),
          Text('BOUTONS', style: ViroTypography.sectionHeader),
          const SizedBox(height: ViroSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Action principale'),
            ),
          ),
          const SizedBox(height: ViroSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Action secondaire'),
            ),
          ),
          const SizedBox(height: ViroSpacing.sm),
          TextButton(onPressed: () {}, child: const Text('Action tertiaire')),
          const SizedBox(height: ViroSpacing.lg),
          Text('CARTES', style: ViroTypography.sectionHeader),
          const SizedBox(height: ViroSpacing.sm),
          const _SampleEventCard(),
          const SizedBox(height: ViroSpacing.sm),
          Row(
            children: const [
              Expanded(
                child: ViroStatsCard(
                  label: 'Matchs',
                  value: '12',
                  subtitle: '10 titulaire',
                ),
              ),
              SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: ViroStatsCard(label: 'Buts', value: '3'),
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.lg),
          Text('BADGES RÔLES', style: ViroTypography.sectionHeader),
          const SizedBox(height: ViroSpacing.sm),
          Wrap(
            spacing: ViroSpacing.sm,
            runSpacing: ViroSpacing.sm,
            children: const [
              ViroRoleBadge(role: ViroRole.player),
              ViroRoleBadge(role: ViroRole.coach),
              ViroRoleBadge(role: ViroRole.parent),
              ViroRoleBadge(role: ViroRole.admin),
            ],
          ),
          const SizedBox(height: ViroSpacing.md),
          Text('Taille compacte', style: textTheme.bodySmall),
          const SizedBox(height: ViroSpacing.sm),
          Wrap(
            spacing: ViroSpacing.sm,
            runSpacing: ViroSpacing.sm,
            children: const [
              ViroRoleBadge(role: ViroRole.player, compact: true),
              ViroRoleBadge(role: ViroRole.coach, compact: true),
              ViroRoleBadge(role: ViroRole.parent, compact: true),
              ViroRoleBadge(role: ViroRole.admin, compact: true),
            ],
          ),
          const SizedBox(height: ViroSpacing.xl),
        ],
      ),
    );
  }
}

class _IconsCatalog extends StatelessWidget {
  const _IconsCatalog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in ViroIcons.catalog) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: ViroSpacing.sm,
              bottom: ViroSpacing.sm,
            ),
            child: Text(
              group.title.toUpperCase(),
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: ViroColors.gray600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ViroCard(
            elevated: false,
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(ViroSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 4;
                const spacing = ViroSpacing.sm;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final (name, icon) in group.icons)
                      SizedBox(
                        width: tileWidth,
                        child: _IconTile(name: name, icon: icon),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: ViroSpacing.sm),
        ],
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: ViroSpacing.sm,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: ViroColors.surface,
        borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ViroIcon(icon, size: 26, color: ViroColors.primary800),
          const SizedBox(height: 6),
          Text(
            name,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: ViroColors.gray600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

void _showSampleMenu(BuildContext context) {
  final renderBox = context.findRenderObject() as RenderBox?;
  final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + ViroSpacing.topBarHeight,
      offset.dx + 200,
      0,
    ),
    items: const [
      PopupMenuItem(value: 1, child: Text('Mon profil')),
      PopupMenuItem(value: 2, child: Text('Changer de club')),
      PopupMenuItem(value: 3, child: Text('Déconnexion')),
    ],
  );
}

class _SampleEventCard extends StatelessWidget {
  const _SampleEventCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ViroCard(
      accentColor: ViroColors.primary600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ViroColors.primary50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SAM. 15 MARS',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ViroColors.primary800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '15:00',
                style: textTheme.titleMedium?.copyWith(
                  color: ViroColors.primary800,
                ),
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ViroIcon(ViroIcons.ball, size: 20, color: ViroColors.primary600),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: Text('Match — U15 Séniors', style: textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ViroIcon(ViroIcons.place, size: 16, color: ViroColors.gray400),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Stade Municipal', style: textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: ViroSpacing.md),
          const Divider(height: 1, color: ViroColors.gray100),
          const SizedBox(height: ViroSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Oui'),
                ),
              ),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Peut-être'),
                ),
              ),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Non'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
