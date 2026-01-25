/// Utilitaires de formatage pour l'application
class NameFormatter {
  NameFormatter._(); // Constructeur privé pour empêcher l'instanciation

  /// Formate un prénom (première lettre en majuscule, reste en minuscule)
  static String formatFirst(String? firstName) {
    if (firstName == null || firstName.trim().isEmpty) {
      return '';
    }
    final trimmed = firstName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  /// Formate un nom (tout en majuscule)
  static String formatLast(String? lastName) {
    if (lastName == null || lastName.trim().isEmpty) {
      return '';
    }
    return lastName.trim().toUpperCase();
  }

  /// Formate un nom complet (prénom + nom)
  /// 
  /// Exemples:
  /// - format(firstName: "jean", lastName: "DUPONT") -> "Jean DUPONT"
  /// - format(firstName: null, lastName: "DUPONT") -> "DUPONT"
  /// - format(firstName: "jean", lastName: null) -> "Jean"
  /// - format(firstName: null, lastName: null, fallback: "Licencié") -> "Licencié"
  static String format({
    String? firstName,
    String? lastName,
    String fallback = "Licencié",
  }) {
    final fn = formatFirst(firstName);
    final ln = formatLast(lastName);
    
    if (fn.isEmpty && ln.isEmpty) {
      return fallback;
    }
    
    return [fn, ln].where((e) => e.isNotEmpty).join(" ").trim();
  }

  /// Formate un nom depuis des données dynamiques (Map, etc.)
  /// Utile pour formater depuis des données Firestore
  static String formatFromData(
    dynamic firstName,
    dynamic lastName, {
    String fallback = "Licencié",
  }) {
    final fn = (firstName as String?)?.trim();
    final ln = (lastName as String?)?.trim();
    
    if ((fn == null || fn.isEmpty) && (ln == null || ln.isEmpty)) {
      return fallback;
    }
    
    return format(firstName: fn, lastName: ln, fallback: fallback);
  }
}
