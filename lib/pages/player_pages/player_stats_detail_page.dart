import 'package:flutter/material.dart';
import '../../models/training_session_attendance.dart';
import '../../theme/viro_theme.dart';
import '../../utils/player_club_stats_helpers.dart';

/// Détail des statistiques club / saison pour le joueur connecté ou affichées par le staff.
class PlayerStatsDetailPage extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;

  const PlayerStatsDetailPage({
    super.key,
    required this.clubId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final s = playerSeasonStatsForClub(userData, clubId);
    final season = computeSeason(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        centerTitle: true,
      ),
      backgroundColor: ViroColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Saison $season · club actif',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _section(
            'Entraînements — présence sur la séance',
            [
              _tile(
                'Séances pointées',
                '${s.trainingTotal}',
              ),
              _tile(
                'Taux (présent + retard)',
                formatPercent(s.trainingRealRate),
              ),
              _tile('Présents', '${s.trainingPresent}'),
              _tile('Retards', '${s.trainingLate}'),
              _tile('Absents', '${s.trainingAbsent}'),
            ],
          ),
          const SizedBox(height: 20),
          _section(
            'Entraînements — réponses avant la séance',
            [
              _tile('Réponses enregistrées', '${s.rsvpAnswered}'),
              _tile(
                'Part de « présent » (parmi réponses)',
                formatPercent(s.rsvpPresentAmongAnswered),
              ),
              _tile('« Présent » annoncé', '${s.rsvpPresent}'),
              _tile('« Absent » annoncé', '${s.rsvpAbsent}'),
              _tile(
                'Délai moyen (réponse « présent »)',
                formatAvgDelayFromStats(s),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(
            'Matchs — réponses',
            [
              _tile('Réponses enregistrées', '${s.matchAnswered}'),
              _tile(
                'Part de « présent » (parmi réponses)',
                formatPercent(s.matchPresentAmongAnswered),
              ),
              _tile('« Présent »', '${s.matchPresent}'),
              _tile('« Absent »', '${s.matchAbsent}'),
              _tile(
                'Délai moyen (réponse « présent »)',
                s.matchDelayCount <= 0
                    ? '—'
                    : formatDurationFr(
                        Duration(
                          seconds:
                              (s.matchDelaySumSec / s.matchDelayCount).round(),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ViroColors.borderColor),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _tile(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ViroColors.primary,
        ),
      ),
    );
  }
}
