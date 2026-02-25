/// Utilitaires pour afficher les emojis des clubs selon leur sport.
library;

/// Émoji selon le sport du club ; "Autre" ou inconnu → ❓
String sportToEmoji(String? sport) {
  if (sport == null || sport.isEmpty) return '❓';
  if (sport.toLowerCase() == 'autre') return '❓';
  switch (sport) {
    case 'Football':
      return '⚽';
    case 'Basketball':
      return '🏀';
    case 'Tennis':
      return '🎾';
    case 'Volleyball':
      return '🏐';
    case 'Handball':
      return '🤾';
    case 'Rugby':
      return '🏉';
    case 'Judo':
      return '🤼';
    case 'Natation':
      return '🏊';
    default:
      return '❓';
  }
}

/// Retourne le nom du club avec son emoji de sport en préfixe.
/// Ex: "FC Paris" + "Football" → "⚽ FC Paris"
String formatClubNameWithEmoji(String clubName, String? sport) {
  final emoji = sportToEmoji(sport);
  return '$emoji $clubName';
}
