import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/club_setup/models/club_setup_draft.dart';

class ClubSetupNotifier extends Notifier<ClubSetupDraft> {
  @override
  ClubSetupDraft build() => ClubSetupDraft();

  void reset() {
    state = ClubSetupDraft();
  }

  void updateDraft(ClubSetupDraft Function(ClubSetupDraft) updater) {
    state = updater(state.copy());
  }

  void toggleObjective(String key) {
    final next = Set<String>.from(state.objectives);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    state = state.copy()..objectives = next;
  }
}

final clubSetupProvider =
    NotifierProvider<ClubSetupNotifier, ClubSetupDraft>(ClubSetupNotifier.new);
