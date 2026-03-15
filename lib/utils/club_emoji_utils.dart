/// Utilitaires pour afficher les emojis des clubs selon leur sport.
library;

/// Émoji selon le sport du club ; sport null ou vide → pas d'émoji, "Autre" ou inconnu → ❓
String sportToEmoji(String? sport) {
  if (sport == null || sport.isEmpty) return '';
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
/// Si le sport est null ou vide, retourne uniquement le nom du club.
String formatClubNameWithEmoji(String clubName, String? sport) {
  final emoji = sportToEmoji(sport);
  if (emoji.isEmpty) return clubName;
  return '$emoji $clubName';
}
