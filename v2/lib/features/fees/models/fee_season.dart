import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/fees/models/fee_tier.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';

class FeeSeason {
  const FeeSeason({
    required this.id,
    required this.seasonLabel,
    required this.isActive,
    this.currency = 'EUR',
    this.paymentDeadlineAt,
    this.paymentInstructions = '',
    this.paymentMethods = const [],
    this.iban,
    required this.tiers,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  final String id;
  final String seasonLabel;
  final bool isActive;
  final String currency;
  final DateTime? paymentDeadlineAt;
  final String paymentInstructions;
  final List<String> paymentMethods;
  final String? iban;
  final List<FeeTier> tiers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory FeeSeason.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawTiers = (d[FirestoreFields.tiers] as List?)?.whereType<Map>().toList() ?? [];
    return FeeSeason(
      id: doc.id,
      seasonLabel: d[FirestoreFields.seasonLabel] as String? ?? '',
      isActive: d[FirestoreFields.isActive] as bool? ?? false,
      currency: d[FirestoreFields.currency] as String? ?? 'EUR',
      paymentDeadlineAt:
          (d[FirestoreFields.paymentDeadlineAt] as Timestamp?)?.toDate(),
      paymentInstructions:
          d[FirestoreFields.paymentInstructions] as String? ?? '',
      paymentMethods: (d[FirestoreFields.paymentMethods] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      iban: d[FirestoreFields.iban] as String?,
      tiers: rawTiers
          .map((e) => FeeTier.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt:
          (d[FirestoreFields.createdAt] as Timestamp?)?.toDate() ??
              DateTime.now(),
      updatedAt:
          (d[FirestoreFields.updatedAt] as Timestamp?)?.toDate() ??
              DateTime.now(),
      createdBy: d[FirestoreFields.createdBy] as String? ?? '',
    );
  }

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

  FeeTier? tierById(String? tierId) {
    if (tierId == null) return null;
    for (final t in tiers) {
      if (t.tierId == tierId) return t;
    }
    return null;
  }

  /// Payload pour création (`set` sans merge) — ne pas utiliser [FieldValue.delete].
  Map<String, dynamic> toFirestoreCreate() => {
        FirestoreFields.seasonLabel: seasonLabel,
        FirestoreFields.isActive: isActive,
        FirestoreFields.currency: currency,
        FirestoreFields.paymentInstructions: paymentInstructions,
        FirestoreFields.paymentMethods: paymentMethods,
        FirestoreFields.tiers: tiers.map((t) => t.toMap()).toList(),
        FirestoreFields.createdAt: FieldValue.serverTimestamp(),
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        FirestoreFields.createdBy: createdBy,
        if (paymentDeadlineAt != null)
          FirestoreFields.paymentDeadlineAt:
              Timestamp.fromDate(paymentDeadlineAt!),
        if (iban != null && iban!.trim().isNotEmpty)
          FirestoreFields.iban: iban!.trim(),
      };

  Map<String, dynamic> toFirestoreUpdate() => {
        FirestoreFields.seasonLabel: seasonLabel,
        FirestoreFields.currency: currency,
        FirestoreFields.paymentInstructions: paymentInstructions,
        FirestoreFields.paymentMethods: paymentMethods,
        FirestoreFields.tiers: tiers.map((t) => t.toMap()).toList(),
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        if (paymentDeadlineAt != null)
          FirestoreFields.paymentDeadlineAt:
              Timestamp.fromDate(paymentDeadlineAt!)
        else
          FirestoreFields.paymentDeadlineAt: FieldValue.delete(),
        if (iban != null && iban!.trim().isNotEmpty)
          FirestoreFields.iban: iban!.trim()
        else
          FirestoreFields.iban: FieldValue.delete(),
      };
}

/// Stats agrégées pour le header admin.
class FeeStats {
  const FeeStats({
    required this.total,
    required this.paid,
    required this.exempt,
    required this.pending,
    required this.overdue,
  });

  final int total;
  final int paid;
  final int exempt;
  final int pending;
  final int overdue;

  int get awaiting => pending + overdue;

  double get paidPercent => total > 0 ? paid / total : 0;

  static FeeStats compute(
    List<MemberFee> fees,
    DateTime? deadline,
  ) {
    var paid = 0;
    var exempt = 0;
    var pending = 0;
    var overdue = 0;
    for (final f in fees) {
      switch (f.displayStatus(deadline)) {
        case MemberFeeDisplayStatus.paye:
          paid++;
        case MemberFeeDisplayStatus.exonere:
          exempt++;
        case MemberFeeDisplayStatus.enRetard:
          overdue++;
        case MemberFeeDisplayStatus.aPayer:
          pending++;
      }
    }
    return FeeStats(
      total: fees.length,
      paid: paid,
      exempt: exempt,
      pending: pending,
      overdue: overdue,
    );
  }
}
