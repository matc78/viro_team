import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/clubs/providers/user_clubs_provider.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/stream_combine.dart';

/// Rappel cotisation affiché sur la home.
class HomeFeeReminderItem {
  const HomeFeeReminderItem({
    required this.clubId,
    required this.clubName,
    required this.brandColorHex,
    required this.season,
    required this.fee,
  });

  final String clubId;
  final String clubName;
  final String? brandColorHex;
  final FeeSeason season;
  final MemberFee fee;

  bool get isOverdue =>
      fee.displayStatus(season.paymentDeadlineAt) ==
      MemberFeeDisplayStatus.enRetard;
}

final activeSeasonProvider =
    StreamProvider.family<FeeSeason?, String>((ref, clubId) {
  return ref.read(feeServiceProvider).watchActiveSeason(clubId);
});

final myFeeProvider = StreamProvider.family<
    ({MemberFee? fee, FeeSeason? season}),
    ({String clubId, String memberId})>((ref, params) {
  return ref.read(feeServiceProvider).watchActiveMemberFee(
        clubId: params.clubId,
        memberId: params.memberId,
      );
});

final allMemberFeesProvider =
    StreamProvider.family<List<MemberFee>, String>((ref, clubId) {
  final season = ref.watch(activeSeasonProvider(clubId)).value;
  if (season == null) return Stream.value([]);
  return ref.read(feeServiceProvider).watchAllMemberFees(
        clubId: clubId,
        seasonId: season.id,
      );
});

final feeStatsProvider = Provider.family<FeeStats, String>((ref, clubId) {
  final fees = ref.watch(allMemberFeesProvider(clubId)).value ?? [];
  final season = ref.watch(activeSeasonProvider(clubId)).value;
  return FeeStats.compute(fees, season?.paymentDeadlineAt);
});

/// Bannières cotisation due sur la home (tous clubs).
final homeFeeRemindersProvider =
    StreamProvider<List<HomeFeeReminderItem>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  final clubs = ref.watch(userClubsProvider).value;

  if (auth == null || clubs == null || clubs.isEmpty) {
    return Stream.value([]);
  }

  final authUid = auth.uid;
  final feeService = ref.read(feeServiceProvider);
  final eventService = ref.read(eventServiceProvider);

  final streams = clubs.map<Stream<List<HomeFeeReminderItem>>>((entry) {
    final club = entry.$1;
    return eventService.watchClubMember(clubId: club.id, uid: authUid).asyncExpand(
      (member) {
        if (member == null) return Stream.value(<HomeFeeReminderItem>[]);
        return feeService
            .watchActiveMemberFee(
              clubId: club.id,
              memberId: member.memberId,
            )
            .map((data) {
          final season = data.season;
          final fee = data.fee;
          if (season == null ||
              fee == null ||
              fee.status != MemberFeeStatus.aPayer) {
            return <HomeFeeReminderItem>[];
          }
          if (fee.amountDueCents(season) <= 0) {
            return <HomeFeeReminderItem>[];
          }
          return [
            HomeFeeReminderItem(
              clubId: club.id,
              clubName: club.name,
              brandColorHex: club.brandColorHex,
              season: season,
              fee: fee,
            ),
          ];
        });
      },
    );
  }).toList();

  return combineLatestListStreams<HomeFeeReminderItem>(streams).map(
    (items) => items.take(3).toList(),
  );
});
