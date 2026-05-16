import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_member.dart';

Future<String?> showChangeRoleSheet(
  BuildContext context, {
  required ClubMember member,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ViroSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rôle de ${member.fullName}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ViroColors.primary800,
                    ),
              ),
              const SizedBox(height: ViroSpacing.md),
              ListTile(
                title: const Text('Joueur'),
                trailing: member.role == MemberRoles.player
                    ? const Icon(Icons.check, color: ViroColors.primary600)
                    : null,
                onTap: () => Navigator.pop(ctx, MemberRoles.player),
              ),
              ListTile(
                title: const Text('Coach'),
                trailing: member.role == MemberRoles.coach
                    ? const Icon(Icons.check, color: ViroColors.primary600)
                    : null,
                onTap: () => Navigator.pop(ctx, MemberRoles.coach),
              ),
              ListTile(
                title: const Text('Administrateur'),
                trailing: member.role == MemberRoles.admin
                    ? const Icon(Icons.check, color: ViroColors.primary600)
                    : null,
                onTap: () => Navigator.pop(ctx, MemberRoles.admin),
              ),
            ],
          ),
        ),
      );
    },
  );
}
