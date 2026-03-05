import 'package:flutter/material.dart';

import '../../../theme/viro_theme.dart';
import '../../../widget/user_display_tile.dart';

/// Tuile par membre : carte lisible avec avatar, nom, rôle, et infos joueur (catégories, équipe, licence).
class MemberTile extends StatelessWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String roleLabel;
  final bool isPlayer;
  final bool isStaff;
  final List<String> categories;
  final List<String> teamNames;
  final bool hasLicense;
  final Widget trailing;
  final VoidCallback onTap;

  const MemberTile({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.roleLabel,
    required this.isPlayer,
    required this.isStaff,
    required this.categories,
    required this.teamNames,
    required this.hasLicense,
    required this.trailing,
    required this.onTap,
  });

  Widget _roleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _categoryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ViroColors.borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 0,
                  fit: FlexFit.loose,
                  child: UserDisplayTile(
                    userId: userId,
                    firstName: firstName,
                    lastName: lastName,
                    avatarUrl: avatarUrl,
                    navigateOnTap: false,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, badgesConstraints) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: badgesConstraints.maxWidth),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                alignment: WrapAlignment.end,
                                runAlignment: WrapAlignment.end,
                                children: [
                        if (isStaff)
                          _roleBadge(
                            roleLabel,
                            ViroColors.getMemberBadgeColor(roleLabel),
                          )
                        else ...[
                          if (categories.isEmpty)
                            _categoryBadge(
                              "Sans catégorie",
                              ViroColors.getMemberBadgeColor(
                                "Sans catégorie",
                              ),
                            )
                          else
                            ...categories.map(
                              (cat) => _categoryBadge(
                                cat,
                                ViroColors.getMemberBadgeColor(cat),
                              ),
                            ),
                        ],
                        if (isPlayer)
                          _categoryBadge(
                            hasLicense ? "Licencié" : "Non licencié",
                            ViroColors.getMemberBadgeColor(
                              hasLicense ? "Licencié" : "Non licencié",
                            ),
                          ),
                        trailing,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isPlayer && teamNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: teamNames
                            .map(
                              (name) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    ],
                  );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
