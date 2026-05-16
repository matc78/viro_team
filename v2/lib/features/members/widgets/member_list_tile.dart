import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/members/widgets/member_avatar.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_invitation.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/utils/invite_message.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_role_badge.dart';

class MemberListTile extends StatelessWidget {
  const MemberListTile({
    super.key,
    required this.member,
    required this.club,
    required this.viewerRole,
    this.onChangeRole,
    this.onRemove,
    this.showClubAdminActions = true,
  });

  final ClubMember member;
  final Club club;
  final String viewerRole;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRemove;

  /// `false` dans un roster d'équipe : pas de menu admin ni copie d'invitation.
  final bool showClubAdminActions;

  bool get _isAdmin => viewerRole == MemberRoles.admin;
  bool get _canCopyInvite =>
      showClubAdminActions &&
      member.hasPendingInvite &&
      !member.hasLinkedAccount;

  Future<void> _copyInvite(BuildContext context) async {
    if (member.pendingInviteCode == null) return;
    final invitation = ClubInvitation(
      id: member.activeInvitationId ?? '',
      clubId: club.id,
      code: member.pendingInviteCode!,
      role: member.role,
      status: InvitationStatus.pending,
      memberId: member.memberId,
      expiresAt: member.pendingInviteExpiresAt,
      clubName: club.name,
    );
    final message = buildInviteMessage(club: club, invitation: invitation);
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ViroSnackBar.show(context, 'Message copié dans le presse-papiers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ViroCard(
      margin: const EdgeInsets.only(bottom: ViroSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.md,
        vertical: ViroSpacing.sm,
      ),
      child: Row(
        children: [
          MemberAvatar(member: member),
          const SizedBox(width: ViroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName.isNotEmpty ? member.fullName : 'Sans nom',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ViroColors.primary800,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: ViroSpacing.xs,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ViroRoleBadge(
                      role: viroRoleFromMemberRole(member.role),
                      compact: true,
                    ),
                    if (!member.hasLinkedAccount)
                      Text(
                        'Pas encore inscrit',
                        style: theme.bodySmall?.copyWith(
                          color: ViroColors.gray600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_canCopyInvite)
            IconButton(
              icon: ViroIcon(ViroIcons.copy, color: ViroColors.primary600),
              tooltip: 'Copier le code d\'invitation',
              onPressed: () => _copyInvite(context),
            ),
          if (!showClubAdminActions && onRemove != null)
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: ViroColors.error,
                size: 22,
              ),
              onPressed: onRemove,
              tooltip: 'Retirer de l\'équipe',
            ),
          if (showClubAdminActions &&
              _isAdmin &&
              member.role != MemberRoles.admin)
            PopupMenuButton<String>(
              icon: ViroIcon(ViroIcons.moreVertical, color: ViroColors.gray600),
              onSelected: (value) {
                switch (value) {
                  case 'role':
                    onChangeRole?.call();
                  case 'remove':
                    onRemove?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Text('Changer le rôle'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Supprimer'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
