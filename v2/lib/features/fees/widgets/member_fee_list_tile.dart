import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';
import 'package:viro_team_v2/features/fees/widgets/fee_status_chip.dart';

class MemberFeeListTile extends StatelessWidget {
  const MemberFeeListTile({
    super.key,
    required this.fee,
    required this.season,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final MemberFee fee;
  final FeeSeason season;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final display = fee.displayStatus(season.paymentDeadlineAt);
    final tier = season.tierById(fee.tierId);
    final tierLabel = tier?.label ?? 'Non assigné';
    final amount = fee.status == MemberFeeStatus.exonere
        ? '—'
        : formatFeeAmountCents(fee.amountDueCents(season));

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
            )
          : CircleAvatar(
              child: Text(
                fee.memberDisplayName.isNotEmpty
                    ? fee.memberDisplayName[0].toUpperCase()
                    : '?',
              ),
            ),
      title: Text(
        fee.memberDisplayName,
        style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$tierLabel · $amount'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FeeStatusChip(status: display, compact: true),
          const SizedBox(width: ViroSpacing.xs),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}
