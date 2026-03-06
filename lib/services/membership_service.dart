import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/firebase_helpers.dart';

/// Service pour la nouvelle architecture : clubs/{clubId}/members/{uid} + users/{uid}.profileSummaries
class MembershipService {
  MembershipService._();
  static final MembershipService instance = MembershipService._();

  final _db = appFirestore;

  /// Récupère la liste actuelle des profileSummaries (depuis le doc user ou dérivée de roles)
  Future<List<Map<String, String>>> _getProfileSummaries(String uid) async {
    final userSnap = await _db.collection(FirebaseCollections.users).doc(uid).get();
    final d = userSnap.data() ?? {};
    final raw = d['profileSummaries'] as List? ?? [];
    if (raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((m) => {
                'clubId': (m['clubId'] as String? ?? '').trim(),
                'role': (m['role'] as String? ?? '').trim(),
              })
          .where((e) => e['clubId']!.isNotEmpty && e['role']!.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Ajoute (clubId, role) à profileSummaries si pas déjà présent
  Future<void> _addProfileSummaryEntry(String uid, String clubId, String role) async {
    final summaries = await _getProfileSummaries(uid);
    if (summaries.any((e) => e['clubId'] == clubId && e['role'] == role)) return;
    summaries.add({'clubId': clubId, 'role': role});
    await updateProfileSummariesForUser(uid, summaries);
  }

  /// Retire toutes les entrées pour ce clubId des profileSummaries
  Future<void> _removeProfileSummaryEntriesForClub(String uid, String clubId) async {
    final summaries = await _getProfileSummaries(uid);
    final filtered = summaries.where((e) => e['clubId'] != clubId).toList();
    if (filtered.length == summaries.length) return;
    await updateProfileSummariesForUser(uid, filtered);
  }

  String _displayNameFromUserData(Map<String, dynamic> userData) {
    final first = (userData['firstName'] as String?)?.trim() ?? '';
    final last = (userData['lastName'] as String?)?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return userData['email'] as String? ?? '';
    return [first, last.toUpperCase()].where((e) => e.isNotEmpty).join(' ').trim();
  }

  /// Crée ou met à jour le document member et ajoute (clubId, role) à profileSummaries
  Future<void> ensureMemberAndProfileSummary({
    required String uid,
    required String clubId,
    required String role,
    bool isFounderAdmin = false,
    String? playerLicense,
    List<String> playerTeamIds = const [],
    List<String> playerTeamNames = const [],
    List<String> playerCategories = const [],
    List<String> coachTeamIds = const [],
    List<String> coachTeamNames = const [],
    Map<String, dynamic>? userDataOverride,
  }) async {
    final userSnap = await _db.collection(FirebaseCollections.users).doc(uid).get();
    final userData = userDataOverride ?? userSnap.data() ?? {};
    final snapshot = {
      'displayName': _displayNameFromUserData(userData),
      'avatarUrl': userData['avatarUrl'],
      'email': userData['email'],
    };

    final memberRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .doc(uid);

    final existing = await memberRef.get();
    final List<String> roles = existing.exists
        ? List<String>.from((existing.data()?['roles'] as List?)?.whereType<String>() ?? [])
        : [];
    if (!roles.contains(role)) roles.add(role);

    final updates = <String, dynamic>{
      'userId': uid,
      'roles': roles,
      'isFounderAdmin': isFounderAdmin || (existing.data()?['isFounderAdmin'] == true),
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      'snapshot': snapshot,
    };
    if (role == 'player') {
      updates['player'] = {
        if (playerLicense != null) 'license': playerLicense,
        'teamIds': playerTeamIds,
        'teamNames': playerTeamNames,
        'categories': playerCategories,
      };
    }
    if (role == 'coach') {
      updates['coach'] = {
        'teamIds': coachTeamIds,
        'teamNames': coachTeamNames.isNotEmpty ? coachTeamNames : coachTeamIds,
      };
    }
    if (role == 'admin' || role == 'admin_fondateur') {
      updates['admin'] = {'scopes': ['full']};
    }
    if (!existing.exists) {
      updates['joinedAt'] = FieldValue.serverTimestamp();
    }
    if (existing.exists) {
      final ed = existing.data() ?? {};
      if (!updates.containsKey('player') && ed['player'] is Map) updates['player'] = ed['player'];
      if (!updates.containsKey('coach') && ed['coach'] is Map) updates['coach'] = ed['coach'];
      if (!updates.containsKey('admin') && ed['admin'] is Map) updates['admin'] = ed['admin'];
    }

    await memberRef.set(updates, SetOptions(merge: true));
    await _addProfileSummaryEntry(uid, clubId, role);
  }

  /// Supprime le document member et les entrées profileSummaries pour ce club
  Future<void> removeMemberAndProfileSummary(String uid, String clubId) async {
    final memberRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .doc(uid);
    await memberRef.delete();
    await _removeProfileSummaryEntriesForClub(uid, clubId);
  }

  /// Retire un rôle dans un club (ex. joueur quitte le club). Met à jour ou supprime le doc member et profileSummaries.
  Future<void> removeRoleFromClub(String uid, String clubId, String role) async {
    final memberRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .doc(uid);
    final snap = await memberRef.get();
    if (!snap.exists) {
      await _removeProfileSummaryEntry(uid, clubId, role);
      return;
    }
    final data = snap.data() ?? {};
    final roles = List<String>.from((data['roles'] as List?)?.whereType<String>() ?? []);
    roles.remove(role);
    if (roles.isEmpty) {
      await memberRef.delete();
      await _removeProfileSummaryEntriesForClub(uid, clubId);
      return;
    }
    final updates = <String, dynamic>{
      'roles': roles,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (role == 'player') updates['player'] = FieldValue.delete();
    if (role == 'coach') updates['coach'] = FieldValue.delete();
    if (role == 'admin' || role == 'admin_fondateur') updates['admin'] = FieldValue.delete();
    await memberRef.set(updates, SetOptions(merge: true));
    await _removeProfileSummaryEntry(uid, clubId, role);
  }

  Future<void> _removeProfileSummaryEntry(String uid, String clubId, String role) async {
    final summaries = await _getProfileSummaries(uid);
    final filtered = summaries.where((e) => !(e['clubId'] == clubId && e['role'] == role)).toList();
    if (filtered.length == summaries.length) return;
    await updateProfileSummariesForUser(uid, filtered);
  }

  /// Met à jour la section player du member doc (équipes, licence)
  Future<void> updateMemberPlayer({
    required String uid,
    required String clubId,
    String? license,
    List<String>? teamIds,
    List<String>? teamNames,
    List<String>? categories,
  }) async {
    final memberRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .doc(uid);
    final snap = await memberRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final player = Map<String, dynamic>.from((data['player'] as Map?) ?? {});
    if (license != null) player['license'] = license;
    if (teamIds != null) player['teamIds'] = teamIds;
    if (teamNames != null) player['teamNames'] = teamNames;
    if (categories != null) player['categories'] = categories;
    await memberRef.set({
      'player': player,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Met à jour la section coach du member doc (équipes)
  Future<void> updateMemberCoach({
    required String uid,
    required String clubId,
    List<String>? teamIds,
    List<String>? teamNames,
  }) async {
    final memberRef = _db
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.members)
        .doc(uid);
    final snap = await memberRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final coach = Map<String, dynamic>.from((data['coach'] as Map?) ?? {});
    if (teamIds != null) coach['teamIds'] = teamIds;
    if (teamNames != null) coach['teamNames'] = teamNames.isNotEmpty ? teamNames : (coach['teamIds'] as List? ?? []);
    await memberRef.set({
      'coach': coach,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
