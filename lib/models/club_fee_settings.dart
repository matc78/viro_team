import 'package:cloud_firestore/cloud_firestore.dart';

/// Palier tarifaire (grille de cotisation).
class FeeTier {
  final String tierId;
  final String label;
  final int amountCents;
  final String? description;

  const FeeTier({
    required this.tierId,
    required this.label,
    required this.amountCents,
    this.description,
  });

  factory FeeTier.fromMap(Map<String, dynamic> m) {
    return FeeTier(
      tierId: m['tierId'] as String? ?? '',
      label: m['label'] as String? ?? '',
      amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
      description: m['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'tierId': tierId,
    'label': label,
    'amountCents': amountCents,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };
}

/// Paramètres de cotisation du club (`fee_settings/default`).
class ClubFeeSettings {
  final String seasonLabel;
  final String paymentInstructions;
  final List<FeeTier> tiers;
  final String currency;

  /// Dernier jour inclus pour le paiement (passé ce jour calendaire → « en retard » si solde > 0).
  final DateTime? paymentDeadlineAt;
  final DateTime? updatedAt;

  const ClubFeeSettings({
    required this.seasonLabel,
    required this.paymentInstructions,
    required this.tiers,
    this.currency = 'EUR',
    this.paymentDeadlineAt,
    this.updatedAt,
  });

  factory ClubFeeSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawTiers = (d['tiers'] as List?)?.whereType<Map>().toList() ?? [];
    return ClubFeeSettings(
      seasonLabel: d['seasonLabel'] as String? ?? '',
      paymentInstructions: d['paymentInstructions'] as String? ?? '',
      tiers: rawTiers
          .map((e) => FeeTier.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      currency: d['currency'] as String? ?? 'EUR',
      paymentDeadlineAt: (d['paymentDeadlineAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Après le jour calendaire de [paymentDeadlineAt] (à partir du lendemain), le solde est « en retard ».
  bool isPaymentDeadlineElapsed([DateTime? clock]) {
    if (paymentDeadlineAt == null) return false;
    final now = clock ?? DateTime.now();
    final end = DateTime(
      paymentDeadlineAt!.year,
      paymentDeadlineAt!.month,
      paymentDeadlineAt!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(end);
  }

  Map<String, dynamic> toFirestore() => {
    'seasonLabel': seasonLabel,
    'paymentInstructions': paymentInstructions,
    'tiers': tiers.map((t) => t.toMap()).toList(),
    'currency': currency,
    if (paymentDeadlineAt != null)
      'paymentDeadlineAt': Timestamp.fromDate(paymentDeadlineAt!)
    else
      'paymentDeadlineAt': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
