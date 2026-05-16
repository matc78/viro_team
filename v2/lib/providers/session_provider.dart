import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';

class SessionState {
  const SessionState({
    this.activeClubId,
    this.activeRole,
  });

  final String? activeClubId;
  final String? activeRole;

  bool get hasActiveClub =>
      activeClubId != null && activeClubId!.isNotEmpty;

  SessionState copyWith({
    String? activeClubId,
    String? activeRole,
    bool clearClub = false,
    bool clearRole = false,
  }) {
    return SessionState(
      activeClubId: clearClub ? null : (activeClubId ?? this.activeClubId),
      activeRole: clearRole ? null : (activeRole ?? this.activeRole),
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void setActiveClub(String clubId, {String? role}) {
    state = SessionState(activeClubId: clubId, activeRole: role);
  }

  void setActiveRole(String role) {
    state = state.copyWith(activeRole: role);
  }

  void clear() {
    state = const SessionState();
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

String memberRoleToViroRole(String role) => switch (role) {
      MemberRoles.admin => 'admin',
      MemberRoles.coach => 'coach',
      MemberRoles.player => 'player',
      _ => 'player',
    };
