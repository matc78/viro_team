import 'package:flutter/material.dart';

import '../../models/tournament/tournament_phase.dart';
import '../../models/tournament/tournament_team.dart';
import '../../theme/viro_theme.dart';

class GroupTableWidget extends StatelessWidget {
  final List<GroupStanding> standings;
  final Map<String, TournamentTeam> teamsById;
  final int nbQualified;
  final String? groupLabel;

  const GroupTableWidget({
    super.key,
    required this.standings,
    required this.teamsById,
    required this.nbQualified,
    this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groupLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                groupLabel!,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ViroColors.primary),
              ),
            ),
          // Header
          _buildHeader(),
          const Divider(height: 1),
          // Rows
          ...standings.asMap().entries.map((e) {
            final rank = e.key + 1;
            final standing = e.value;
            final isQualified = rank <= nbQualified;
            return _buildRow(standing, rank, isQualified);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 22), // rang
          const Expanded(child: SizedBox()),
          _headerCell('Pts', bold: true),
          _headerCell('J'),
          _headerCell('V'),
          _headerCell('N'),
          _headerCell('D'),
          _headerCell('BP'),
          _headerCell('BC'),
          _headerCell('Diff'),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {bool bold = false}) {
    return SizedBox(
      width: 30,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildRow(GroupStanding s, int rank, bool isQualified) {
    final team = teamsById[s.teamId];
    final name = team?.name ?? s.teamId;

    Color teamColor;
    try {
      final hex = (team?.colorHex ?? '#888888').replaceAll('#', '');
      teamColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      teamColor = Colors.grey;
    }

    return Container(
      color: isQualified
          ? ViroColors.primary.withValues(alpha: 0.04)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isQualified ? ViroColors.primary : Colors.grey[500],
              ),
            ),
          ),
          // Nom équipe
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isQualified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_upward,
                      size: 10, color: ViroColors.success),
                ],
              ],
            ),
          ),
          _cell('${s.points}', bold: true),
          _cell('${s.gamesPlayed}'),
          _cell('${s.wins}'),
          _cell('${s.draws}'),
          _cell('${s.losses}'),
          _cell('${s.goalsFor}'),
          _cell('${s.goalsAgainst}'),
          _cell(
            '${s.goalDiff >= 0 ? '+' : ''}${s.goalDiff}',
            color: s.goalDiff > 0
                ? ViroColors.success
                : s.goalDiff < 0
                    ? ViroColors.error
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, {bool bold = false, Color? color}) {
    return SizedBox(
      width: 30,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}
