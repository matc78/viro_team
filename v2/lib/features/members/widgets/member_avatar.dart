import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/models/club_member.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 44,
  });

  final ClubMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasAccount = member.hasLinkedAccount;

    if (hasAccount && member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(member.avatarUrl!),
      );
    }

    if (hasAccount) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: ViroColors.primary100,
        child: Text(
          member.initials,
          style: TextStyle(
            color: ViroColors.primary800,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.35,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ViroColors.gray100,
        border: Border.all(color: ViroColors.gray300, width: 1.5),
      ),
      alignment: Alignment.center,
      child: ViroIcon(
        ViroIcons.user,
        size: size * 0.45,
        color: ViroColors.gray600,
      ),
    );
  }
}
