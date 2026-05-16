import 'package:flutter/foundation.dart';

/// Configuration centrale du projet ViroTeam v2.
///
/// Référence humaine complète : [PROJECT_CONVENTIONS.md] à la racine de `v2/`.
/// Thème détaillé : section « Thème & harmonisation visuelle » du même fichier.
abstract final class ProjectConfig {
  static const String appName = 'ViroTeam';

  // —— Firestore ——
  static const String firestoreDevDatabaseId = 'v2-dev';
  static const String firestoreProdDatabaseId = 'v2-prod';

  static String get firestoreDatabaseId =>
      kReleaseMode ? firestoreProdDatabaseId : firestoreDevDatabaseId;

  static const String firebaseProjectId = 'viroteam-75303';

  // —— Specs (racine monorepo, relatif à v2/) ——
  static const String firestoreModelDoc = '../viroteam_v2_firestore_model.md';
  static const String uxJourneyDoc = '../viroheam_v2_ux_journey_detailed.md';
  static const String invitationModelDoc =
      '../viroheam_v2_invitation_only_model.md';

  // —— Collections Firestore (voir firestoreModelDoc) ——
  static const String usersCollection = 'users';
  static const String clubsCollection = 'clubs';
  static const String membersSubcollection = 'members';
  static const String memberAccountsSubcollection = 'member_accounts';
  static const String invitationsSubcollection = 'invitations';
  static const String joinRequestsCollection = 'join_requests';
  static const String retourUserCollection = 'retour_user';
  static const String eventsSubcollection = 'events';
  static const String announcementsSubcollection = 'announcements';
  static const String teamsSubcollection = 'teams';
  static const String pendingMembersSubcollection = 'pending_members';

  // —— Chemins code ——
  static const String legacyLibPath = '../lib';
  static const String configPath = 'lib/config';
  static const String widgetsPath = 'lib/widgets';
  static const String listTilesPath = 'lib/widgets/lists';

  // —— Thème (fichiers source de vérité) ——
  static const String themeEntry = 'lib/config/viro_theme.dart';
  static const String colorsEntry = 'lib/config/viro_colors.dart';
  static const String motionEntry = 'lib/config/viro_motion.dart';
  static const String iconsEntry = 'lib/config/viro_icons.dart';

  /// Shell obligatoire pour tout écran (fond dégradé + halos).
  static const String scaffoldWidget = 'lib/widgets/common/viro_scaffold.dart';

  /// En-tête claire — pas de AppBar bleue opaque.
  static const String appBarWidget = 'lib/widgets/common/viro_scaffold.dart';

  static const String cardWidget = 'lib/widgets/common/viro_card.dart';
  static const String roleBadgeWidget =
      'lib/widgets/common/viro_role_badge.dart';

  /// Règle : ne pas utiliser primary800+ comme fond plein écran / AppBar.
  static const bool forbidOpaquePrimaryAppBar = true;

  // —— Mise en page ——
  /// Largeur max du contenu centré (formulaires, cartes, grilles, états vides).
  static const double contentMaxWidth = 560;

  /// Contenu centré horizontalement sur grands écrans (tablette / web).
  /// Exceptions : listes longues scrollables (planning, membres, messages…)
  /// qui restent en pleine largeur avec padding [ViroSpacing.screenHorizontal].
  static const bool centerContentByDefault = true;

  // —— Feedback utilisateur ——
  /// Durée max des SnackBar (messages d'action, copie, erreurs légères).
  static const Duration snackBarDuration = Duration(milliseconds: 1500);

  // —— Rôles & permissions ——
  //
  // Hiérarchie club (héritage cumulatif) :
  //   Admin ⊃ Coach ⊃ Player
  // Un coach EST un joueur avec plus de droits.
  // Un admin EST un coach (donc aussi joueur) avec plus de droits.
  //
  // Parent ≠ rôle club. C'est une RELATION optionnelle sur l'utilisateur :
  //   users/{uid}.parentLinks: [
  //     { childUid, permissions, revokedAt }
  //   ]
  // « Je suis parent DE Marie » — pas un 4e rôle dans clubMemberships.
  //
  // AVANT (faux) : roles: ['player', 'coach', 'admin', 'parent']
  // APRÈS (bon)  : clubMemberships.role ∈ {player, coach, admin}
  //                + parentLinks pour le lien parent ↔ enfant
  //
  // Voir [MemberRoles], [MemberRoleHierarchy] et [FirestoreFields.parentLinks].

  /// Rôles possibles dans `clubMemberships` / `members/{uid}.role`.
  static const List<String> clubMemberRoles = ['player', 'coach', 'admin'];

  /// Champ utilisateur : liens parent → enfant (relation, pas rôle global).
  static const String parentLinksField = 'parentLinks';

  /// Résumé hiérarchie — Admin hérite de tout ce que Coach peut faire, etc.
  static const String roleInheritanceRule =
      'Admin hérite de Coach ; Coach hérite de Player.';

  // —— Player (base) ——
  static const String permPlayerPlanning = 'Voir son planning, RSVP';
  static const String permPlayerTeam = 'Voir son équipe';
  static const String permPlayerInviteParent =
      'Inviter des parents pour lui-même';
  static const String permPlayerRevokeParent =
      'Révoquer ses propres parents';

  // —— Coach (= Player +) ——
  static const String permCoachEvents = 'Créer événements, marquer présence';
  static const String permCoachTeam = 'Gérer sa propre équipe';
  static const String permCoachInvitePlayers =
      'Inviter des joueurs pour ses équipes';

  // —— Admin (= Coach +) ——
  static const String permAdminAll = 'Peut tout faire dans le club';
  static const String permAdminInvite =
      'Inviter joueurs, entraîneurs, admins';
  static const String permAdminRevoke = 'Révoquer n\'importe qui';

  // —— Parent (relation, pas rôle club) ——
  static const String permParentView =
      'Voir le planning de l\'enfant (si permission)';
  static const String permParentRsvp =
      'RSVP pour l\'enfant (si permission)';
  static const String permParentCannot =
      'Ne peut pas créer d\'événements ni gérer l\'équipe';
  static const String permParentInvitedBy =
      'Invité par l\'enfant lui-même';
  static const String permParentRevokedBy =
      'Révocable par l\'enfant (ou admin)';
  static const String permParentAlsoMember =
      'Peut aussi être joueur / coach / admin dans le même club';
}
