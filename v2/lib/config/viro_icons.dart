import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Icônes sémantiques ViroTeam — [Phosphor Icons](https://phosphoricons.com).
///
/// Utiliser [ViroIcon] dans l'UI, pas `Icons.*` ni `PhosphorIcon` directement
/// dans les écrans (sauf ce fichier).
abstract final class ViroIcons {
  // Navigation & chrome
  static IconData get menu => PhosphorIconsRegular.list;
  static IconData get settings => PhosphorIconsRegular.gear;
  static IconData get add => PhosphorIconsBold.plus;
  static IconData get arrowUp => PhosphorIconsRegular.arrowUp;
  static IconData get chevronRight => PhosphorIconsRegular.caretRight;
  static IconData get chevronLeft => PhosphorIconsRegular.caretLeft;
  static IconData get close => PhosphorIconsRegular.x;

  // Lieux & planning
  static IconData get place => PhosphorIconsRegular.mapPin;
  static IconData get calendar => PhosphorIconsRegular.calendar;
  static IconData get clock => PhosphorIconsRegular.clock;

  // Sport & équipe
  static IconData get ball => PhosphorIconsFill.soccerBall;
  static IconData get trophy => PhosphorIconsFill.trophy;
  static IconData get users => PhosphorIconsRegular.users;
  static IconData get whistle => PhosphorIconsRegular.megaphoneSimple;

  // Actions
  static IconData get edit => PhosphorIconsRegular.pencilSimple;
  static IconData get trash => PhosphorIconsRegular.trash;
  static IconData get check => PhosphorIconsBold.check;
  static IconData get search => PhosphorIconsRegular.magnifyingGlass;
  static IconData get copy => PhosphorIconsRegular.copy;
  static IconData get moreVertical => PhosphorIconsRegular.dotsThreeVertical;

  // Compte
  static IconData get user => PhosphorIconsRegular.user;
  static IconData get logout => PhosphorIconsRegular.signOut;
  static IconData get bell => PhosphorIconsRegular.bell;

  // Rôles (badges)
  static IconData get rolePlayer => PhosphorIconsFill.soccerBall;
  static IconData get roleCoach => PhosphorIconsFill.megaphoneSimple;
  static IconData get roleParent => PhosphorIconsFill.usersThree;
  static IconData get roleAdmin => PhosphorIconsFill.shieldCheck;

  /// Catalogue pour l'écran design system (groupé).
  static List<ViroIconCatalogGroup> get catalog => [
        ViroIconCatalogGroup(
          title: 'Navigation & chrome',
          icons: [
            ('menu', menu),
            ('settings', settings),
            ('add', add),
            ('arrowUp', arrowUp),
            ('chevronRight', chevronRight),
            ('close', close),
          ],
        ),
        ViroIconCatalogGroup(
          title: 'Lieux & planning',
          icons: [
            ('place', place),
            ('calendar', calendar),
            ('clock', clock),
          ],
        ),
        ViroIconCatalogGroup(
          title: 'Sport & équipe',
          icons: [
            ('ball', ball),
            ('trophy', trophy),
            ('users', users),
            ('whistle', whistle),
          ],
        ),
        ViroIconCatalogGroup(
          title: 'Actions',
          icons: [
            ('edit', edit),
            ('trash', trash),
            ('check', check),
            ('search', search),
          ],
        ),
        ViroIconCatalogGroup(
          title: 'Compte',
          icons: [
            ('user', user),
            ('logout', logout),
            ('bell', bell),
          ],
        ),
        ViroIconCatalogGroup(
          title: 'Rôles (badges)',
          icons: [
            ('rolePlayer', rolePlayer),
            ('roleCoach', roleCoach),
            ('roleParent', roleParent),
            ('roleAdmin', roleAdmin),
          ],
        ),
      ];
}

/// Entrée du catalogue d'icônes (aperçu thème).
class ViroIconCatalogGroup {
  const ViroIconCatalogGroup({
    required this.title,
    required this.icons,
  });

  final String title;
  final List<(String name, IconData icon)> icons;
}

/// Rendu standard des icônes Phosphor dans l'app.
class ViroIcon extends StatelessWidget {
  const ViroIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF0B3358);

    return Semantics(
      label: semanticLabel,
      child: PhosphorIcon(
        icon,
        size: size,
        color: resolvedColor,
      ),
    );
  }
}
