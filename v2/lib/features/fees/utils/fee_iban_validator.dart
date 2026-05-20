/// Validation format IBAN (basique, sans vérification bancaire).
bool isValidIbanFormat(String? iban) {
  if (iban == null || iban.trim().isEmpty) return true;
  final compact = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (compact.length < 15 || compact.length > 34) return false;
  return RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(compact);
}

String normalizeIban(String iban) =>
    iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
