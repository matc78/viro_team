import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/fee_tier.dart';

enum MemberFeeStatus { aPayer, paye, exonere }

enum MemberFeeDisplayStatus { aPayer, enRetard, paye, exonere }

extension MemberFeeStatusX on MemberFeeStatus {
  String get firestoreValue => switch (this) {
        MemberFeeStatus.aPayer => MemberFeeStatuses.aPayer,
        MemberFeeStatus.paye => MemberFeeStatuses.paye,
        MemberFeeStatus.exonere => MemberFeeStatuses.exonere,
      };

  static MemberFeeStatus fromFirestore(String? value) {
    switch (value) {
      case MemberFeeStatuses.paye:
        return MemberFeeStatus.paye;
      case MemberFeeStatuses.exonere:
        return MemberFeeStatus.exonere;
      case MemberFeeStatuses.aPayer:
      default:
        return MemberFeeStatus.aPayer;
    }
  }

  String get label => switch (this) {
        MemberFeeStatus.aPayer => 'À payer',
        MemberFeeStatus.paye => 'Payé',
        MemberFeeStatus.exonere => 'Exonéré',
      };
}

extension MemberFeeDisplayStatusX on MemberFeeDisplayStatus {
  String get label => switch (this) {
        MemberFeeDisplayStatus.aPayer => 'À payer',
        MemberFeeDisplayStatus.enRetard => 'En retard',
        MemberFeeDisplayStatus.paye => 'Payé',
        MemberFeeDisplayStatus.exonere => 'Exonéré',
      };
}

class MemberFee {
  const MemberFee({
    required this.memberId,
    required this.memberDisplayName,
    required this.status,
    this.tierId,
    this.notesAdmin,
    this.paidAt,
    this.markedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String memberId;
  final String memberDisplayName;
  final MemberFeeStatus status;
  final String? tierId;
  final String? notesAdmin;
  final DateTime? paidAt;
  final String? markedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MemberFee.fromFirestore(
    String memberId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return MemberFee(
      memberId: memberId,
      memberDisplayName:
          d[FirestoreFields.memberDisplayName] as String? ?? '',
      status: MemberFeeStatusX.fromFirestore(
        d[FirestoreFields.feeStatus] as String?,
      ),
      tierId: d[FirestoreFields.tierId] as String?,
      notesAdmin: d[FirestoreFields.notesAdmin] as String?,
      paidAt: (d[FirestoreFields.paidAt] as Timestamp?)?.toDate(),
      markedBy: d[FirestoreFields.markedBy] as String?,
      createdAt:
          (d[FirestoreFields.createdAt] as Timestamp?)?.toDate() ??
              DateTime.now(),
      updatedAt:
          (d[FirestoreFields.updatedAt] as Timestamp?)?.toDate() ??
              DateTime.now(),
    );
  }

  int amountDueCents(FeeSeason? season) {
    if (status == MemberFeeStatus.exonere) return 0;
    if (season == null || tierId == null) return 0;
    for (final t in season.tiers) {
      if (t.tierId == tierId) return t.amountCents;
    }
    return 0;
  }

  FeeTier? resolveTier(FeeSeason? season) {
    if (season == null || tierId == null) return null;
    for (final t in season.tiers) {
      if (t.tierId == tierId) return t;
    }
    return null;
  }

  MemberFeeDisplayStatus displayStatus(DateTime? deadline, [DateTime? clock]) {
    if (status == MemberFeeStatus.paye) return MemberFeeDisplayStatus.paye;
    if (status == MemberFeeStatus.exonere) {
      return MemberFeeDisplayStatus.exonere;
    }
    if (deadline != null && _isDeadlineElapsed(deadline, clock)) {
      return MemberFeeDisplayStatus.enRetard;
    }
    return MemberFeeDisplayStatus.aPayer;
  }

  static bool _isDeadlineElapsed(DateTime deadline, DateTime? clock) {
    final now = clock ?? DateTime.now();
    final end = DateTime(deadline.year, deadline.month, deadline.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(end);
  }

  Map<String, dynamic> toFirestoreCreate({
    required String displayName,
  }) {
    return {
      FirestoreFields.memberId: memberId,
      FirestoreFields.memberDisplayName: displayName,
      FirestoreFields.feeStatus: status.firestoreValue,
      if (tierId != null && tierId!.isNotEmpty) FirestoreFields.tierId: tierId,
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    };
  }
}
