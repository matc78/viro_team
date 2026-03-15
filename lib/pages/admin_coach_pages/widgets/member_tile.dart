import 'package:flutter/material.dart';

import '../../../theme/viro_theme.dart';
import '../../../widget/user_display_tile.dart';

/// Tuile par membre : carte lisible avec avatar, nom, rôle, et infos joueur.
///
/// [slideAnimation] est optionnelle : fournie uniquement pour les tiles
/// swipables (supprimables). Quand présente, les tailles du contenu
/// s'adaptent dynamiquement via [AnimatedBuilder] (0 = normal, 1 = compressé).
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

  /// Animation de slide du parent (0 = fermé/taille normale, 1 = ouvert/compressé).
  final Animation<double>? slideAnimation;

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
    this.slideAnimation,
  });

  Widget _roleBadge(
    String label,
    Color color, {
    double fontSize = 12,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _categoryBadge(
    String label,
    Color color, {
    double fontSize = 12,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // Construit le contenu en interpolant les tailles selon [t] (0→1).
  Widget _buildContent(double t) {
    final nameSize = 16.0 - 3.0 * t;          // 16 → 13
    final badgeFontSize = 12.0 - 2.0 * t;     // 12 → 10
    final badgePaddingH = 8.0 - 3.0 * t;      // 8  → 5
    final badgePaddingV = 4.0 - 2.0 * t;      // 4  → 2
    final teamIconSize = 12.0 - 3.0 * t;      // 12 → 9
    final teamFontSize = 12.0 - 2.0 * t;      // 12 → 10
    final avatarGap = 8.0 - 4.0 * t;          // 8  → 4
    // badges : opacité des badges d'équipe disparaissent tôt
    final teamRowOpacity = (1.0 - t * 1.6).clamp(0.0, 1.0);

    final badgePadding = EdgeInsets.symmetric(
      horizontal: badgePaddingH,
      vertical: badgePaddingV,
    );

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
                    textStyle: TextStyle(
                      fontSize: nameSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: avatarGap),
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
                                  constraints: BoxConstraints(
                                    maxWidth: badgesConstraints.maxWidth,
                                  ),
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
                                          fontSize: badgeFontSize,
                                          padding: badgePadding,
                                        )
                                      else ...[
                                        if (categories.isEmpty)
                                          _categoryBadge(
                                            "Sans catégorie",
                                            ViroColors.getMemberBadgeColor(
                                              "Sans catégorie",
                                            ),
                                            fontSize: badgeFontSize,
                                            padding: badgePadding,
                                          )
                                        else
                                          ...categories.map(
                                            (cat) => _categoryBadge(
                                              cat,
                                              ViroColors.getMemberBadgeColor(cat),
                                              fontSize: badgeFontSize,
                                              padding: badgePadding,
                                            ),
                                          ),
                                      ],
                                      if (isPlayer)
                                        _categoryBadge(
                                          hasLicense ? "Licencié" : "Non licencié",
                                          ViroColors.getMemberBadgeColor(
                                            hasLicense ? "Licencié" : "Non licencié",
                                          ),
                                          fontSize: badgeFontSize,
                                          padding: badgePadding,
                                        ),
                                      trailing,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPlayer && teamNames.isNotEmpty && teamRowOpacity > 0) ...[
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: teamRowOpacity,
                              child: Column(
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
                                              size: teamIconSize,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: teamFontSize,
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

  @override
  Widget build(BuildContext context) {
    if (slideAnimation == null) return _buildContent(0.0);
    return AnimatedBuilder(
      animation: slideAnimation!,
      builder: (context, _) => _buildContent(slideAnimation!.value),
    );
  }
}
