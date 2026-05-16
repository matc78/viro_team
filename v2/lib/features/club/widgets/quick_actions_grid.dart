import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/config/viro_motion.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _QuickActionsGridBase extends StatelessWidget {
  const _QuickActionsGridBase({required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.screenHorizontal,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: ViroSpacing.sm,
          crossAxisSpacing: ViroSpacing.sm,
          childAspectRatio: 1.75,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return _QuickActionCell(action: actions[index]);
        },
      ),
    );
  }
}

/// Cellule grille — remplit la hauteur de la cellule et centre le contenu.
class _QuickActionCell extends StatelessWidget {
  const _QuickActionCell({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ViroSpacing.cardRadius);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return ViroPressable(
      onTap: action.onTap,
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ViroColors.surfaceCard,
          borderRadius: radius,
          border: Border.all(
            color: ViroColors.primary100.withValues(alpha: 0.45),
          ),
          boxShadow: ViroMotion.cardShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ViroSpacing.md,
            vertical: ViroSpacing.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ViroIcon(
                action.icon,
                size: 24,
                color: ViroColors.primary600,
              ),
              const SizedBox(height: ViroSpacing.xs),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accès rapides membre : Mes équipes, Tournois.
class MemberQuickActionsGrid extends StatelessWidget {
  const MemberQuickActionsGrid({
    super.key,
    this.onMyTeams,
    this.onTournaments,
  });

  final VoidCallback? onMyTeams;
  final VoidCallback? onTournaments;

  @override
  Widget build(BuildContext context) {
    return _QuickActionsGridBase(
      actions: [
        QuickAction(
          label: 'Mes équipes',
          icon: ViroIcons.users,
          onTap: onMyTeams,
        ),
        QuickAction(
          label: 'Tournois',
          icon: ViroIcons.trophy,
          onTap: onTournaments,
        ),
      ],
    );
  }
}

/// Gestion du club (coach + admin).
class ClubManagementActionsGrid extends StatelessWidget {
  const ClubManagementActionsGrid({
    super.key,
    required this.role,
    this.onAttendance,
    this.onManageTeams,
    this.onManageMembers,
    this.onManageTournaments,
    this.onFees,
  });

  final String role;
  final VoidCallback? onAttendance;
  final VoidCallback? onManageTeams;
  final VoidCallback? onManageMembers;
  final VoidCallback? onManageTournaments;
  final VoidCallback? onFees;

  List<QuickAction> get _actions {
    return [
      QuickAction(
        label: 'Pointer les présences',
        icon: ViroIcons.check,
        onTap: onAttendance,
      ),
      QuickAction(
        label: 'Gérer les équipes',
        icon: ViroIcons.users,
        onTap: onManageTeams,
      ),
      if (role == MemberRoles.admin || role == MemberRoles.coach)
        QuickAction(
          label: 'Gérer les membres',
          icon: ViroIcons.user,
          onTap: onManageMembers,
        ),
      if (role == MemberRoles.admin)
        QuickAction(
          label: 'Gérer les tournois',
          icon: ViroIcons.trophy,
          onTap: onManageTournaments,
        ),
      if (role == MemberRoles.admin)
        QuickAction(
          label: 'Cotisations',
          icon: ViroIcons.calendar,
          onTap: onFees,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _QuickActionsGridBase(actions: _actions);
  }
}
