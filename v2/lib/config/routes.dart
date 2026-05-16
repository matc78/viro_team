import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:viro_team_v2/config/router_refresh.dart';

import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';

import 'package:viro_team_v2/features/auth/screens/login_screen.dart';

import 'package:viro_team_v2/features/auth/screens/onboarding_entry_screen.dart';

import 'package:viro_team_v2/features/auth/screens/sign_up_screen.dart';

import 'package:viro_team_v2/features/club/screens/club_detail_screen.dart';
import 'package:viro_team_v2/features/members/screens/club_members_screen.dart';
import 'package:viro_team_v2/features/teams/screens/manage_teams_screen.dart';
import 'package:viro_team_v2/features/teams/screens/my_teams_screen.dart';

import 'package:viro_team_v2/features/club_setup/screens/club_setup_wizard_screen.dart';

import 'package:viro_team_v2/features/clubs/screens/club_selector_screen.dart';

import 'package:viro_team_v2/features/home/screens/home_member_screen.dart';

import 'package:viro_team_v2/features/join/providers/pending_invitation_provider.dart';

import 'package:viro_team_v2/features/join/screens/invitation_preview_screen.dart';

import 'package:viro_team_v2/features/join/screens/join_code_screen.dart';

import 'package:viro_team_v2/features/join/screens/request_role_screen.dart';

import 'package:viro_team_v2/providers/session_provider.dart';

import 'package:viro_team_v2/screens/dev/design_system_preview_screen.dart';



abstract final class AppRoutes {

  static const entry = '/';

  static const login = '/login';

  static const signup = '/signup';

  static const join = '/join';

  static const joinPreview = '/join/preview';

  static const joinRequestRole = '/join/request-role';

  static const clubSetup = '/club-setup';

  static const home = '/home';

  static const clubs = '/clubs';

  static const clubDetail = '/club/:clubId';

  static const clubMembers = '/club/:clubId/members';

  static const clubMyTeams = '/club/:clubId/teams';

  static const clubManageTeams = '/club/:clubId/teams/manage';

  static const designPreview = '/dev/design';



  static String clubDetailPath(String clubId) => '/club/$clubId';

  static String clubMembersPath(String clubId) => '/club/$clubId/members';

  static String clubMyTeamsPath(String clubId) => '/club/$clubId/teams';

  static String clubManageTeamsPath(String clubId) =>
      '/club/$clubId/teams/manage';

}



final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {

  final notifier = RouterRefreshNotifier();

  ref.listen(authStateProvider, (_, _) => notifier.notify());

  ref.listen(viroUserProvider, (_, _) => notifier.notify());

  ref.listen(sessionProvider, (_, _) => notifier.notify());

  ref.listen(pendingInvitationProvider, (_, _) => notifier.notify());

  ref.onDispose(notifier.dispose);

  return notifier;

});



final goRouterProvider = Provider<GoRouter>((ref) {

  final refresh = ref.watch(routerRefreshProvider);



  return GoRouter(

    initialLocation: AppRoutes.entry,

    refreshListenable: refresh,

    redirect: (context, state) {

      final auth = ref.read(authStateProvider);

      final profile = ref.read(viroUserProvider);

      final pending = ref.read(pendingInvitationProvider);



      final isAuth = auth.maybeWhen(data: (u) => u != null, orElse: () => false);

      final user = profile.maybeWhen(data: (u) => u, orElse: () => null);

      final path = state.matchedLocation;



      final isPublic = path == AppRoutes.entry ||

          path == AppRoutes.login ||

          path == AppRoutes.signup ||

          path == AppRoutes.join ||

          path == AppRoutes.designPreview;



      if (!isAuth) {

        if (path == AppRoutes.joinPreview && pending.hasInvitation) {

          return null;

        }

        if (!isPublic &&

            path != AppRoutes.joinPreview &&

            path != AppRoutes.joinRequestRole) {

          return AppRoutes.entry;

        }

        return null;

      }



      if (user == null) {

        final authLoading = auth.isLoading;

        final isAuthed = auth.maybeWhen(data: (u) => u != null, orElse: () => false);

        if (authLoading || (isAuthed && path == AppRoutes.clubSetup)) {

          return null;

        }

        return path == AppRoutes.entry ? null : AppRoutes.entry;

      }



      final inSetup = path == AppRoutes.clubSetup;

      final needsClubSetup = !user.hasClubs &&

          !user.profileCompleted &&

          ref.read(signUpIntentProvider) == SignUpIntent.founder;



      if (needsClubSetup && !inSetup) {

        return AppRoutes.clubSetup;

      }



      if (path == AppRoutes.entry ||

          path == AppRoutes.login ||

          path == AppRoutes.signup) {

        if (user.hasClubs) {

          return AppRoutes.home;

        }

        if (pending.hasInvitation) {

          return AppRoutes.joinPreview;

        }

        return AppRoutes.entry;

      }



      return null;

    },

    routes: [

      GoRoute(

        path: AppRoutes.entry,

        builder: (_, _) => const OnboardingEntryScreen(),

      ),

      GoRoute(

        path: AppRoutes.login,

        builder: (_, _) => const LoginScreen(),

      ),

      GoRoute(

        path: AppRoutes.signup,

        builder: (_, state) => SignUpScreen(

          intentParam: state.uri.queryParameters['intent'],

          codeParam: state.uri.queryParameters['code'],

        ),

      ),

      GoRoute(

        path: AppRoutes.join,

        builder: (_, _) => const JoinCodeScreen(),

      ),

      GoRoute(

        path: AppRoutes.joinPreview,

        builder: (_, _) => const InvitationPreviewScreen(),

      ),

      GoRoute(

        path: AppRoutes.joinRequestRole,

        builder: (_, _) => const RequestRoleScreen(),

      ),

      GoRoute(

        path: AppRoutes.clubSetup,

        builder: (_, _) => const ClubSetupWizardScreen(),

      ),

      GoRoute(

        path: AppRoutes.home,

        builder: (_, _) => const HomeMemberScreen(),

      ),

      GoRoute(

        path: AppRoutes.clubs,

        builder: (_, _) => const ClubSelectorScreen(),

      ),

      GoRoute(

        path: AppRoutes.clubDetail,

        builder: (_, state) {

          final clubId = state.pathParameters['clubId']!;

          return ClubDetailScreen(clubId: clubId);

        },

      ),

      GoRoute(

        path: AppRoutes.clubMembers,

        builder: (_, state) {

          final clubId = state.pathParameters['clubId']!;

          return ClubMembersScreen(clubId: clubId);

        },

      ),

      GoRoute(

        path: AppRoutes.clubManageTeams,

        builder: (_, state) {

          final clubId = state.pathParameters['clubId']!;

          return ManageTeamsScreen(clubId: clubId);

        },

      ),

      GoRoute(

        path: AppRoutes.clubMyTeams,

        builder: (_, state) {

          final clubId = state.pathParameters['clubId']!;

          return MyTeamsScreen(clubId: clubId);

        },

      ),

      GoRoute(

        path: AppRoutes.designPreview,

        builder: (_, _) => const DesignSystemPreviewScreen(),

      ),

    ],

  );

});

