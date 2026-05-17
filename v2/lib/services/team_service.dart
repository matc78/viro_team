import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

class TeamService {
  TeamService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _teams(String clubId) => _db
      .collection(ProjectConfig.clubsCollection)
      .doc(clubId)
      .collection(ProjectConfig.teamsSubcollection);

  CollectionReference<Map<String, dynamic>> _pendingMembers(String clubId) =>
      _db
          .collection(ProjectConfig.clubsCollection)
          .doc(clubId)
          .collection(ProjectConfig.pendingMembersSubcollection);

  /// Toutes les équipes du club, triées par nom.
  Stream<List<ClubTeam>> watchClubTeams({required String clubId}) {
    return _teams(clubId).snapshots().map((snap) {
      final teams = snap.docs
          .map((d) => ClubTeam.fromFirestore(clubId: clubId, doc: d))
          .toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      return teams;
    });
  }

  /// Équipes où [uid] (et [alternateUid] si fourni) est joueur ou coach.
  Stream<List<ClubTeam>> watchUserTeams({
    required String clubId,
    required String uid,
    String? alternateUid,
  }) {
    final ids = <String>{uid};
    final alt = alternateUid;
    if (alt != null && alt.isNotEmpty) ids.add(alt);

    final streams = <Stream<List<ClubTeam>>>[];
    for (final id in ids) {
      streams.add(
        _teams(clubId)
            .where(FirestoreFields.playerIds, arrayContains: id)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((d) => ClubTeam.fromFirestore(clubId: clubId, doc: d))
                  .toList(),
            ),
      );
      streams.add(
        _teams(clubId)
            .where(FirestoreFields.coachIds, arrayContains: id)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((d) => ClubTeam.fromFirestore(clubId: clubId, doc: d))
                  .toList(),
            ),
      );
    }

    return combineLatestListStreams(streams).map((teams) {
      final byId = <String, ClubTeam>{};
      for (final team in teams) {
        byId[team.id] = team;
      }
      return byId.values.toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    });
  }

  Future<Map<String, TeamMemberProfile>> fetchMemberProfiles(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return {};

    final unique = uids.toSet().toList();
    final result = <String, TeamMemberProfile>{};

    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.skip(i).take(30).toList();
      final snap = await _db
          .collection(ProjectConfig.usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final user = ViroUser.fromFirestore(doc);
        result[user.uid] = TeamMemberProfile(
          uid: user.uid,
          displayName: user.displayName.isNotEmpty
              ? user.displayName
              : '${user.firstName} ${user.lastName}'.trim(),
          firstName: user.firstName,
          lastName: user.lastName,
          avatarUrl: user.avatarUrl,
        );
      }
    }

    return result;
  }

  Stream<List<PendingTeamMember>> watchPendingMembers(String clubId) {
    return _pendingMembers(clubId).snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            final data = doc.data();
            return PendingTeamMember(
              id: doc.id,
              firstName: data[FirestoreFields.firstName] as String? ?? '',
              lastName: data[FirestoreFields.lastName] as String? ?? '',
              email: data[FirestoreFields.email] as String?,
            );
          })
          .toList()
        ..sort(
          (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
    });
  }

  Future<String> createTeam({
    required String clubId,
    required String name,
    required String category,
  }) async {
    final ref = await _teams(clubId).add({
      FirestoreFields.name: name.trim(),
      FirestoreFields.category: category,
      FirestoreFields.playerIds: <String>[],
      FirestoreFields.coachIds: <String>[],
      FirestoreFields.pendingPlayerIds: <String>[],
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> addPlayerToTeam({
    required String clubId,
    required String teamId,
    required String uid,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.playerIds: FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> addCoachToTeam({
    required String clubId,
    required String teamId,
    required String uid,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.coachIds: FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> addPendingPlayerToTeam({
    required String clubId,
    required String teamId,
    required String pendingId,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.pendingPlayerIds: FieldValue.arrayUnion([pendingId]),
    });
  }

  Future<void> removePlayerFromTeam({
    required String clubId,
    required String teamId,
    required String uid,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.playerIds: FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> removeCoachFromTeam({
    required String clubId,
    required String teamId,
    required String uid,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.coachIds: FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> removePendingPlayerFromTeam({
    required String clubId,
    required String teamId,
    required String pendingId,
  }) async {
    await _teams(clubId).doc(teamId).update({
      FirestoreFields.pendingPlayerIds: FieldValue.arrayRemove([pendingId]),
    });
  }

  Future<List<PendingTeamMember>> fetchPendingMembers({
    required String clubId,
    required List<String> pendingIds,
  }) async {
    if (pendingIds.isEmpty) return [];

    final refs = pendingIds
        .map((id) => _pendingMembers(clubId).doc(id))
        .toList();
    final snaps = await Future.wait(refs.map((r) => r.get()));

    return snaps
        .where((s) => s.exists)
        .map((doc) {
          final data = doc.data() ?? {};
          return PendingTeamMember(
            id: doc.id,
            firstName: data[FirestoreFields.firstName] as String? ?? '',
            lastName: data[FirestoreFields.lastName] as String? ?? '',
            email: data[FirestoreFields.email] as String?,
          );
        })
        .toList();
  }

  /// Remplace [legacyMemberId] par [authUid] dans les rosters d'équipe (après liaison compte).
  Future<void> reconcileRosterIds({
    required String clubId,
    required String legacyMemberId,
    required String authUid,
  }) async {
    if (legacyMemberId.isEmpty || authUid.isEmpty || legacyMemberId == authUid) {
      return;
    }

    final playerSnap = await _teams(clubId)
        .where(FirestoreFields.playerIds, arrayContains: legacyMemberId)
        .get();
    final coachSnap = await _teams(clubId)
        .where(FirestoreFields.coachIds, arrayContains: legacyMemberId)
        .get();
    final pendingSnap = await _teams(clubId)
        .where(FirestoreFields.pendingPlayerIds, arrayContains: legacyMemberId)
        .get();

    final updates = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};

    void mergePatch(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> patch,
    ) {
      updates[ref] = {...?updates[ref], ...patch};
    }

    void patchTeam(
      DocumentSnapshot<Map<String, dynamic>> doc, {
      required String field,
      required bool promoteToPlayers,
    }) {
      final data = doc.data() ?? {};
      final ids = (data[field] as List<dynamic>?)?.whereType<String>().toList() ??
          [];
      if (!ids.contains(legacyMemberId)) return;

      final next =
          ids.map((id) => id == legacyMemberId ? authUid : id).toSet().toList();
      final patch = <String, dynamic>{field: next};
      if (promoteToPlayers) {
        final players = (data[FirestoreFields.playerIds] as List<dynamic>?)
                ?.whereType<String>()
                .toSet() ??
            {};
        players.add(authUid);
        patch[FirestoreFields.playerIds] = players.toList();
        final pending = (data[FirestoreFields.pendingPlayerIds] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            [];
        patch[FirestoreFields.pendingPlayerIds] =
            pending.where((id) => id != legacyMemberId).toList();
      }
      mergePatch(doc.reference, patch);
    }

    for (final doc in playerSnap.docs) {
      patchTeam(doc, field: FirestoreFields.playerIds, promoteToPlayers: false);
    }
    for (final doc in coachSnap.docs) {
      patchTeam(doc, field: FirestoreFields.coachIds, promoteToPlayers: false);
    }
    for (final doc in pendingSnap.docs) {
      patchTeam(
        doc,
        field: FirestoreFields.pendingPlayerIds,
        promoteToPlayers: true,
      );
    }

    if (updates.isEmpty) return;

    final batch = _db.batch();
    for (final entry in updates.entries) {
      batch.update(entry.key, entry.value);
    }
    await batch.commit();
  }

  /// Corrige les rosters où un memberId pré-créé n'a pas été remplacé par l'UID Auth.
  Future<void> reconcileStaleRosterIds(String clubId) async {
    final membersSnap = await _db
        .collection(ProjectConfig.clubsCollection)
        .doc(clubId)
        .collection(ProjectConfig.membersSubcollection)
        .get();

    for (final doc in membersSnap.docs) {
      final accountUid = doc.data()[FirestoreFields.accountUid] as String?;
      if (accountUid == null || accountUid.isEmpty || accountUid == doc.id) {
        continue;
      }
      await reconcileRosterIds(
        clubId: clubId,
        legacyMemberId: doc.id,
        authUid: accountUid,
      );
    }
  }
}
