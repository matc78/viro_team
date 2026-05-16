import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/models/club_invitation.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

final pendingInvitationsProvider =
    FutureProvider<List<ClubInvitation>>((ref) async {
  final user = await ref.watch(viroUserFutureProvider.future);
  if (user == null) return [];

  final email = user.emailNorm.isNotEmpty ? user.emailNorm : user.email;
  if (email.isEmpty) return [];

  return ref.read(invitationServiceProvider).getPendingInvitationsForEmail(
        email,
      );
});
