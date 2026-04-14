import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firebase_collections.dart';
import '../models/club_fee_settings.dart';
import '../models/fee_season.dart';
import '../models/member_fee.dart';
import '../utils/firestore_instance.dart';

/// Accès Firestore aux cotisations (saisons + suivi par membre).
class FeeService {
  FeeService._();
  static final FeeService instance = FeeService._();

  // ─── Helpers chemins ───────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _feeSeasonsCol(String clubId) {
    return appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.feeSeasons);
  }

  DocumentReference<Map<String, dynamic>> _feeSeasonRef(
    String clubId,
    String seasonId,
  ) {
    return _feeSeasonsCol(clubId).doc(seasonId);
  }

  CollectionReference<Map<String, dynamic>> _seasonMemberFeesCol(
    String clubId,
    String seasonId,
  ) {
    return _feeSeasonsCol(clubId)
        .doc(seasonId)
        .collection(FirebaseCollections.memberFees);
  }

  // ─── Saisons ───────────────────────────────────────────────────────────────

  /// Stream de toutes les saisons du club (tri createdAt desc côté client).
  Stream<List<FeeSeason>> watchSeasons(String clubId) {
    return _feeSeasonsCol(clubId).snapshots().map((snap) {
      final seasons = snap.docs
          .map((d) => FeeSeason.fromFirestore(d))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return seasons;
    });
  }

  /// Stream de la saison active (isActive == true), ou null si aucune.
  Stream<FeeSeason?> watchActiveSeason(String clubId) {
    return _feeSeasonsCol(clubId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return FeeSeason.fromFirestore(snap.docs.first);
    });
  }

  /// Crée une nouvelle saison.
  ///
  /// Si [season.isActive] est true, désactive toutes les autres saisons en batch.
  Future<String> createSeason(String clubId, FeeSeason season) async {
    final col = _feeSeasonsCol(clubId);
    final newRef = col.doc();

    if (season.isActive) {
      // Désactiver les saisons actives existantes
      final existingActive = await col
          .where('isActive', isEqualTo: true)
          .get();
      if (existingActive.docs.isNotEmpty) {
        final batch = appFirestore.batch();
        for (final doc in existingActive.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        batch.set(newRef, season.toFirestore());
        await batch.commit();
        return newRef.id;
      }
    }

    await newRef.set(season.toFirestore());
    return newRef.id;
  }

  /// Bascule la saison [seasonId] comme active (désactive les autres).
  Future<void> setActiveSeason(String clubId, String seasonId) async {
    final col = _feeSeasonsCol(clubId);
    final existingActive = await col.where('isActive', isEqualTo: true).get();

    final batch = appFirestore.batch();
    for (final doc in existingActive.docs) {
      if (doc.id != seasonId) {
        batch.update(doc.reference, {'isActive': false});
      }
    }
    batch.update(col.doc(seasonId), {'isActive': true});
    await batch.commit();
  }

  // ─── Paramètres d'une saison ───────────────────────────────────────────────

  /// Stream des paramètres d'une saison (en tant que [ClubFeeSettings] pour compatibilité).
  Stream<ClubFeeSettings?> watchFeeSettings(String clubId, String seasonId) {
    return _feeSeasonRef(clubId, seasonId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FeeSeason.fromFirestore(snap).toClubFeeSettings();
    });
  }

  /// Stream de la [FeeSeason] complète.
  Stream<FeeSeason?> watchFeeSeason(String clubId, String seasonId) {
    return _feeSeasonRef(clubId, seasonId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FeeSeason.fromFirestore(snap);
    });
  }

  /// Sauvegarde les paramètres d'une saison existante (ne touche pas isActive/createdAt).
  Future<void> saveFeeSettings(
    String clubId,
    String seasonId,
    ClubFeeSettings settings,
  ) async {
    await _feeSeasonRef(
      clubId,
      seasonId,
    ).set(settings.toFirestore(), SetOptions(merge: true));
  }

  /// Sauvegarde une [FeeSeason] (paramètres uniquement, pas isActive/createdAt).
  Future<void> saveFeeSeason(String clubId, FeeSeason season) async {
    await _feeSeasonRef(
      clubId,
      season.id,
    ).set(season.toSettingsFirestore(), SetOptions(merge: true));
  }

  // ─── Cotisations membres ───────────────────────────────────────────────────

  Stream<MemberFee?> watchMemberFee(
    String clubId,
    String seasonId,
    String userId,
  ) {
    return _seasonMemberFeesCol(clubId, seasonId)
        .doc(userId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return MemberFee.fromFirestore(userId, snap);
    });
  }

  Stream<List<MemberFee>> watchAllMemberFees(String clubId, String seasonId) {
    return _seasonMemberFeesCol(clubId, seasonId).snapshots().map(
      (snap) => snap.docs.map((d) => MemberFee.fromFirestore(d.id, d)).toList(),
    );
  }

  /// Stream de la cotisation du joueur pour la saison active.
  Stream<({MemberFee? fee, FeeSeason? season})> watchActiveMemberFee(
    String clubId,
    String userId,
  ) {
    return watchActiveSeason(clubId).asyncExpand((season) {
      if (season == null) {
        return Stream.value((fee: null, season: null));
      }
      return watchMemberFee(clubId, season.id, userId).map(
        (fee) => (fee: fee, season: season),
      );
    });
  }

  Future<void> upsertMemberFee({
    required String clubId,
    required String seasonId,
    required MemberFee fee,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Non connecté');

    final normalized = _memberFeeWithDefaultStatusWhenTier(fee);
    final ref = _seasonMemberFeesCol(clubId, seasonId).doc(fee.userId);
    final data = _memberFeeWritePayload(normalized, uid);
    await ref.set(data, SetOptions(merge: true));
  }

  /// Avec un palier de grille (sans montant perso), passer de « non configuré » à « en attente de paiement ».
  MemberFee _memberFeeWithDefaultStatusWhenTier(MemberFee fee) {
    final hasTier =
        fee.tierId != null &&
        fee.tierId!.isNotEmpty &&
        fee.customAmountCents == null;
    if (hasTier && fee.status == MemberFeeStatus.nonConfigure) {
      return MemberFee(
        userId: fee.userId,
        status: MemberFeeStatus.aPayer,
        tierId: fee.tierId,
        customAmountCents: fee.customAmountCents,
        amountPaidCents: fee.amountPaidCents,
        notesAdmin: fee.notesAdmin,
      );
    }
    return fee;
  }

  /// Payload Firestore pour un doc `member_fees` (merge).
  Map<String, dynamic> _memberFeeWritePayload(MemberFee fee, String editorUid) {
    final data = <String, dynamic>{
      'status': fee.status.value,
      'amountPaidCents': fee.amountPaidCents,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': editorUid,
    };

    if (fee.notesAdmin != null && fee.notesAdmin!.isNotEmpty) {
      data['notesAdmin'] = fee.notesAdmin;
    } else {
      data['notesAdmin'] = FieldValue.delete();
    }

    if (fee.tierId != null && fee.tierId!.isNotEmpty) {
      data['tierId'] = fee.tierId;
      data['customAmountCents'] = FieldValue.delete();
    } else if (fee.customAmountCents != null) {
      data['customAmountCents'] = fee.customAmountCents;
      data['tierId'] = FieldValue.delete();
    } else {
      data['tierId'] = FieldValue.delete();
      data['customAmountCents'] = FieldValue.delete();
    }

    return data;
  }

  /// Applique un palier et/ou un statut à plusieurs joueurs (écritures par batch de 500).
  ///
  /// [applyTierId] non null : fixe le palier et supprime un montant personnalisé.
  /// Si [applyStatus] est null mais un palier est appliqué, le statut devient « en attente de paiement ».
  /// [applyStatus] non null : fixe le statut (prioritaire sur le défaut ci-dessus).
  /// Au moins l'un des deux doit être non null.
  /// Si le statut final est [MemberFeeStatus.partiel], [partialPaidCents] est requis (identique pour tous, plafonné au dû par joueur).
  Future<void> applyBulkMemberFees({
    required String clubId,
    required String seasonId,
    required List<String> userIds,
    required ClubFeeSettings? settings,
    required Map<String, MemberFee?> existingByUid,
    String? applyTierId,
    MemberFeeStatus? applyStatus,
    int? partialPaidCents,
  }) async {
    final editorUid = FirebaseAuth.instance.currentUser?.uid;
    if (editorUid == null) throw StateError('Non connecté');
    if (applyTierId == null && applyStatus == null) {
      throw ArgumentError('applyTierId ou applyStatus requis');
    }
    if (applyStatus == MemberFeeStatus.partiel && partialPaidCents == null) {
      throw ArgumentError('partialPaidCents requis pour le statut partiel');
    }

    final col = _seasonMemberFeesCol(clubId, seasonId);
    const maxBatch = 500;

    MemberFee mergeOne(String uid) {
      final base =
          existingByUid[uid] ??
          MemberFee(userId: uid, status: MemberFeeStatus.nonConfigure);

      var tierId = base.tierId;
      var custom = base.customAmountCents;
      var status = base.status;

      if (applyTierId != null) {
        tierId = applyTierId;
        custom = null;
      }
      if (applyStatus != null) {
        status = applyStatus;
      } else if (applyTierId != null) {
        status = MemberFeeStatus.aPayer;
      }

      if (applyStatus == MemberFeeStatus.exonere) {
        tierId = null;
        custom = null;
      }

      var fee = MemberFee(
        userId: uid,
        status: status,
        tierId: tierId,
        customAmountCents: custom,
        amountPaidCents: base.amountPaidCents,
        notesAdmin: base.notesAdmin,
      );

      final due = fee.amountDueCents(settings);
      var paid = fee.amountPaidCents;

      if (fee.status == MemberFeeStatus.paye) {
        paid = due;
      } else if (fee.status == MemberFeeStatus.partiel) {
        paid = partialPaidCents!.clamp(0, due);
      } else if (fee.status == MemberFeeStatus.exonere) {
        paid = 0;
      }

      return MemberFee(
        userId: uid,
        status: fee.status,
        tierId: fee.tierId,
        customAmountCents: fee.customAmountCents,
        amountPaidCents: paid,
        notesAdmin: fee.notesAdmin,
      );
    }

    final writes = <({String uid, MemberFee fee})>[];
    for (final uid in userIds) {
      writes.add((uid: uid, fee: mergeOne(uid)));
    }

    for (var i = 0; i < writes.length; i += maxBatch) {
      final batch = appFirestore.batch();
      final end =
          (i + maxBatch > writes.length) ? writes.length : i + maxBatch;
      for (var j = i; j < end; j++) {
        final w = writes[j];
        batch.set(
          col.doc(w.uid),
          _memberFeeWritePayload(w.fee, editorUid),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }
}
