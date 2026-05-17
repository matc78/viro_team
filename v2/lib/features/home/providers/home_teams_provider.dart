import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

/// Équipes de tous les clubs de l'utilisateur (aperçu home multi-clubs).
final homeClubTeamsProvider =
    StreamProvider<Map<String, Map<String, ClubTeam>>>((ref) {
  final clubs = ref.watch(userClubsProvider).value;
  if (clubs == null || clubs.isEmpty) return Stream.value({});

  final streams = clubs.map((entry) {
    final clubId = entry.$1.id;
    return ref.read(teamServiceProvider).watchClubTeams(clubId: clubId).map(
          (teams) => [
            MapEntry(
              clubId,
              {for (final t in teams) t.id: t},
            ),
          ],
        );
  }).toList();

  return combineLatestListStreams<MapEntry<String, Map<String, ClubTeam>>>(
    streams,
  ).map(
    (entries) => Map<String, Map<String, ClubTeam>>.fromEntries(entries),
  );
});
