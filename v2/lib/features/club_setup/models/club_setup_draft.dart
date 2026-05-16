import 'dart:typed_data';

import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/models/club.dart';

/// Brouillon local de l'assistant création de club.
class ClubSetupDraft {
  ClubSetupDraft({
    this.name = '',
    String? sport,
    this.logoBytes,
    Set<String>? objectives,
    this.city = '',
    this.postalCode = '',
    this.address = '',
    List<PracticeLocation>? practiceLocations,
    this.brandColorHex,
    this.description = '',
  })  : sport = sport ?? ClubSports.all.first,
        objectives = objectives ?? <String>{},
        practiceLocations = practiceLocations ?? [];

  String name;
  String sport;
  Uint8List? logoBytes;
  Set<String> objectives;
  String city;
  String postalCode;
  String address;
  List<PracticeLocation> practiceLocations;
  String? brandColorHex;
  String description;

  bool get canProceedIdentity => name.trim().length >= 2 && sport.isNotEmpty;

  bool get canProceedObjectives => objectives.isNotEmpty;

  bool get canProceedInfo =>
      city.trim().isNotEmpty && practiceLocations.isNotEmpty;

  ClubSetupDraft copy() {
    return ClubSetupDraft(
      name: name,
      sport: sport,
      logoBytes: logoBytes,
      objectives: Set<String>.from(objectives),
      city: city,
      postalCode: postalCode,
      address: address,
      practiceLocations: List<PracticeLocation>.from(practiceLocations),
      brandColorHex: brandColorHex,
      description: description,
    );
  }
}
