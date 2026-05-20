import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';

class FeeTier {
  const FeeTier({
    required this.tierId,
    required this.label,
    required this.amountCents,
  });

  final String tierId;
  final String label;
  final int amountCents;

  String get formattedAmount => formatFeeAmountCents(amountCents);

  factory FeeTier.fromMap(Map<String, dynamic> m) {
    return FeeTier(
      tierId: m[FirestoreFields.tierId] as String? ?? '',
      label: m['label'] as String? ?? '',
      amountCents: (m[FirestoreFields.amountCents] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        FirestoreFields.tierId: tierId,
        'label': label,
        FirestoreFields.amountCents: amountCents,
      };

  FeeTier copyWith({
    String? tierId,
    String? label,
    int? amountCents,
  }) {
    return FeeTier(
      tierId: tierId ?? this.tierId,
      label: label ?? this.label,
      amountCents: amountCents ?? this.amountCents,
    );
  }
}
