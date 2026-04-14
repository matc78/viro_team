import 'package:flutter/material.dart';

import '../models/member_fee.dart';
import '../theme/viro_theme.dart';

/// Couleur de fond pour un chip/badge de statut de cotisation.
Color feeStatusColor(MemberFeeStatus s) {
  switch (s) {
    case MemberFeeStatus.nonConfigure:
      return Colors.grey.shade200;
    case MemberFeeStatus.exonere:
      return Colors.blueGrey.shade100;
    case MemberFeeStatus.aPayer:
      return Colors.orange.shade100;
    case MemberFeeStatus.partiel:
      return Colors.amber.shade100;
    case MemberFeeStatus.paye:
      return Colors.green.shade100;
    case MemberFeeStatus.enRetard:
      return Colors.red.shade100;
  }
}

/// Couleur de texte/icône pour un statut de cotisation.
Color feeStatusTextColor(MemberFeeStatus s) {
  switch (s) {
    case MemberFeeStatus.nonConfigure:
      return Colors.grey.shade700;
    case MemberFeeStatus.exonere:
      return Colors.blueGrey.shade700;
    case MemberFeeStatus.aPayer:
      return Colors.orange.shade800;
    case MemberFeeStatus.partiel:
      return Colors.amber.shade900;
    case MemberFeeStatus.paye:
      return ViroColors.success;
    case MemberFeeStatus.enRetard:
      return ViroColors.error;
  }
}

/// Icône associée à un statut de cotisation.
IconData feeStatusIcon(MemberFeeStatus s) {
  switch (s) {
    case MemberFeeStatus.nonConfigure:
      return Icons.help_outline;
    case MemberFeeStatus.exonere:
      return Icons.volunteer_activism_outlined;
    case MemberFeeStatus.aPayer:
      return Icons.schedule_outlined;
    case MemberFeeStatus.partiel:
      return Icons.hourglass_bottom_outlined;
    case MemberFeeStatus.paye:
      return Icons.check_circle_outline;
    case MemberFeeStatus.enRetard:
      return Icons.warning_amber_rounded;
  }
}

/// Chip de statut cotisation réutilisable.
class FeeStatusChip extends StatelessWidget {
  final MemberFeeStatus status;
  final double fontSize;

  const FeeStatusChip({super.key, required this.status, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final bg = feeStatusColor(status);
    final fg = feeStatusTextColor(status);
    final icon = feeStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
