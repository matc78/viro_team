import 'package:intl/intl.dart';

final _dateFormat = DateFormat('EEE dd/MM', 'fr_FR');
final _weekdayFormat = DateFormat('EEEE', 'fr_FR');
final _dayMonthFormat = DateFormat('d/MM', 'fr_FR');
final _timeFormat = DateFormat('HH\'h\'mm', 'fr_FR');
final _relativeFormat = DateFormat.yMMMd('fr_FR');

String _capitalizeFr(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatEventDate(DateTime date) => _dateFormat.format(date);

/// Jour de la semaine en toutes lettres (ex. « Lundi »).
String formatWeekdayLong(DateTime date) =>
    _capitalizeFr(_weekdayFormat.format(date));

/// Jour et mois numériques (ex. « 20/05 »).
String formatDayMonth(DateTime date) => _dayMonthFormat.format(date);

/// Écart en jours calendaires entre [date] et aujourd'hui (positif = futur).
int planningDaysFromToday(DateTime date) {
  final dayOnly = _dateOnly(date);
  final today = _dateOnly(DateTime.now());
  return dayOnly.difference(today).inDays;
}

/// Libellé discret de l'écart (ex. « +3 », « -2 »). Null si aujourd'hui.
String? formatPlanningDayOffset(int daysFromToday) {
  if (daysFromToday == 0) return null;
  if (daysFromToday > 0) return '+$daysFromToday';
  return '$daysFromToday';
}

/// Parties d'un en-tête de jour du planning global.
({
  String? badge,
  String weekday,
  int day,
  String month,
  int daysFromToday,
  String? dayOffsetLabel,
}) planningDayHeaderParts(DateTime date) {
  final dayOnly = _dateOnly(date);
  final today = _dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final daysFromToday = planningDaysFromToday(dayOnly);

  String? badge;
  if (dayOnly == today) {
    badge = "Aujourd'hui";
  } else if (dayOnly == tomorrow) {
    badge = 'Demain';
  }

  return (
    badge: badge,
    weekday: formatWeekdayLong(dayOnly),
    day: dayOnly.day,
    month: _capitalizeFr(DateFormat('MMMM', 'fr_FR').format(dayOnly)),
    daysFromToday: daysFromToday,
    dayOffsetLabel: formatPlanningDayOffset(daysFromToday),
  );
}

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
