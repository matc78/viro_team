import 'package:flutter/material.dart';
import '../../models/training_session_attendance.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/club_stats_hub_loader.dart';
import '../../utils/player_club_stats_helpers.dart';
import '../../widget/viro_loader.dart';

/// Statistiques agrégées du club : effectif, événements, moyennes et classements.
class AdminClubStatsHubPage extends StatelessWidget {
  final String clubId;

  const AdminClubStatsHubPage({super.key, required this.clubId});

  Future<ClubStatsHubSnapshot?> _load() async {
    try {
      return await loadClubStatsHubSnapshot(clubId);
    } catch (e, st) {
      AppLogger.instance.error(
        'AdminClubStatsHubPage load',
        error: e,
        stackTrace: st,
        context: {'clubId': clubId},
      );
      return null;
    }
  }

  static String _fmtInt(int v) => v < 0 ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Statistiques du club'),
        centerTitle: true,
      ),
      body: FutureBuilder<ClubStatsHubSnapshot?>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 48));
          }
          final data = snap.data;
          if (data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Impossible de charger les statistiques. Réessayez plus tard.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Saison ${computeSeason(DateTime.now())} · Données joueurs : agrégats sur le compte '
                '(présences séance, réponses convocation).',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Effectif & structure'),
              const SizedBox(height: 10),
              _metricsWrap(
                [
                  _MetricTile(
                    icon: Icons.sports_handball_rounded,
                    label: 'Joueurs',
                    value: _fmtInt(data.playersCount),
                    color: ViroColors.primary,
                  ),
                  _MetricTile(
                    icon: Icons.groups_rounded,
                    label: 'Équipes',
                    value: _fmtInt(data.teamsCount),
                    color: Colors.indigo,
                  ),
                  _MetricTile(
                    icon: Icons.sports_rounded,
                    label: 'Coachs',
                    value: '${data.coachesCount}',
                    color: Colors.teal,
                  ),
                  _MetricTile(
                    icon: Icons.shield_outlined,
                    label: 'Admins',
                    value: '${data.adminsCount}',
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('Événements'),
              const SizedBox(height: 6),
              const Text(
                'Le total correspond en général à : entraînements passés + matchs passés + '
                'autres passés + à venir. « Autres » regroupe les types « Évènement », « Autre » '
                'ou un ancien libellé de type.',
                style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.3),
              ),
              const SizedBox(height: 10),
              _metricsWrap(
                [
                  _MetricTile(
                    icon: Icons.event_note_outlined,
                    label: 'Total',
                    value: _fmtInt(data.eventsTotal),
                    color: Colors.blueGrey,
                  ),
                  _MetricTile(
                    icon: Icons.fitness_center,
                    label: 'Entraînements passés',
                    value: _fmtInt(data.trainingsPast),
                    color: ViroColors.primary,
                  ),
                  _MetricTile(
                    icon: Icons.sports_soccer_outlined,
                    label: 'Matchs passés',
                    value: _fmtInt(data.matchesPast),
                    color: Colors.green.shade700,
                  ),
                  _MetricTile(
                    icon: Icons.more_time_outlined,
                    label: 'Autres passés',
                    value: _fmtInt(data.otherPast),
                    color: Colors.brown.shade600,
                  ),
                  _MetricTile(
                    icon: Icons.upcoming_outlined,
                    label: 'À venir',
                    value: _fmtInt(data.eventsUpcoming),
                    color: Colors.orange.shade800,
                  ),
                ],
                maxCross: 3,
              ),
              const SizedBox(height: 24),
              _sectionTitle('Moyennes (membres avec au moins une donnée)'),
              const SizedBox(height: 8),
              Text(
                'Échantillon : ${data.sampleSize} joueur(s).',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: ViroColors.borderColor),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Présence réelle moyenne (séance)'),
                      subtitle: const Text(
                        'Présent + retard, sur séances pointées',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        formatPercent(data.avgTrainingReal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ViroColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Part moyenne « présent » annoncé'),
                      subtitle: const Text(
                        'Entraînements · parmi les réponses enregistrées',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        formatPercent(data.avgRsvpPresent),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ViroColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Top 3 — taux de présence réelle (séance)'),
              const SizedBox(height: 8),
              _rankList(
                data.topPresenceReal,
                empty: 'Pas assez de pointages de séance pour classer.',
              ),
              const SizedBox(height: 20),
              _sectionTitle('À suivre — plus faibles taux (séance)'),
              const SizedBox(height: 8),
              _rankList(
                data.worstPresenceReal,
                empty: 'Pas assez de pointages pour ce classement.',
              ),
              const SizedBox(height: 24),
              _sectionTitle('Top 3 — réponses convocation (entraînement)'),
              const SizedBox(height: 8),
              _rankList(
                data.topRsvpTraining,
                empty: 'Pas encore de réponses enregistrées.',
              ),
              const SizedBox(height: 20),
              _sectionTitle('À suivre — réponses convocation (entraînement)'),
              const SizedBox(height: 8),
              _rankList(
                data.worstRsvpTraining,
                empty: 'Pas assez de données.',
              ),
              const SizedBox(height: 24),
              _sectionTitle('Top 3 — retards en séance'),
              const SizedBox(height: 8),
              _lateList(
                data.topLate,
                empty: 'Aucun retard enregistré sur la saison.',
              ),
              const SizedBox(height: 24),
              _sectionTitle('Top 3 — réponses convocation (match)'),
              const SizedBox(height: 8),
              _rankList(
                data.topMatchRsvp,
                empty: 'Pas encore de réponses match.',
              ),
              const SizedBox(height: 20),
              _sectionTitle('À suivre — réponses convocation (match)'),
              const SizedBox(height: 8),
              _rankList(
                data.worstMatchRsvp,
                empty: 'Pas assez de données match.',
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 0.6,
        color: Colors.black54,
      ),
    );
  }

  static Widget _metricsWrap(
    List<Widget> tiles, {
    int maxCross = 4,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cap = maxCross.clamp(2, 6);
        final cross = w > 520 ? cap : 2;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: tiles,
        );
      },
    );
  }

  static Widget _rankList(
    List<ClubPlayerRank> rows, {
    required String empty,
  }) {
    if (rows.isEmpty) {
      return Text(empty, style: const TextStyle(color: Colors.grey));
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _rankTile(i + 1, rows[i]),
        ],
      ],
    );
  }

  static Widget _lateList(
    List<ClubPlayerLateRank> rows, {
    required String empty,
  }) {
    if (rows.isEmpty) {
      return Text(empty, style: const TextStyle(color: Colors.grey));
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _lateTile(i + 1, rows[i]),
        ],
      ],
    );
  }

  static Widget _rankTile(int rank, ClubPlayerRank r) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : '🥉';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              medal,
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              r.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            r.valueLabel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: ViroColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _lateTile(int rank, ClubPlayerLateRank r) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : '🥉';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              medal,
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              r.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${r.lateCount}×',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
