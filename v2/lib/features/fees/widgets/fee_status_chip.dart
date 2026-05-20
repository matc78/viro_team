import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';

class FeeStatusChip extends StatelessWidget {
  const FeeStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final MemberFeeDisplayStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
      ),
    );
  }

  (Color, Color) _colors(MemberFeeDisplayStatus status) => switch (status) {
        MemberFeeDisplayStatus.paye => (
            ViroColors.success.withValues(alpha: 0.15),
            ViroColors.success,
          ),
        MemberFeeDisplayStatus.exonere => (
            ViroColors.gray100,
            ViroColors.gray600,
          ),
        MemberFeeDisplayStatus.enRetard => (
            ViroColors.error.withValues(alpha: 0.12),
            ViroColors.error,
          ),
        MemberFeeDisplayStatus.aPayer => (
            ViroColors.warning.withValues(alpha: 0.15),
            ViroColors.warning,
          ),
      };
}
