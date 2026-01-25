/// Helpers pour la gestion du matériel et équipement (inventaire, prêts, suggestions par sport).
class EquipmentHelpers {
  EquipmentHelpers._();

  // États possibles
  static const String conditionBon = 'bon';
  static const String conditionUse = 'use';
  static const String conditionMaintenance = 'maintenance';
  static const String conditionHorsService = 'hors_service';

  static const List<String> conditions = [
    conditionBon,
    conditionUse,
    conditionMaintenance,
    conditionHorsService,
  ];

  static String conditionLabel(String value) {
    switch (value) {
      case conditionBon:
        return 'Bon';
      case conditionUse:
        return 'Usé';
      case conditionMaintenance:
        return 'En maintenance';
      case conditionHorsService:
        return 'Hors service';
      default:
        return value;
    }
  }

  // Disponibilité
  static const String availabilityDisponible = 'disponible';
  static const String availabilityPrete = 'prete';
  static const String availabilityMaintenance = 'maintenance';

  static const List<String> availabilities = [
    availabilityDisponible,
    availabilityPrete,
    availabilityMaintenance,
  ];

  static String availabilityLabel(String value) {
    switch (value) {
      case availabilityDisponible:
        return 'Disponible';
      case availabilityPrete:
        return 'Prêté';
      case availabilityMaintenance:
        return 'En maintenance';
      default:
        return value;
    }
  }

  // Unités
  static const String unitPiece = 'pièce';
  static const String unitLot = 'lot';
  static const String unitPaire = 'paire';

  static const List<String> units = [unitPiece, unitLot, unitPaire];

  static String unitLabel(String value) {
    switch (value) {
      case unitPiece:
        return 'pièce';
      case unitLot:
        return 'lot';
      case unitPaire:
        return 'paire';
      default:
        return value;
    }
  }

  /// Suggestions de matériel de base selon le sport du club.
  static List<Map<String, dynamic>> getDefaultEquipmentBySport(String? sport) {
    final s = (sport ?? '').toLowerCase().trim();
    switch (s) {
      case 'football':
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Shorts', 'category': 'Shorts', 'unit': unitLot},
          {'name': 'Chaussettes', 'category': 'Chaussettes', 'unit': unitPaire},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Plots', 'category': 'Plots', 'unit': unitLot},
          {'name': 'Cônes', 'category': 'Cônes', 'unit': unitLot},
          {'name': 'Filets (cages)', 'category': 'Filets', 'unit': unitPiece},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
        ];
      case 'basketball':
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Shorts', 'category': 'Shorts', 'unit': unitLot},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Plots', 'category': 'Plots', 'unit': unitLot},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
          {'name': 'Paniers portables', 'category': 'Paniers', 'unit': unitPiece},
        ];
      case 'volleyball':
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Filet', 'category': 'Filets', 'unit': unitPiece},
          {'name': 'Genouillères', 'category': 'Protections', 'unit': unitPaire},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
        ];
      case 'handball':
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Shorts', 'category': 'Shorts', 'unit': unitLot},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
          {'name': 'Filets (buts)', 'category': 'Filets', 'unit': unitPiece},
        ];
      case 'rugby':
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Shorts', 'category': 'Shorts', 'unit': unitLot},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Plots', 'category': 'Plots', 'unit': unitLot},
          {'name': 'Cônes', 'category': 'Cônes', 'unit': unitLot},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
          {'name': 'Protège-dents', 'category': 'Protections', 'unit': unitPiece},
        ];
      case 'tennis':
        return [
          {'name': 'Raquettes', 'category': 'Raquettes', 'unit': unitPiece},
          {'name': 'Balles', 'category': 'Balles', 'unit': unitLot},
          {'name': 'Filet', 'category': 'Filets', 'unit': unitPiece},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
        ];
      case 'judo':
        return [
          {'name': 'Kimono', 'category': 'Kimono', 'unit': unitPiece},
          {'name': 'Ceintures', 'category': 'Ceintures', 'unit': unitLot},
          {'name': 'Tapis', 'category': 'Tapis', 'unit': unitPiece},
          {'name': 'Zori', 'category': 'Chaussures', 'unit': unitPaire},
        ];
      case 'natation':
        return [
          {'name': 'Lunettes', 'category': 'Lunettes', 'unit': unitPiece},
          {'name': 'Bonnets', 'category': 'Bonnets', 'unit': unitPiece},
          {'name': 'Pull-buoys', 'category': 'Accessoires', 'unit': unitPiece},
          {'name': 'Palmes', 'category': 'Palmes', 'unit': unitPaire},
          {'name': 'Planches', 'category': 'Planches', 'unit': unitPiece},
          {'name': 'Paddles', 'category': 'Accessoires', 'unit': unitPaire},
        ];
      default:
        return [
          {'name': 'Maillots', 'category': 'Maillots', 'unit': unitLot},
          {'name': 'Ballons', 'category': 'Ballons', 'unit': unitPiece},
          {'name': 'Chasubles', 'category': 'Chasubles', 'unit': unitLot},
          {'name': 'Plots', 'category': 'Plots', 'unit': unitLot},
        ];
    }
  }
}
