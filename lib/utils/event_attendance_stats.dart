/// Statistiques de réponse (présence déclarée) pour un événement.
/// Les [teamPendingPlayerIds] sont les IDs `pending_members` rattachés à l'équipe :
/// ils restent visibles dans les listes mais ne sont pas comptés dans les totaux.
class EventRsvpSummary {
  final int present;
  final int absent;
  final int sansReponse;
  final int convoquesAvecCompte;

  const EventRsvpSummary({
    required this.present,
    required this.absent,
    required this.sansReponse,
    required this.convoquesAvecCompte,
  });
}

/// Calcule présents / absents / sans réponse parmi les convoqués ayant un compte uniquement.
EventRsvpSummary computeRsvpSummaryExcludingPendingMembers({
  required Map<String, dynamic> attendance,
  required List<dynamic> teamMemberIds,
  Set<String>? teamPendingPlayerIds,
}) {
  final pending = teamPendingPlayerIds ?? {};
  final eligible = teamMemberIds
      .map((e) => e.toString().trim())
      .where((id) => id.isNotEmpty && !pending.contains(id))
      .toList();

  var p = 0, a = 0;
  for (final id in eligible) {
    final v = attendance[id];
    if (v == 'present') {
      p++;
    } else if (v == 'absent') {
      a++;
    }
  }
  final n = eligible.length;
  final sr = (n - p - a).clamp(0, n);
  return EventRsvpSummary(
    present: p,
    absent: a,
    sansReponse: sr,
    convoquesAvecCompte: n,
  );
}
