import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/providers/service_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final viroUserProvider = StreamProvider<ViroUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(userServiceProvider).watchUser(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

final viroUserFutureProvider = FutureProvider<ViroUser?>((ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;
  return ref.watch(userServiceProvider).getUser(auth.uid);
});

enum SignUpIntent { founder, join }

class SignUpIntentNotifier extends Notifier<SignUpIntent> {
  @override
  SignUpIntent build() => SignUpIntent.founder;

  void setIntent(SignUpIntent intent) => state = intent;
}

final signUpIntentProvider =
    NotifierProvider<SignUpIntentNotifier, SignUpIntent>(
  SignUpIntentNotifier.new,
);

class PendingInviteCodeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCode(String? code) => state = code;
}

final pendingInviteCodeProvider =
    NotifierProvider<PendingInviteCodeNotifier, String?>(
  PendingInviteCodeNotifier.new,
);
