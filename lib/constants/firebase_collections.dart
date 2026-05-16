/// Constantes pour les noms de collections Firestore
/// Évite les typos et facilite le refactoring
class FirebaseCollections {
  FirebaseCollections._(); // Constructeur privé pour empêcher l'instanciation

  // Collections principales
  static const String users = 'users';
  static const String clubs = 'clubs';
  static const String teams = 'teams';
  static const String events = 'events';
  static const String joinRequests = 'join_requests';
  static const String announcements = 'announcements';

  // Sous-collections
  static const String members = 'members';
  static const String attendance = 'attendance';
  static const String equipment = 'equipment';
  static const String equipmentCatalog = 'equipmentCatalog';
  static const String equipmentLoans = 'equipment_loans';
  static const String equipmentLoanRequests = 'equipment_loan_requests';
  static const String equipmentLoanChangeRequests =
      'equipment_loan_change_requests';
  static const String memberLeaves = 'member_leaves';

  /// Sous-collection des retraits par un admin (quota 1 coach/player par jour)
  static const String memberRemovals = 'member_removals';

  /// Sous-collection des membres en attente de création de compte (email, prénom, nom)
  static const String pendingMembers = 'pending_members';

  /// Sous-collection des liens d'invite pour création de compte (token, pendingMemberId, email, etc.)
  static const String inviteLinks = 'invite_links';

  /// Sous-collection des présences réelles lors des entraînements (un doc par joueur par event)
  static const String trainingAttendances = 'training_attendances';

  /// Sous-collection sous users/{uid} pour l'état de modération avatar (un doc par user)
  static const String avatarModeration = 'avatar_moderation';

  /// ID du document unique dans avatar_moderation (état courant)
  static const String avatarModerationStateDocId = 'state';

  /// Cotisations : saisons sous clubs/{clubId}/fee_seasons/{seasonId}
  static const String feeSeasons = 'fee_seasons';

  /// Cotisations : suivi par joueur sous clubs/{clubId}/fee_seasons/{seasonId}/member_fees/{uid}
  static const String memberFees = 'member_fees';

  // Legacy (données avant le multi-saisons — conservées pour compatibilité)
  /// @deprecated Utiliser [feeSeasons] à la place
  static const String feeSettings = 'fee_settings';

  /// @deprecated Utiliser [feeSeasons] à la place
  static const String feeSettingsDefaultDocId = 'default';

  // Tournois & Championnats
  /// Collection principale : clubs/{clubId}/tournaments/{tournamentId}
  static const String tournaments = 'tournaments';

  /// Sous-collection équipes d'un tournoi
  static const String tournamentTeams = 'tournament_teams';

  /// Sous-collection matchs d'un tournoi
  static const String tournamentMatches = 'tournament_matches';

  /// Sous-collection phases d'un tournoi
  static const String tournamentPhases = 'tournament_phases';
}
