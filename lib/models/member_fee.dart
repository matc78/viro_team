import 'package:cloud_firestore/cloud_firestore.dart';

import 'club_fee_settings.dart';

/// Statut de cotisation d'un joueur (persisté en String dans Firestore).
enum MemberFeeStatus {
  nonConfigure('non_configure'),
  exonere('exonere'),
  aPayer('a_payer'),
  partiel('partiel'),
  paye('paye'),
  enRetard('en_retard');

  final String value;
  const MemberFeeStatus(this.value);

  static MemberFeeStatus fromString(String? s) {
    for (final e in MemberFeeStatus.values) {
      if (e.value == s) return e;
    }
    return MemberFeeStatus.nonConfigure;
  }

  /// Libellé court pour l'UI (français).
  String get label {
    switch (this) {
      case MemberFeeStatus.nonConfigure:
        return 'Non configuré';
      case MemberFeeStatus.exonere:
        return 'Exonéré';
      case MemberFeeStatus.aPayer:
        return 'En attente de paiement';
      case MemberFeeStatus.partiel:
        return 'Partiel';
      case MemberFeeStatus.paye:
        return 'Payé';
      case MemberFeeStatus.enRetard:
        return 'En retard';
    }
  }
}

/// Document `clubs/{clubId}/member_fees/{userId}`.
class MemberFee {
  final String userId;
  final MemberFeeStatus status;
  final String? tierId;
  final int? customAmountCents;
  final int amountPaidCents;
  final String? notesAdmin;
  final DateTime? updatedAt;
  final String? updatedByUid;

  const MemberFee({
    required this.userId,
    required this.status,
    this.tierId,
    this.customAmountCents,
    this.amountPaidCents = 0,
    this.notesAdmin,
    this.updatedAt,
    this.updatedByUid,
  });

  factory MemberFee.fromFirestore(
    String userId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return MemberFee(
      userId: userId,
      status: MemberFeeStatus.fromString(d['status'] as String?),
      tierId: d['tierId'] as String?,
      customAmountCents: (d['customAmountCents'] as num?)?.toInt(),
      amountPaidCents: (d['amountPaidCents'] as num?)?.toInt() ?? 0,
      notesAdmin: d['notesAdmin'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      updatedByUid: d['updatedByUid'] as String?,
    );
  }

  /// Montant dû en centimes selon la grille ou montant personnalisé.
  int amountDueCents(ClubFeeSettings? settings) {
    if (status == MemberFeeStatus.exonere) return 0;
    if (customAmountCents != null) return customAmountCents!;
    if (tierId != null && settings != null) {
      for (final t in settings.tiers) {
        if (t.tierId == tierId) return t.amountCents;
      }
    }
    return 0;
  }

  int remainingCents(ClubFeeSettings? settings) {
    final due = amountDueCents(settings);
    final rest = due - amountPaidCents;
    return rest > 0 ? rest : 0;
  }

  /// Statut affiché : tient compte du solde et, si défini, de la date limite (passée → « en retard »).
  MemberFeeStatus effectiveDisplayStatus(
    ClubFeeSettings? settings, [
    DateTime? clock,
  ]) {
    final now = clock ?? DateTime.now();
    if (status == MemberFeeStatus.exonere) return MemberFeeStatus.exonere;
    if (status == MemberFeeStatus.nonConfigure) {
      return MemberFeeStatus.nonConfigure;
    }

    final rest = remainingCents(settings);
    if (rest <= 0) return MemberFeeStatus.paye;

    if (status == MemberFeeStatus.enRetard) return MemberFeeStatus.enRetard;

    var adjusted = status;
    if (status == MemberFeeStatus.paye && rest > 0) {
      adjusted = amountPaidCents > 0
          ? MemberFeeStatus.partiel
          : MemberFeeStatus.aPayer;
    }

    if (settings?.isPaymentDeadlineElapsed(now) == true) {
      return MemberFeeStatus.enRetard;
    }
    return adjusted;
  }
}
