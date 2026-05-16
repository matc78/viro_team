import 'dart:math';

/// Algorithme Window Draft — répartit [playerIds] en [nbTeams] équipes.
///
/// [driftFactor] 0.0 = répartition équilibrée (snake draft), 1.0 = totalement aléatoire.
List<List<String>> windowDraft(
  List<String> playerIds,
  int nbTeams,
  double driftFactor,
) {
  if (nbTeams <= 0 || playerIds.isEmpty) return [];

  final random = Random();
  final shuffled = List<String>.from(playerIds)..shuffle(random);
  final teams = List.generate(nbTeams, (_) => <String>[]);

  for (int w = 0; w * nbTeams < shuffled.length; w++) {
    final windowStart = w * nbTeams;
    final window = shuffled.sublist(
      windowStart,
      min(windowStart + nbTeams, shuffled.length),
    );
    final isSnake = w.isOdd;

    for (int j = 0; j < window.length; j++) {
      int idx = isSnake ? (window.length - 1 - j) : j;

      if (driftFactor > 0) {
        final maxDrift = max(1, (nbTeams * driftFactor).round());
        idx = (idx + random.nextInt(maxDrift)) % nbTeams;
      }

      teams[idx].add(window[j]);
    }
  }

  return teams;
}
