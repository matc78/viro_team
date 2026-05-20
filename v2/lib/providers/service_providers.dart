import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/services/announcement_service.dart';
import 'package:viro_team_v2/services/auth_service.dart';
import 'package:viro_team_v2/services/club_service.dart';
import 'package:viro_team_v2/services/event_service.dart';
import 'package:viro_team_v2/services/fee_service.dart';
import 'package:viro_team_v2/services/invitation_service.dart';
import 'package:viro_team_v2/services/join_request_service.dart';
import 'package:viro_team_v2/services/member_service.dart';
import 'package:viro_team_v2/services/retour_user_service.dart';
import 'package:viro_team_v2/services/team_service.dart';
import 'package:viro_team_v2/services/user_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userServiceProvider = Provider<UserService>((ref) => UserService());

final clubServiceProvider = Provider<ClubService>((ref) => ClubService());

final eventServiceProvider = Provider<EventService>((ref) => EventService());

final invitationServiceProvider =
    Provider<InvitationService>((ref) => InvitationService());

final joinRequestServiceProvider =
    Provider<JoinRequestService>((ref) => JoinRequestService());

final retourUserServiceProvider =
    Provider<RetourUserService>((ref) => RetourUserService());

final memberServiceProvider =
    Provider<MemberService>((ref) => MemberService());

final teamServiceProvider = Provider<TeamService>((ref) => TeamService());

final announcementServiceProvider =
    Provider<AnnouncementService>((ref) => AnnouncementService());

final feeServiceProvider = Provider<FeeService>((ref) => FeeService());
