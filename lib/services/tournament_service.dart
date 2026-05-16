import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firebase_collections.dart';
import '../models/tournament/tournament_match.dart';
import '../models/tournament/tournament_model.dart';
import '../models/tournament/tournament_phase.dart';
import '../models/tournament/tournament_team.dart';
import '../utils/firestore_instance.dart';

/// Données combinées d'un tournoi (phases + matchs + équipes) pour un seul stream.
class TournamentData {
  final List<TournamentPhase> phases;
  final List<TournamentMatch> matches;
  final List<TournamentTeam> teams;

  const TournamentData({
    required this.phases,
    required this.matches,
    required this.teams,
  });
}

class TournamentStanding {
  final int rank;
  final String teamId;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  const TournamentStanding({
    required this.rank,
    required this.teamId,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.points = 0,
  });
}

class TournamentService {
  TournamentService._();
  static final TournamentService instance = TournamentService._();

  final FirebaseFirestore _db = appFirestore;

  // ─── Path helpers ────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _tournamentsCol(
          String clubId) =>
      _db
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.tournaments);

  DocumentReference<Map<String, dynamic>> _tournamentRef(
          String clubId, String tId) =>
      _tournamentsCol(clubId).doc(tId);

  CollectionReference<Map<String, dynamic>> _teamsCol(
          String clubId, String tId) =>
      _tournamentRef(clubId, tId)
          .collection(FirebaseCollections.tournamentTeams);

  CollectionReference<Map<String, dynamic>> _matchesCol(
          String clubId, String tId) =>
      _tournamentRef(clubId, tId)
          .collection(FirebaseCollections.tournamentMatches);

  CollectionReference<Map<String, dynamic>> _phasesCol(
          String clubId, String tId) =>
      _tournamentRef(clubId, tId)
          .collection(FirebaseCollections.tournamentPhases);

  // ─── Tournament CRUD ────────────────────────────────────────────────────

  Stream<List<TournamentModel>> watchTournaments(String clubId) {
    return _tournamentsCol(clubId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentModel.fromFirestore(d))
            .toList());
  }

  Stream<TournamentModel?> watchTournament(
      String clubId, String tournamentId) {
    return _tournamentRef(clubId, tournamentId)
        .snapshots()
        .map((d) => d.exists ? TournamentModel.fromFirestore(d) : null);
  }

  Future<String> createTournament(
      String clubId, TournamentModel tournament) async {
    final ref = _tournamentsCol(clubId).doc();
    await ref.set(tournament.toFirestore());
    return ref.id;
  }

  Future<void> updateTournament(
      String clubId, TournamentModel tournament) async {
    final data = tournament.toFirestore()..remove('createdAt');
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _tournamentRef(clubId, tournament.id).update(data);
  }

  Future<void> deleteTournament(
      String clubId, String tournamentId) async {
    // Suppression simple du document tournoi (les sous-collections
    // sont nettoyées séparément si nécessaire via Cloud Functions).
    await _tournamentRef(clubId, tournamentId).delete();
  }

  // ─── Teams ───────────────────────────────────────────────────────────────

  Stream<List<TournamentTeam>> watchTeams(
      String clubId, String tournamentId) {
    return _teamsCol(clubId, tournamentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map(TournamentTeam.fromFirestore).toList());
  }

  /// Sauvegarde toutes les équipes (supprime les anciennes et recrée).
  Future<void> saveTeams(
    String clubId,
    String tournamentId,
    List<TournamentTeam> teams,
  ) async {
    final col = _teamsCol(clubId, tournamentId);
    final existingSnap = await col.get();

    const int chunkSize = 400;
    final List<Map<String, dynamic>> ops = [];

    for (final doc in existingSnap.docs) {
      ops.add({'type': 'delete', 'ref': doc.reference});
    }
    for (final team in teams) {
      final ref = team.id.isEmpty ? col.doc() : col.doc(team.id);
      ops.add({'type': 'set', 'ref': ref, 'data': team.toFirestore()});
    }

    for (int i = 0; i < ops.length; i += chunkSize) {
      final chunk = ops.sublist(i, min(i + chunkSize, ops.length));
      final batch = _db.batch();
      for (final op in chunk) {
        if (op['type'] == 'delete') {
          batch.delete(
              op['ref'] as DocumentReference<Map<String, dynamic>>);
        } else {
          batch.set(
            op['ref'] as DocumentReference<Map<String, dynamic>>,
            op['data'] as Map<String, dynamic>,
          );
        }
      }
      await batch.commit();
    }
  }

  /// Échange deux joueurs entre deux équipes (transaction atomique).
  /// Conserve un historique capé à 100 entrées sur le doc tournoi.
  Future<void> swapPlayers({
    required String clubId,
    required String tournamentId,
    required String playerAId,
    required String fromTeamId,
    required String playerBId,
    required String toTeamId,
  }) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final teamARef = _teamsCol(clubId, tournamentId).doc(fromTeamId);
    final teamBRef = _teamsCol(clubId, tournamentId).doc(toTeamId);
    final tournamentRef = _tournamentRef(clubId, tournamentId);

    await _db.runTransaction((tx) async {
      final snapA = await tx.get(teamARef);
      final snapB = await tx.get(teamBRef);

      final listA =
          List<String>.from(snapA.data()?['playerIds'] as List? ?? []);
      final listB =
          List<String>.from(snapB.data()?['playerIds'] as List? ?? []);

      if (!listA.contains(playerAId) || !listB.contains(playerBId)) {
        throw Exception('Joueurs introuvables dans leurs équipes.');
      }

      listA.remove(playerAId);
      listA.add(playerBId);
      listB.remove(playerBId);
      listB.add(playerAId);

      tx.update(teamARef, {'playerIds': listA});
      tx.update(teamBRef, {'playerIds': listB});

      // Historique (cap 100)
      final tournSnap = await tx.get(tournamentRef);
      final rawHistory = List<Map<String, dynamic>>.from(
        (tournSnap.data()?['swapHistory'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );
      rawHistory.add({
        'playerId': playerAId,
        'fromTeamId': fromTeamId,
        'toTeamId': toTeamId,
        'swappedAt': Timestamp.now(),
        'swappedBy': adminUid,
      });
      rawHistory.add({
        'playerId': playerBId,
        'fromTeamId': toTeamId,
        'toTeamId': fromTeamId,
        'swappedAt': Timestamp.now(),
        'swappedBy': adminUid,
      });
      final trimmed = rawHistory.length > 100
          ? rawHistory.sublist(rawHistory.length - 100)
          : rawHistory;

      tx.update(tournamentRef, {'swapHistory': trimmed});
    });
  }

  // ─── Phases & Matches ────────────────────────────────────────────────────

  Stream<List<TournamentPhase>> watchPhases(
      String clubId, String tournamentId) {
    return _phasesCol(clubId, tournamentId)
        .orderBy('index')
        .snapshots()
        .map((snap) =>
            snap.docs.map(TournamentPhase.fromFirestore).toList());
  }

  Stream<List<TournamentMatch>> watchMatches(
      String clubId, String tournamentId) {
    return _matchesCol(clubId, tournamentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map(TournamentMatch.fromFirestore).toList());
  }

  Stream<List<TournamentMatch>> watchMatchesByPhase(
      String clubId, String tournamentId, String phaseId) {
    return _matchesCol(clubId, tournamentId)
        .where('phaseId', isEqualTo: phaseId)
        .snapshots()
        .map((snap) =>
            snap.docs.map(TournamentMatch.fromFirestore).toList());
  }

  /// Stream combiné phases + matchs + équipes → un seul StreamBuilder suffit.
  Stream<TournamentData> watchTournamentData(
      String clubId, String tournamentId) {
    List<TournamentPhase>? phases;
    List<TournamentMatch>? matches;
    List<TournamentTeam>? teams;
    final subs = <StreamSubscription<dynamic>>[];
    late final StreamController<TournamentData> controller;

    void tryEmit() {
      if (!controller.isClosed &&
          phases != null &&
          matches != null &&
          teams != null) {
        controller.add(TournamentData(
          phases: phases!,
          matches: matches!,
          teams: teams!,
        ));
      }
    }

    controller = StreamController<TournamentData>(
      onListen: () {
        subs.add(watchPhases(clubId, tournamentId).listen(
          (p) {
            phases = p;
            tryEmit();
          },
          onError: controller.addError,
        ));
        subs.add(watchMatches(clubId, tournamentId).listen(
          (m) {
            matches = m;
            tryEmit();
          },
          onError: controller.addError,
        ));
        subs.add(watchTeams(clubId, tournamentId).listen(
          (t) {
            teams = t;
            tryEmit();
          },
          onError: controller.addError,
        ));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );

    return controller.stream;
  }

  // ─── Statut ──────────────────────────────────────────────────────────────

  Future<void> updateStatus(
      String clubId, String tournamentId, TournamentStatus status) async {
    final ref = _tournamentRef(clubId, tournamentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Tournoi introuvable.');
      }
      final current =
          TournamentStatusExt.fromString(snap.data()?['status'] as String?);
      if (!_isValidStatusTransition(current, status)) {
        throw Exception(
            'Transition de statut invalide: ${current.value} → ${status.value}');
      }
      tx.update(ref, {
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool _isValidStatusTransition(TournamentStatus from, TournamentStatus to) {
    if (from == to) return true;
    switch (from) {
      case TournamentStatus.draft:
        return to == TournamentStatus.active;
      case TournamentStatus.active:
        return to == TournamentStatus.completed;
      case TournamentStatus.completed:
        return to == TournamentStatus.archived;
      case TournamentStatus.archived:
        return false;
    }
  }

  // ─── Génération du tournoi ───────────────────────────────────────────────

  /// Génère toutes les phases et les matchs en fonction de la structure.
  /// Appelé une seule fois après la confirmation des équipes (Step 4).
  Future<void> generateTournament(
    String clubId,
    TournamentModel tournament,
    List<TournamentTeam> teams,
  ) async {
    // Marqueur de début
    await _tournamentRef(clubId, tournament.id)
        .update({'generationStatus': 'pending', 'status': 'active'});

    final List<Map<String, dynamic>> ops = [];
    int phaseIndex = 0;

    final teamIds = teams.map((t) => t.id).toList();

    switch (tournament.structure) {
      case TournamentStructure.championnatSeul:
        _addGroupPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: teamIds,
          nbGroups: 1,
          nbQualifiedPerGroup: teamIds.length,
        );
        break;

      case TournamentStructure.tournoiSeul:
        _addKnockoutPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: teamIds,
          phaseType: PhaseType.knockout,
        );
        break;

      case TournamentStructure.poulesVersTournoi:
        final groupPhaseId =
            _phasesCol(clubId, tournament.id).doc().id;
        _addGroupPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: teamIds,
          nbGroups: tournament.nbGroups,
          nbQualifiedPerGroup: tournament.nbQualifiedPerGroup,
          docId: groupPhaseId,
        );
        // Phase finale (placeholder — remplie lors de l'avancement)
        _addKnockoutPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: [], // sera remplie par checkAndAdvancePhase
          phaseType: PhaseType.knockout,
        );
        break;

      case TournamentStructure.poulesInterVersTournoi:
        _addGroupPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: teamIds,
          nbGroups: tournament.nbGroups,
          nbQualifiedPerGroup: tournament.nbQualifiedPerGroup,
        );
        _addGroupPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: [], // sera remplie par l'avancement
          nbGroups: tournament.nbIntermediateGroups,
          nbQualifiedPerGroup: tournament.nbQualifiedFromIntermediate,
        );
        _addKnockoutPhase(
          ops: ops,
          clubId: clubId,
          tournamentId: tournament.id,
          phaseIndex: phaseIndex++,
          teamIds: [],
          phaseType: PhaseType.knockout,
        );
        break;
    }

    // Bracket consolante (si activé + structure avec knockout)
    if (tournament.hasConsolationBracket &&
        tournament.structure != TournamentStructure.championnatSeul) {
      _addKnockoutPhase(
        ops: ops,
        clubId: clubId,
        tournamentId: tournament.id,
        phaseIndex: phaseIndex++,
        teamIds: [],
        phaseType: PhaseType.consolation,
      );
    }

    // Commit en chunks de 400 ops
    const int chunkSize = 400;
    for (int i = 0; i < ops.length; i += chunkSize) {
      final chunk = ops.sublist(i, min(i + chunkSize, ops.length));
      final batch = _db.batch();
      for (final op in chunk) {
        if (op['type'] == 'set') {
          batch.set(
            op['ref'] as DocumentReference<Map<String, dynamic>>,
            op['data'] as Map<String, dynamic>,
          );
        }
      }
      await batch.commit();
    }

    await _tournamentRef(clubId, tournament.id)
        .update({'generationStatus': 'complete'});
  }

  void _addGroupPhase({
    required List<Map<String, dynamic>> ops,
    required String clubId,
    required String tournamentId,
    required int phaseIndex,
    required List<String> teamIds,
    required int nbGroups,
    required int nbQualifiedPerGroup,
    String? docId,
  }) {
    final phaseRef = docId != null
        ? _phasesCol(clubId, tournamentId).doc(docId)
        : _phasesCol(clubId, tournamentId).doc();

    // Répartition des équipes dans les groupes
    final Map<int, List<String>> groups = {};
    for (int i = 0; i < nbGroups; i++) {
      groups[i] = [];
    }
    for (int i = 0; i < teamIds.length; i++) {
      groups[i % nbGroups]!.add(teamIds[i]);
    }

    int matchCount = 0;
    for (int g = 0; g < nbGroups; g++) {
      final groupTeams = groups[g]!;
      for (int i = 0; i < groupTeams.length; i++) {
        for (int j = i + 1; j < groupTeams.length; j++) {
          final matchRef = _matchesCol(clubId, tournamentId).doc();
          ops.add({
            'type': 'set',
            'ref': matchRef,
            'data': TournamentMatch(
              id: matchRef.id,
              phaseId: phaseRef.id,
              phaseType: PhaseType.group,
              phaseIndex: phaseIndex,
              groupIndex: g,
              teamAId: groupTeams[i],
              teamBId: groupTeams[j],
            ).toFirestore(),
          });
          matchCount++;
        }
      }
    }

    ops.add({
      'type': 'set',
      'ref': phaseRef,
      'data': TournamentPhase(
        id: phaseRef.id,
        type: PhaseType.group,
        index: phaseIndex,
        nbGroups: nbGroups,
        nbQualifiedPerGroup: nbQualifiedPerGroup,
        participatingTeamIds: teamIds,
        totalMatchCount: matchCount,
      ).toFirestore(),
    });
  }

  void _addKnockoutPhase({
    required List<Map<String, dynamic>> ops,
    required String clubId,
    required String tournamentId,
    required int phaseIndex,
    required List<String> teamIds,
    required PhaseType phaseType,
  }) {
    final phaseRef = _phasesCol(clubId, tournamentId).doc();

    int matchCount = 0;
    if (teamIds.isNotEmpty) {
      matchCount = _generateKnockoutMatches(
        ops: ops,
        clubId: clubId,
        tournamentId: tournamentId,
        phaseId: phaseRef.id,
        phaseIndex: phaseIndex,
        teamIds: teamIds,
        phaseType: phaseType,
      );
    }

    ops.add({
      'type': 'set',
      'ref': phaseRef,
      'data': TournamentPhase(
        id: phaseRef.id,
        type: phaseType,
        index: phaseIndex,
        participatingTeamIds: teamIds,
        totalMatchCount: matchCount,
      ).toFirestore(),
    });
  }

  /// Génère les matchs d'un bracket éliminatoire.
  /// Retourne le nombre de matchs générés.
  int _generateKnockoutMatches({
    required List<Map<String, dynamic>> ops,
    required String clubId,
    required String tournamentId,
    required String phaseId,
    required int phaseIndex,
    required List<String> teamIds,
    required PhaseType phaseType,
  }) {
    final int n = teamIds.length;
    if (n < 2) return 0;

    // Arrondir à la puissance de 2 supérieure
    int bracketSize = 1;
    while (bracketSize < n) {
      bracketSize <<= 1;
    }
    final int nbRounds = bracketSize.bitLength - 1; // log2(bracketSize)
    int matchCount = 0;

    // Premier tour
    final List<String?> firstRoundTeams = List.filled(bracketSize, null);
    for (int i = 0; i < n; i++) {
      firstRoundTeams[i] = teamIds[i];
    }

    final int firstRoundMatches = bracketSize ~/ 2;
    final List<String> firstRoundMatchIds = [];

    for (int slot = 0; slot < firstRoundMatches; slot++) {
      final teamA = firstRoundTeams[slot * 2];
      final teamB = firstRoundTeams[slot * 2 + 1];
      final isBye = teamA == null || teamB == null;

      final matchRef = _matchesCol(clubId, tournamentId).doc();
      firstRoundMatchIds.add(matchRef.id);

      // Les matchs BYE sont auto-complétés
      final status =
          isBye ? MatchStatus.completed : MatchStatus.upcoming;
      final sA = (teamA == null && teamB != null) ? 0 : 0;
      final sB = (teamB == null && teamA != null) ? 0 : 0;

      ops.add({
        'type': 'set',
        'ref': matchRef,
        'data': TournamentMatch(
          id: matchRef.id,
          phaseId: phaseId,
          phaseType: phaseType,
          phaseIndex: phaseIndex,
          round: nbRounds - 1,
          bracketSlot: slot,
          teamAId: teamA,
          teamBId: teamB,
          scoreA: sA,
          scoreB: sB,
          status: status,
        ).toFirestore(),
      });
      if (!isBye) matchCount++;
    }

    // Rounds suivants (placeholders)
    int currentRoundMatches = firstRoundMatches ~/ 2;
    int currentRound = nbRounds - 2;
    while (currentRoundMatches >= 1 && currentRound >= 0) {
      for (int slot = 0; slot < currentRoundMatches; slot++) {
        final matchRef = _matchesCol(clubId, tournamentId).doc();
        ops.add({
          'type': 'set',
          'ref': matchRef,
          'data': TournamentMatch(
            id: matchRef.id,
            phaseId: phaseId,
            phaseType: phaseType,
            phaseIndex: phaseIndex,
            round: currentRound,
            bracketSlot: slot,
          ).toFirestore(),
        });
        matchCount++;
      }
      currentRoundMatches ~/= 2;
      currentRound--;
    }

    return matchCount;
  }

  // ─── Saisie de score ─────────────────────────────────────────────────────

  Future<void> updateMatchScore(
    String clubId,
    String tournamentId,
    String matchId,
    int scoreA,
    int scoreB, {
    required bool markCompleted,
  }) async {
    final matchRef = _matchesCol(clubId, tournamentId).doc(matchId);
    final newStatus =
        markCompleted ? MatchStatus.completed : MatchStatus.inProgress;
    String phaseId = '';
    bool shouldAdvancePhase = false;

    await _db.runTransaction((tx) async {
      final matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) {
        throw Exception('Match introuvable.');
      }
      final data = matchSnap.data() ?? {};
      phaseId = data['phaseId'] as String? ?? '';
      final previousStatus =
          MatchStatusExt.fromString(data['status'] as String?);

      tx.update(matchRef, {
        'scoreA': scoreA,
        'scoreB': scoreB,
        'status': newStatus.value,
      });

      if (phaseId.isEmpty || previousStatus == newStatus) return;
      final phaseRef = _phasesCol(clubId, tournamentId).doc(phaseId);
      if (previousStatus != MatchStatus.completed &&
          newStatus == MatchStatus.completed) {
        tx.update(phaseRef, {
          'completedMatchCount': FieldValue.increment(1),
        });
        shouldAdvancePhase = true;
      } else if (previousStatus == MatchStatus.completed &&
          newStatus != MatchStatus.completed) {
        tx.update(phaseRef, {
          'completedMatchCount': FieldValue.increment(-1),
          'isComplete': false,
        });
      }
    });

    if (shouldAdvancePhase && phaseId.isNotEmpty) {
      await checkAndAdvancePhase(clubId, tournamentId, phaseId);
    }
  }


  // ─── Avancement de phase ─────────────────────────────────────────────────

  Future<void> checkAndAdvancePhase(
    String clubId,
    String tournamentId,
    String phaseId,
  ) async {
    final phaseRef = _phasesCol(clubId, tournamentId).doc(phaseId);
    final phaseSnap = await phaseRef.get();
    if (!phaseSnap.exists) return;
    final phase = TournamentPhase.fromFirestore(phaseSnap);

    if (phase.isComplete) return;
    if (phase.completedMatchCount < phase.totalMatchCount) return;

    // Calculer les qualifiés
    final matchesSnap = await _matchesCol(clubId, tournamentId)
        .where('phaseId', isEqualTo: phaseId)
        .get();
    final matches =
        matchesSnap.docs.map(TournamentMatch.fromFirestore).toList();

    List<String> qualifiedIds = [];

    if (phase.type == PhaseType.group) {
      qualifiedIds = _extractGroupQualifiers(matches, phase);
    } else if (phase.type == PhaseType.knockout ||
        phase.type == PhaseType.consolation) {
      // Le gagnant du match final
      final finalMatch = matches
          .where((m) => m.round == 0 && m.status == MatchStatus.completed)
          .toList();
      if (finalMatch.isNotEmpty && finalMatch.first.winnerId != null) {
        qualifiedIds = [finalMatch.first.winnerId!];
      }
    }

    final batch = _db.batch();
    batch.update(phaseRef, {
      'isComplete': true,
      'qualifiedTeamIds': qualifiedIds,
    });

    // Chercher la phase suivante (même type de structure)
    final tournSnap =
        await _tournamentRef(clubId, tournamentId).get();
    if (!tournSnap.exists) {
      await batch.commit();
      return;
    }
    final tournament = TournamentModel.fromFirestore(tournSnap);

    final nextPhasesSnap = await _phasesCol(clubId, tournamentId)
        .where('index', isEqualTo: phase.index + 1)
        .get();

    if (nextPhasesSnap.docs.isEmpty) {
      // Dernier phase — tournoi terminé
      batch.update(_tournamentRef(clubId, tournamentId),
          {'status': TournamentStatus.completed.value});
      await batch.commit();
      return;
    }

    await batch.commit();

    // Remplir la phase suivante si c'est une phase de groupes vide
    final nextPhaseDoc = nextPhasesSnap.docs.first;
    final nextPhase = TournamentPhase.fromFirestore(nextPhaseDoc);

    if (nextPhase.participatingTeamIds.isEmpty &&
        qualifiedIds.isNotEmpty) {
      await _populateNextPhase(
        clubId: clubId,
        tournamentId: tournamentId,
        nextPhase: nextPhase,
        teamIds: qualifiedIds,
        tournament: tournament,
      );
    }
  }

  Future<void> _populateNextPhase({
    required String clubId,
    required String tournamentId,
    required TournamentPhase nextPhase,
    required List<String> teamIds,
    required TournamentModel tournament,
  }) async {
    final ops = <Map<String, dynamic>>[];

    if (nextPhase.type == PhaseType.group) {
      // Recalculer le nombre de groupes selon config
      int nbGroups;
      int nbQualified;
      if (nextPhase.index == 1 &&
          tournament.structure ==
              TournamentStructure.poulesInterVersTournoi) {
        nbGroups = tournament.nbIntermediateGroups;
        nbQualified = tournament.nbQualifiedFromIntermediate;
      } else {
        nbGroups = nextPhase.nbGroups;
        nbQualified = nextPhase.nbQualifiedPerGroup;
      }

      // Supprimer les placeholders de la phase et recréer
      final existingMatches = await _matchesCol(clubId, tournamentId)
          .where('phaseId', isEqualTo: nextPhase.id)
          .get();
      for (final doc in existingMatches.docs) {
        ops.add({'type': 'delete', 'ref': doc.reference});
      }

      _addGroupPhaseInPlace(
        ops: ops,
        clubId: clubId,
        tournamentId: tournamentId,
        phase: nextPhase,
        teamIds: teamIds,
        nbGroups: nbGroups,
        nbQualifiedPerGroup: nbQualified,
      );
    } else if (nextPhase.type == PhaseType.knockout ||
        nextPhase.type == PhaseType.consolation) {
      final existingMatches = await _matchesCol(clubId, tournamentId)
          .where('phaseId', isEqualTo: nextPhase.id)
          .get();
      for (final doc in existingMatches.docs) {
        ops.add({'type': 'delete', 'ref': doc.reference});
      }

      final matchCount = _generateKnockoutMatches(
        ops: ops,
        clubId: clubId,
        tournamentId: tournamentId,
        phaseId: nextPhase.id,
        phaseIndex: nextPhase.index,
        teamIds: teamIds,
        phaseType: nextPhase.type,
      );

      final phaseRef =
          _phasesCol(clubId, tournamentId).doc(nextPhase.id);
      ops.add({
        'type': 'update',
        'ref': phaseRef,
        'data': {
          'participatingTeamIds': teamIds,
          'totalMatchCount': matchCount,
          'completedMatchCount': 0,
        },
      });
    }

    const int chunkSize = 400;
    for (int i = 0; i < ops.length; i += chunkSize) {
      final chunk = ops.sublist(i, min(i + chunkSize, ops.length));
      final batch = _db.batch();
      for (final op in chunk) {
        if (op['type'] == 'delete') {
          batch.delete(
              op['ref'] as DocumentReference<Map<String, dynamic>>);
        } else if (op['type'] == 'set') {
          batch.set(
            op['ref'] as DocumentReference<Map<String, dynamic>>,
            op['data'] as Map<String, dynamic>,
          );
        } else if (op['type'] == 'update') {
          batch.update(
            op['ref'] as DocumentReference<Map<String, dynamic>>,
            op['data'] as Map<String, dynamic>,
          );
        }
      }
      await batch.commit();
    }
  }

  void _addGroupPhaseInPlace({
    required List<Map<String, dynamic>> ops,
    required String clubId,
    required String tournamentId,
    required TournamentPhase phase,
    required List<String> teamIds,
    required int nbGroups,
    required int nbQualifiedPerGroup,
  }) {
    final Map<int, List<String>> groups = {};
    for (int i = 0; i < nbGroups; i++) {
      groups[i] = [];
    }
    for (int i = 0; i < teamIds.length; i++) {
      groups[i % nbGroups]!.add(teamIds[i]);
    }

    int matchCount = 0;
    for (int g = 0; g < nbGroups; g++) {
      final groupTeams = groups[g]!;
      for (int i = 0; i < groupTeams.length; i++) {
        for (int j = i + 1; j < groupTeams.length; j++) {
          final matchRef = _matchesCol(clubId, tournamentId).doc();
          ops.add({
            'type': 'set',
            'ref': matchRef,
            'data': TournamentMatch(
              id: matchRef.id,
              phaseId: phase.id,
              phaseType: PhaseType.group,
              phaseIndex: phase.index,
              groupIndex: g,
              teamAId: groupTeams[i],
              teamBId: groupTeams[j],
            ).toFirestore(),
          });
          matchCount++;
        }
      }
    }

    final phaseRef =
        _phasesCol(clubId, tournamentId).doc(phase.id);
    ops.add({
      'type': 'update',
      'ref': phaseRef,
      'data': {
        'participatingTeamIds': teamIds,
        'nbGroups': nbGroups,
        'nbQualifiedPerGroup': nbQualifiedPerGroup,
        'totalMatchCount': matchCount,
        'completedMatchCount': 0,
      },
    });
  }

  List<String> _extractGroupQualifiers(
      List<TournamentMatch> matches, TournamentPhase phase) {
    // Calculer les classements en utilisant la méthode du modèle
    final standings =
        phase.computeGroupStandings(matches);

    final List<String> qualifiedIds = [];
    final sortedGroupKeys = standings.keys.toList()..sort();

    for (final g in sortedGroupKeys) {
      final groupStandings = standings[g]!;
      final qualified = groupStandings
          .take(phase.nbQualifiedPerGroup)
          .map((s) => s.teamId)
          .toList();
      qualifiedIds.addAll(qualified);
    }
    return qualifiedIds;
  }

  // ─── Classement final ────────────────────────────────────────────────────

  Future<List<TournamentStanding>> computeFinalStandings(
    String clubId,
    String tournamentId,
  ) async {
    final matchesSnap =
        await _matchesCol(clubId, tournamentId).get();
    final teamsSnap =
        await _teamsCol(clubId, tournamentId).get();

    final matches =
        matchesSnap.docs.map(TournamentMatch.fromFirestore).toList();
    final teams =
        teamsSnap.docs.map(TournamentTeam.fromFirestore).toList();
    final teamsById = {for (final t in teams) t.id: t};

    // Chercher le match final knockout
    final knockoutFinal = matches
        .where((m) =>
            m.phaseType == PhaseType.knockout &&
            m.round == 0 &&
            m.status == MatchStatus.completed &&
            m.teamAId != null &&
            m.teamBId != null)
        .toList();

    if (knockoutFinal.isEmpty) {
      // Championnat seul : classement par points
      return _computeLeagueStandings(matches, teamsById);
    }

    final finalMatch = knockoutFinal.first;
    final standings = <TournamentStanding>[];
    final assignedRanks = <String>{};

    // Rank 1 & 2
    if (finalMatch.winnerId != null) {
      standings.add(TournamentStanding(rank: 1, teamId: finalMatch.winnerId!));
      assignedRanks.add(finalMatch.winnerId!);
    }
    if (finalMatch.loserId != null) {
      standings.add(TournamentStanding(rank: 2, teamId: finalMatch.loserId!));
      assignedRanks.add(finalMatch.loserId!);
    }

    // Rank 3 & 4 (consolation ou petite finale / perdants des demies)
    final consolationFinal = matches
        .where((m) =>
            m.phaseType == PhaseType.consolation &&
            m.round == 0 &&
            m.status == MatchStatus.completed &&
            m.teamAId != null &&
            m.teamBId != null)
        .toList();

    if (consolationFinal.isNotEmpty) {
      final cf = consolationFinal.first;
      if (cf.winnerId != null && !assignedRanks.contains(cf.winnerId)) {
        standings.add(TournamentStanding(rank: 3, teamId: cf.winnerId!));
        assignedRanks.add(cf.winnerId!);
      }
      if (cf.loserId != null && !assignedRanks.contains(cf.loserId)) {
        standings.add(TournamentStanding(rank: 4, teamId: cf.loserId!));
        assignedRanks.add(cf.loserId!);
      }
    } else {
      // Perdants des demies partagent la 3e place
      final semiLosers = matches
          .where((m) =>
              m.phaseType == PhaseType.knockout &&
              m.round == 1 &&
              m.status == MatchStatus.completed &&
              m.loserId != null)
          .map((m) => m.loserId!)
          .where((id) => !assignedRanks.contains(id))
          .toSet()
          .toList();
      for (final id in semiLosers) {
        standings.add(TournamentStanding(rank: 3, teamId: id));
        assignedRanks.add(id);
      }
    }

    // Rangs suivants : par vague d'élimination (round décroissant)
    final maxRound = matches
        .where((m) => m.phaseType == PhaseType.knockout && m.round != null)
        .fold<int>(0, (max, m) => m.round! > max ? m.round! : max);

    int currentRank = standings.length + 1;
    for (int r = 2; r <= maxRound; r++) {
      final losers = matches
          .where((m) =>
              m.phaseType == PhaseType.knockout &&
              m.round == r &&
              m.status == MatchStatus.completed &&
              m.loserId != null &&
              !assignedRanks.contains(m.loserId))
          .map((m) => m.loserId!)
          .toSet()
          .toList();
      for (final id in losers) {
        standings.add(TournamentStanding(rank: currentRank, teamId: id));
        assignedRanks.add(id);
      }
      if (losers.isNotEmpty) currentRank += losers.length;
    }

    // Équipes non classées (non encore éliminées ou absentes du bracket)
    for (final team in teams) {
      if (!assignedRanks.contains(team.id)) {
        standings.add(
            TournamentStanding(rank: currentRank++, teamId: team.id));
      }
    }

    return standings;
  }

  /// Version synchrone de [computeFinalStandings] — utilise des données déjà chargées.
  /// Permet un classement en temps réel via StreamBuilder.
  List<TournamentStanding> computeFinalStandingsSync(
    List<TournamentMatch> matches,
    List<TournamentTeam> teams,
  ) {
    final teamsById = {for (final t in teams) t.id: t};

    final knockoutFinal = matches
        .where((m) =>
            m.phaseType == PhaseType.knockout &&
            m.round == 0 &&
            m.status == MatchStatus.completed &&
            m.teamAId != null &&
            m.teamBId != null)
        .toList();

    if (knockoutFinal.isEmpty) {
      return _computeLeagueStandings(matches, teamsById);
    }

    final finalMatch = knockoutFinal.first;
    final standings = <TournamentStanding>[];
    final assignedRanks = <String>{};

    if (finalMatch.winnerId != null) {
      standings.add(TournamentStanding(rank: 1, teamId: finalMatch.winnerId!));
      assignedRanks.add(finalMatch.winnerId!);
    }
    if (finalMatch.loserId != null) {
      standings.add(TournamentStanding(rank: 2, teamId: finalMatch.loserId!));
      assignedRanks.add(finalMatch.loserId!);
    }

    final consolationFinal = matches
        .where((m) =>
            m.phaseType == PhaseType.consolation &&
            m.round == 0 &&
            m.status == MatchStatus.completed &&
            m.teamAId != null &&
            m.teamBId != null)
        .toList();

    if (consolationFinal.isNotEmpty) {
      final cf = consolationFinal.first;
      if (cf.winnerId != null && !assignedRanks.contains(cf.winnerId)) {
        standings.add(TournamentStanding(rank: 3, teamId: cf.winnerId!));
        assignedRanks.add(cf.winnerId!);
      }
      if (cf.loserId != null && !assignedRanks.contains(cf.loserId)) {
        standings.add(TournamentStanding(rank: 4, teamId: cf.loserId!));
        assignedRanks.add(cf.loserId!);
      }
    } else {
      final semiLosers = matches
          .where((m) =>
              m.phaseType == PhaseType.knockout &&
              m.round == 1 &&
              m.status == MatchStatus.completed &&
              m.loserId != null)
          .map((m) => m.loserId!)
          .where((id) => !assignedRanks.contains(id))
          .toSet()
          .toList();
      for (final id in semiLosers) {
        standings.add(TournamentStanding(rank: 3, teamId: id));
        assignedRanks.add(id);
      }
    }

    final maxRound = matches
        .where((m) => m.phaseType == PhaseType.knockout && m.round != null)
        .fold<int>(0, (max, m) => m.round! > max ? m.round! : max);

    int currentRank = standings.length + 1;
    for (int r = 2; r <= maxRound; r++) {
      final losers = matches
          .where((m) =>
              m.phaseType == PhaseType.knockout &&
              m.round == r &&
              m.status == MatchStatus.completed &&
              m.loserId != null &&
              !assignedRanks.contains(m.loserId))
          .map((m) => m.loserId!)
          .toSet()
          .toList();
      for (final id in losers) {
        standings.add(TournamentStanding(rank: currentRank, teamId: id));
        assignedRanks.add(id);
      }
      if (losers.isNotEmpty) currentRank += losers.length;
    }

    for (final team in teams) {
      if (!assignedRanks.contains(team.id)) {
        standings.add(TournamentStanding(rank: currentRank++, teamId: team.id));
      }
    }

    return standings;
  }

  List<TournamentStanding> _computeLeagueStandings(
    List<TournamentMatch> matches,
    Map<String, TournamentTeam> teamsById,
  ) {
    final Map<String, _LeagueStats> stats = {};

    for (final team in teamsById.keys) {
      stats[team] = _LeagueStats(teamId: team);
    }

    for (final m in matches) {
      if (m.status != MatchStatus.completed) continue;
      if (m.teamAId == null || m.teamBId == null) continue;

      stats.putIfAbsent(m.teamAId!, () => _LeagueStats(teamId: m.teamAId!));
      stats.putIfAbsent(m.teamBId!, () => _LeagueStats(teamId: m.teamBId!));

      final sA = stats[m.teamAId!]!;
      final sB = stats[m.teamBId!]!;

      sA.goalsFor += m.scoreA;
      sA.goalsAgainst += m.scoreB;
      sB.goalsFor += m.scoreB;
      sB.goalsAgainst += m.scoreA;

      if (m.scoreA > m.scoreB) {
        sA.wins++;
        sB.losses++;
      } else if (m.scoreB > m.scoreA) {
        sB.wins++;
        sA.losses++;
      } else {
        sA.draws++;
        sB.draws++;
      }
    }

    final sorted = stats.values.toList()
      ..sort((a, b) {
        final ptsDiff = b.points.compareTo(a.points);
        if (ptsDiff != 0) return ptsDiff;
        final gdDiff = (b.goalsFor - b.goalsAgainst)
            .compareTo(a.goalsFor - a.goalsAgainst);
        if (gdDiff != 0) return gdDiff;
        return b.goalsFor.compareTo(a.goalsFor);
      });

    return sorted.asMap().entries.map((e) {
      final s = e.value;
      return TournamentStanding(
        rank: e.key + 1,
        teamId: s.teamId,
        wins: s.wins,
        draws: s.draws,
        losses: s.losses,
        goalsFor: s.goalsFor,
        goalsAgainst: s.goalsAgainst,
        points: s.points,
      );
    }).toList();
  }
}

class _LeagueStats {
  final String teamId;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  _LeagueStats({required this.teamId});

  int get points => wins * 3 + draws;
}
