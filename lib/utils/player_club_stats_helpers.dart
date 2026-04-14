import '../constants/player_stats_policy.dart';
import '../models/training_session_attendance.dart';

/// Statistiques agrégées pour un club et la saison courante (clé `clubId_saison`).
class PlayerSeasonStats {
  final String statsKey;
  final int trainingTotal;
  final int trainingPresent;
  final int trainingLate;
  final int trainingAbsent;
  final int rsvpAnswered;
  final int rsvpPresent;
  final int rsvpAbsent;
  final int rsvpDelaySumSec;
  final int rsvpDelayCount;
  final int matchAnswered;
  final int matchPresent;
  final int matchAbsent;
  final int matchDelaySumSec;
  final int matchDelayCount;

  const PlayerSeasonStats({
    required this.statsKey,
    this.trainingTotal = 0,
    this.trainingPresent = 0,
    this.trainingLate = 0,
    this.trainingAbsent = 0,
    this.rsvpAnswered = 0,
    this.rsvpPresent = 0,
    this.rsvpAbsent = 0,
    this.rsvpDelaySumSec = 0,
    this.rsvpDelayCount = 0,
    this.matchAnswered = 0,
    this.matchPresent = 0,
    this.matchAbsent = 0,
    this.matchDelaySumSec = 0,
    this.matchDelayCount = 0,
  });

  /// Présence réelle : (présent + retard) / total séances pointées.
  double? get trainingRealRate {
    if (trainingTotal <= 0) return null;
    return (trainingPresent + trainingLate) / trainingTotal;
  }

  /// Part de « présent » parmi les réponses enregistrées (entraînement).
  double? get rsvpPresentAmongAnswered {
    final n = rsvpPresent + rsvpAbsent;
    if (n <= 0) return null;
    return rsvpPresent / n;
  }

  /// Délai moyen (secondes) avant une réponse « présent » (entraînements).
  double? get avgRsvpDelaySec {
    if (rsvpDelayCount <= 0) return null;
    return rsvpDelaySumSec / rsvpDelayCount;
  }

  double? get matchPresentAmongAnswered {
    final n = matchPresent + matchAbsent;
    if (n <= 0) return null;
    return matchPresent / n;
  }

  double? get avgMatchRsvpDelaySec {
    if (matchDelayCount <= 0) return null;
    return matchDelaySumSec / matchDelayCount;
  }

  bool get hasAnyData =>
      trainingTotal > 0 ||
      rsvpAnswered > 0 ||
      matchAnswered > 0;
}

int _i(Map<String, dynamic>? m, String k) {
  if (m == null) return 0;
  final v = m[k];
  if (v is int) return v;
  if (v is num) return v.round();
  return 0;
}

Map<String, dynamic>? _nested(Map<String, dynamic> root, String field, String key) {
  final raw = root[field];
  if (raw is! Map) return null;
  final inner = raw[key];
  if (inner is! Map) return null;
  return Map<String, dynamic>.from(inner);
}

/// Extrait les agrégats [PlayerSeasonStats] pour le club et la saison de [referenceDate].
PlayerSeasonStats playerSeasonStatsForClub(
  Map<String, dynamic> userData,
  String clubId, [
  DateTime? referenceDate,
]) {
  final ref = referenceDate ?? DateTime.now();
  final season = computeSeason(ref);
  final statsKey = '${clubId}_$season';

  final training = _nested(userData, 'trainingStats', statsKey);
  final rsvpT = _nested(userData, kRsvpTrainingStatsField, statsKey);
  final rsvpM = _nested(userData, kRsvpMatchStatsField, statsKey);

  return PlayerSeasonStats(
    statsKey: statsKey,
    trainingTotal: _i(training, 'total'),
    trainingPresent: _i(training, 'present'),
    trainingLate: _i(training, 'late'),
    trainingAbsent: _i(training, 'absent'),
    rsvpAnswered: _i(rsvpT, 'answered'),
    rsvpPresent: _i(rsvpT, 'present'),
    rsvpAbsent: _i(rsvpT, 'absent'),
    rsvpDelaySumSec: _i(rsvpT, 'delaySumSec'),
    rsvpDelayCount: _i(rsvpT, 'delayCount'),
    matchAnswered: _i(rsvpM, 'answered'),
    matchPresent: _i(rsvpM, 'present'),
    matchAbsent: _i(rsvpM, 'absent'),
    matchDelaySumSec: _i(rsvpM, 'delaySumSec'),
    matchDelayCount: _i(rsvpM, 'delayCount'),
  );
}

String formatPercent(double? v) {
  if (v == null) return '—';
  return '${(v * 100).round()} %';
}

String formatDurationFr(Duration d) {
  if (d.inMinutes < 120) {
    return '${d.inMinutes} min';
  }
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m.toString().padLeft(2, '0')}';
}

String formatAvgDelayFromStats(PlayerSeasonStats s) {
  final sec = s.avgRsvpDelaySec;
  if (sec == null) return '—';
  return formatDurationFr(Duration(seconds: sec.round()));
}

/// Ligne courte pour liste équipe (joueur).
String playerStatsOneLiner(PlayerSeasonStats s) {
  final tr = s.trainingRealRate;
  final pr = s.rsvpPresentAmongAnswered;
  if (!s.hasAnyData) return 'Stats : —';
  return 'Séance ${formatPercent(tr)} · Annonce ${formatPercent(pr)}';
}
