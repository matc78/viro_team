import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentTeam {
  final String id;
  final String name;
  final List<String> playerIds;
  final String colorHex;

  /// Joueurs hors club : guestId → {firstName, lastName}
  final Map<String, Map<String, String>> guestPlayers;

  const TournamentTeam({
    required this.id,
    required this.name,
    this.playerIds = const [],
    this.colorHex = '#2F27CE',
    this.guestPlayers = const {},
  });

  factory TournamentTeam.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};

    final Map<String, Map<String, String>> guests = {};
    if (d['guestPlayers'] is Map) {
      (d['guestPlayers'] as Map).forEach((k, v) {
        if (v is Map) {
          guests[k as String] = Map<String, String>.from(
            (v).map((mk, mv) => MapEntry(mk.toString(), mv.toString())),
          );
        }
      });
    }

    return TournamentTeam(
      id: doc.id,
      name: d['name'] as String? ?? '',
      playerIds: List<String>.from(d['playerIds'] as List? ?? []),
      colorHex: d['colorHex'] as String? ?? '#2F27CE',
      guestPlayers: guests,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'playerIds': playerIds,
        'colorHex': colorHex,
        if (guestPlayers.isNotEmpty) 'guestPlayers': guestPlayers,
      };

  TournamentTeam copyWith({
    String? id,
    String? name,
    List<String>? playerIds,
    String? colorHex,
    Map<String, Map<String, String>>? guestPlayers,
  }) {
    return TournamentTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      playerIds: playerIds ?? this.playerIds,
      colorHex: colorHex ?? this.colorHex,
      guestPlayers: guestPlayers ?? this.guestPlayers,
    );
  }
}
