import 'package:intl/intl.dart';

final _dateFormat = DateFormat('EEE dd/MM', 'fr_FR');
final _timeFormat = DateFormat('HH\'h\'mm', 'fr_FR');
final _relativeFormat = DateFormat.yMMMd('fr_FR');

String formatEventDate(DateTime date) => _dateFormat.format(date);

String formatEventTime(String? startTime) {
  if (startTime == null || startTime.isEmpty) return '';
  final parts = startTime.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return _timeFormat.format(DateTime(2000, 1, 1, h, m));
  }
  return startTime;
}

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays == 0) return "Aujourd'hui";
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? 'Il y a 1 semaine' : 'Il y a $weeks semaines';
  }
  return _relativeFormat.format(date);
}

String eventTypeLabel(String type) => switch (type) {
      'training' => 'Entraînement',
      'match' => 'Match',
      'tournament' => 'Tournoi',
      _ => 'Événement',
    };
