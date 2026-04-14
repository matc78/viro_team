import 'package:intl/intl.dart';

String formatEurosFromCents(int cents) {
  final euros = cents / 100.0;
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  ).format(euros);
}

/// Parse une saisie type "12,50" ou "12.5" → centimes.
int? parseEurosStringToCents(String raw) {
  final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return 0;
  final v = double.tryParse(t);
  if (v == null) return null;
  return (v * 100).round();
}
