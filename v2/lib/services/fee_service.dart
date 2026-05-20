import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/announcements/utils/announcement_filter.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/fee_tier.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

/// Accès Firestore aux cotisations (saisons + suivi par membre).
class FeeService {
  FeeService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _feeSeasonsCol(String clubId) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.feeSeasonsSubcollection);

  DocumentReference<Map<String, dynamic>> _feeSeasonRef(
    String clubId,
    String seasonId,
  ) =>
      _feeSeasonsCol(clubId).doc(seasonId);

  CollectionReference<Map<String, dynamic>> _memberFeesCol(
    String clubId,
    String seasonId,
  ) =>
      _feeSeasonsCol(clubId)
          .doc(seasonId)
          .collection(ProjectConfig.memberFeesSubcollection);

  String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  // ─── Lecture ───────────────────────────────────────────────────────────────

  Stream<FeeSeason?> watchActiveSeason(String clubId) {
    return _feeSeasonsCol(clubId)
        .where(FirestoreFields.isActive, isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return FeeSeason.fromFirestore(snap.docs.first);
    });
  }

  Stream<MemberFee?> watchMemberFee({
    required String clubId,
    required String seasonId,
    required String memberId,
  }) {
    return _memberFeesCol(clubId, seasonId)
        .doc(memberId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return MemberFee.fromFirestore(memberId, snap);
    });
  }

  Stream<List<MemberFee>> watchAllMemberFees({
    required String clubId,
    required String seasonId,
  }) {
    return _memberFeesCol(clubId, seasonId).snapshots().map(
          (snap) => snap.docs
              .map((d) => MemberFee.fromFirestore(d.id, d))
              .toList(),
        );
  }

  Stream<({MemberFee? fee, FeeSeason? season})> watchActiveMemberFee({
    required String clubId,
    required String memberId,
  }) {
    return watchActiveSeason(clubId).asyncExpand((season) {
      if (season == null) {
        return Stream.value((fee: null, season: null));
      }
      return watchMemberFee(
        clubId: clubId,
        seasonId: season.id,
        memberId: memberId,
      ).map((fee) => (fee: fee, season: season));
    });
  }

  // ─── Saisons (admin) ───────────────────────────────────────────────────────

  Future<String> createSeason({
    required String clubId,
    required FeeSeason season,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('Non connecté');

    final col = _feeSeasonsCol(clubId);
    final newRef = col.doc();
    final data = season.toFirestoreCreate();

    if (season.isActive) {
      final existingActive =
          await col.where(FirestoreFields.isActive, isEqualTo: true).get();
      if (existingActive.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in existingActive.docs) {
          batch.update(doc.reference, {FirestoreFields.isActive: false});
        }
        batch.set(newRef, data);
        await batch.commit();
        return newRef.id;
      }
    }

    await newRef.set(data);
    return newRef.id;
  }

  Future<void> updateSeason({
    required String clubId,
    required FeeSeason season,
  }) async {
    await _feeSeasonRef(clubId, season.id).update(season.toFirestoreUpdate());
  }

  Future<void> closeSeason({
    required String clubId,
    required String seasonId,
  }) async {
    await _feeSeasonRef(clubId, seasonId).update({
      FirestoreFields.isActive: false,
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  // ─── Member fees (admin) ───────────────────────────────────────────────────

  Future<void> setMemberFeeStatus({
    required String clubId,
    required String seasonId,
    required String memberId,
    required MemberFeeStatus status,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('Non connecté');

    final data = <String, dynamic>{
      FirestoreFields.feeStatus: status.firestoreValue,
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      FirestoreFields.markedBy: uid,
    };

    if (status == MemberFeeStatus.paye) {
      data[FirestoreFields.paidAt] = FieldValue.serverTimestamp();
    } else {
      data[FirestoreFields.paidAt] = FieldValue.delete();
    }

    if (status == MemberFeeStatus.exonere) {
      data[FirestoreFields.tierId] = FieldValue.delete();
    }

    await _memberFeesCol(clubId, seasonId)
        .doc(memberId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> setMemberFeeTier({
    required String clubId,
    required String seasonId,
    required String memberId,
    required String? tierId,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('Non connecté');

    final data = <String, dynamic>{
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      FirestoreFields.markedBy: uid,
    };

    if (tierId != null && tierId.isNotEmpty) {
      data[FirestoreFields.tierId] = tierId;
      data[FirestoreFields.feeStatus] = MemberFeeStatuses.aPayer;
    } else {
      data[FirestoreFields.tierId] = FieldValue.delete();
    }

    await _memberFeesCol(clubId, seasonId)
        .doc(memberId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> setMemberFeeNote({
    required String clubId,
    required String seasonId,
    required String memberId,
    required String? note,
  }) async {
    final data = <String, dynamic>{
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    };
    if (note != null && note.trim().isNotEmpty) {
      data[FirestoreFields.notesAdmin] = note.trim();
    } else {
      data[FirestoreFields.notesAdmin] = FieldValue.delete();
    }
    await _memberFeesCol(clubId, seasonId)
        .doc(memberId)
        .set(data, SetOptions(merge: true));
  }

  Future<int> countMemberFeesWithTier({
    required String clubId,
    required String seasonId,
    required String tierId,
  }) async {
    final snap = await _memberFeesCol(clubId, seasonId)
        .where(FirestoreFields.tierId, isEqualTo: tierId)
        .get();
    return snap.docs.length;
  }

  /// Crée les fiches manquantes pour membres + pending_members.
  Future<int> initializeMemberFees({
    required String clubId,
    required String seasonId,
    required List<ClubMember> members,
    required List<ClubTeam> teams,
    required List<ClubMember> pendingAsMembers,
    required Set<String> existingMemberIds,
    required List<FeeTier> tiers,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('Non connecté');

    final toCreate = <ClubMember>[
      ...members,
      ...pendingAsMembers,
    ];

    final writes = <({String id, MemberFee fee})>[];
    for (final m in toCreate) {
      if (existingMemberIds.contains(m.memberId)) continue;
      final tierId = _suggestTierId(
        member: m,
        teams: teams,
        tiers: tiers,
      );
      writes.add((
        id: m.memberId,
        fee: MemberFee(
          memberId: m.memberId,
          memberDisplayName: m.fullName,
          status: MemberFeeStatus.aPayer,
          tierId: tierId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));
    }

    if (writes.isEmpty) return 0;

    const maxBatch = 500;
    for (var i = 0; i < writes.length; i += maxBatch) {
      final batch = _db.batch();
      final end = (i + maxBatch > writes.length) ? writes.length : i + maxBatch;
      for (var j = i; j < end; j++) {
        final w = writes[j];
        final payload = w.fee.toFirestoreCreate(displayName: w.fee.memberDisplayName);
        if (w.fee.tierId != null) {
          payload[FirestoreFields.tierId] = w.fee.tierId;
        }
        batch.set(_memberFeesCol(clubId, seasonId).doc(w.id), payload);
      }
      await batch.commit();
    }
    return writes.length;
  }

  String? _suggestTierId({
    required ClubMember member,
    required List<ClubTeam> teams,
    required List<FeeTier> tiers,
  }) {
    if (tiers.isEmpty) return null;
    final categories = memberCategoriesFromTeams(
      clubTeams: teams,
      memberTeamIds: member.teamIds,
    );
    for (final cat in categories) {
      for (final tier in tiers) {
        if (tier.label.toLowerCase() == cat.toLowerCase()) {
          return tier.tierId;
        }
      }
    }
    return null;
  }

  Future<void> bulkSetStatus({
    required String clubId,
    required String seasonId,
    required List<String> memberIds,
    required MemberFeeStatus status,
  }) async {
    const maxBatch = 500;
    for (var i = 0; i < memberIds.length; i += maxBatch) {
      final end =
          (i + maxBatch > memberIds.length) ? memberIds.length : i + maxBatch;
      await Future.wait(
        memberIds.sublist(i, end).map(
              (id) => setMemberFeeStatus(
                clubId: clubId,
                seasonId: seasonId,
                memberId: id,
                status: status,
              ),
            ),
      );
    }
  }

  Future<void> bulkSetTier({
    required String clubId,
    required String seasonId,
    required List<String> memberIds,
    required String tierId,
  }) async {
    const maxBatch = 500;
    for (var i = 0; i < memberIds.length; i += maxBatch) {
      final end =
          (i + maxBatch > memberIds.length) ? memberIds.length : i + maxBatch;
      await Future.wait(
        memberIds.sublist(i, end).map(
              (id) => setMemberFeeTier(
                clubId: clubId,
                seasonId: seasonId,
                memberId: id,
                tierId: tierId,
              ),
            ),
      );
    }
  }

  /// Export CSV pour le trésorier.
  Future<String> exportCsv({
    required String clubId,
    required String seasonId,
    required FeeSeason season,
    required List<MemberFee> fees,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Nom;Catégorie;Montant;Statut;Date paiement;Notes admin');

    for (final fee in fees) {
      final tier = season.tierById(fee.tierId);
      final tierLabel = tier?.label ?? 'Non assigné';
      final amount = fee.status == MemberFeeStatus.exonere
          ? '0,00 €'
          : formatFeeAmountCents(fee.amountDueCents(season));
      final display = fee.displayStatus(season.paymentDeadlineAt);
      final statusLabel = display.label;
      final paidAt = fee.paidAt != null
          ? '${fee.paidAt!.day.toString().padLeft(2, '0')}/'
              '${fee.paidAt!.month.toString().padLeft(2, '0')}/'
              '${fee.paidAt!.year}'
          : '';
      final notes = (fee.notesAdmin ?? '').replaceAll(';', ',');
      buffer.writeln(
        '${fee.memberDisplayName};$tierLabel;$amount;$statusLabel;$paidAt;$notes',
      );
    }
    return buffer.toString();
  }
}
