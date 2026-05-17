/// Libellés Firestore pour le ciblage des annonces (compatibles v1).
abstract final class AnnouncementTargetTypes {
  static const String tousLesMembres = 'Tous les membres';
  static const String equipes = 'Équipes';
  static const String categories = 'Catégories';

  static const List<String> adminOptions = [
    tousLesMembres,
    equipes,
    categories,
  ];

  static const List<String> coachOptions = [
    equipes,
    categories,
  ];
}
