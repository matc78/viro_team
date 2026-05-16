import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_invitation.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/services/invitation_service.dart';

class PendingInvitationState {
  const PendingInvitationState({
    this.invitation,
    this.club,
    this.isLoading = false,
    this.error,
  });

  final ClubInvitation? invitation;
  final Club? club;
  final bool isLoading;
  final String? error;

  bool get hasInvitation => invitation != null && club != null;

  PendingInvitationState copyWith({
    ClubInvitation? invitation,
    Club? club,
    bool? isLoading,
    String? error,
    bool clear = false,
  }) {
    if (clear) {
      return const PendingInvitationState();
    }
    return PendingInvitationState(
      invitation: invitation ?? this.invitation,
      club: club ?? this.club,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PendingInvitationNotifier extends Notifier<PendingInvitationState> {
  @override
  PendingInvitationState build() => const PendingInvitationState();

  InvitationService get _invitations =>
      ref.read(invitationServiceProvider);

  Future<bool> lookupCode(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _invitations.findByCode(code);
      if (result == null) {
        state = const PendingInvitationState(
          error: 'Code introuvable ou expiré.',
        );
        return false;
      }
      state = PendingInvitationState(
        invitation: result.invitation,
        club: result.club,
      );
      return true;
    } catch (e) {
      state = PendingInvitationState(error: e.toString());
      return false;
    }
  }

  void clear() {
    state = const PendingInvitationState();
  }
}

final pendingInvitationProvider = NotifierProvider<PendingInvitationNotifier,
    PendingInvitationState>(PendingInvitationNotifier.new);
