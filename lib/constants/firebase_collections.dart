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
}
