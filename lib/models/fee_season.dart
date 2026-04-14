import 'package:cloud_firestore/cloud_firestore.dart';

import 'club_fee_settings.dart';

/// Une saison de cotisation du club.
///
/// Stockée dans `clubs/{clubId}/fee_seasons/{seasonId}`.
/// Reprend tous les champs de [ClubFeeSettings] et ajoute
/// les métadonnées propres à la saison (id, isActive, createdAt).
class FeeSeason {
  final String id;

  /// Libellé affiché (ex : "2024-2025").
  final String seasonLabel;

  /// Indique si cette saison est celle actuellement affichée aux joueurs.
  /// Une seule saison active par club à la fois.
  final bool isActive;

  final DateTime createdAt;

  /// Paliers tarifaires (liste vide si non configuré).
  final List<FeeTier> tiers;

  /// Consignes de paiement affichées aux joueurs.
  final String paymentInstructions;

  /// Dernier jour inclus pour le paiement (null = pas de date limite).
  final DateTime? paymentDeadlineAt;

  final String currency;

  final DateTime? updatedAt;

  const FeeSeason({
    required this.id,
    required this.seasonLabel,
    required this.isActive,
    required this.createdAt,
    required this.tiers,
    this.paymentInstructions = '',
    this.paymentDeadlineAt,
    this.currency = 'EUR',
    this.updatedAt,
  });

  factory FeeSeason.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawTiers = (d['tiers'] as List?)?.whereType<Map>().toList() ?? [];
    return FeeSeason(
      id: doc.id,
      seasonLabel: d['seasonLabel'] as String? ?? '',
      isActive: d['isActive'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tiers: rawTiers
          .map((e) => FeeTier.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      paymentInstructions: d['paymentInstructions'] as String? ?? '',
      currency: d['currency'] as String? ?? 'EUR',
      paymentDeadlineAt: (d['paymentDeadlineAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Payload pour la création (set sans merge) — n'utilise pas FieldValue.delete().
  Map<String, dynamic> toFirestore() => {
    'seasonLabel': seasonLabel,
    'isActive': isActive,
    'createdAt': FieldValue.serverTimestamp(),
    'tiers': tiers.map((t) => t.toMap()).toList(),
    'paymentInstructions': paymentInstructions,
    'currency': currency,
    if (paymentDeadlineAt != null)
      'paymentDeadlineAt': Timestamp.fromDate(paymentDeadlineAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Payload pour la mise à jour des paramètres uniquement (sans createdAt/isActive).
  /// Utilisé avec set(..., merge: true) — FieldValue.delete() est autorisé ici.
  Map<String, dynamic> toSettingsFirestore() => {
    'seasonLabel': seasonLabel,
    'tiers': tiers.map((t) => t.toMap()).toList(),
    'paymentInstructions': paymentInstructions,
    'currency': currency,
    if (paymentDeadlineAt != null)
      'paymentDeadlineAt': Timestamp.fromDate(paymentDeadlineAt!)
    else
      'paymentDeadlineAt': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  }; // FieldValue.delete() OK car toujours appelé avec SetOptions(merge: true)

  /// Convertit en [ClubFeeSettings] pour compatibilité avec le code existant.
  ClubFeeSettings toClubFeeSettings() => ClubFeeSettings(
    seasonLabel: seasonLabel,
    paymentInstructions: paymentInstructions,
    tiers: tiers,
    currency: currency,
    paymentDeadlineAt: paymentDeadlineAt,
    updatedAt: updatedAt,
  );

  /// Crée une copie avec les champs modifiés.
  FeeSeason copyWith({
    String? seasonLabel,
    bool? isActive,
    List<FeeTier>? tiers,
    String? paymentInstructions,
    DateTime? paymentDeadlineAt,
    bool clearDeadline = false,
    String? currency,
  }) {
    return FeeSeason(
      id: id,
      seasonLabel: seasonLabel ?? this.seasonLabel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      tiers: tiers ?? this.tiers,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      paymentDeadlineAt:
          clearDeadline ? null : (paymentDeadlineAt ?? this.paymentDeadlineAt),
      currency: currency ?? this.currency,
      updatedAt: updatedAt,
    );
  }
}
