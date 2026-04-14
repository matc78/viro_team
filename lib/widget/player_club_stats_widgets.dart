import 'package:flutter/material.dart';
import '../models/training_session_attendance.dart';
import '../theme/viro_theme.dart';
import '../utils/player_club_stats_helpers.dart';
import '../pages/player_pages/player_stats_detail_page.dart';

/// Aperçu des stats pour la saison courante + lien vers le détail.
class PlayerClubStatsPreviewCard extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;

  const PlayerClubStatsPreviewCard({
    super.key,
    required this.clubId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final s = playerSeasonStatsForClub(userData, clubId);
    if (!s.hasAnyData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ViroColors.borderColor),
        ),
        child: const Text(
          'Les statistiques apparaîtront après des réponses aux convocations '
          'et des séances pointées par le staff.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    final season = computeSeason(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saison $season',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _row('Présence réelle (séance)', formatPercent(s.trainingRealRate)),
          _row('Présences annoncées (entraîn.)', formatPercent(s.rsvpPresentAmongAnswered)),
          _row('Délai moyen (réponse « présent »)', formatAvgDelayFromStats(s)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerStatsDetailPage(
                      clubId: clubId,
                      userData: userData,
                    ),
                  ),
                );
              },
              child: const Text('Voir le détail'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ViroColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc stats pour la fiche [ProfilDisplayPage] (même contenu que l'aperçu joueur).
class PlayerClubStatsSection extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;

  const PlayerClubStatsSection({
    super.key,
    required this.clubId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'STATISTIQUES (SAISON)',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
        ),
        PlayerClubStatsPreviewCard(clubId: clubId, userData: userData),
      ],
    );
  }
}
