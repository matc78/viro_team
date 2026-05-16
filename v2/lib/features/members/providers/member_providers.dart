import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_member.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/services/member_service.dart';

final clubMembersProvider =
    StreamProvider.family<List<ClubMember>, String>((ref, clubId) {
  return ref.read(memberServiceProvider).watchClubMembers(clubId);
});

final clubParentsProvider =
    FutureProvider.family<List<ClubParentEntry>, String>((ref, clubId) {
  return ref.read(memberServiceProvider).fetchClubParents(clubId);
});

final clubForMembersProvider = FutureProvider.family<Club?, String>((ref, clubId) {
  return ref.read(clubServiceProvider).getClub(clubId);
});
