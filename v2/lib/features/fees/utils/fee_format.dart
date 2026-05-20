import 'package:intl/intl.dart';

/// Formate un montant en centimes en euros (locale FR).
String formatFeeAmountCents(int amountCents) {
  final euros = amountCents / 100;
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  ).format(euros);
}

/// Parse une saisie utilisateur (ex. "180" ou "180,50") en centimes.
int? parseAmountToCents(String input) {
  final trimmed = input.trim().replaceAll(' ', '').replaceAll('€', '');
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll(',', '.');
  final value = double.tryParse(normalized);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}
