import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';
import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';
import 'package:bhaichara/features/profile/domain/repositories/follow_repository.dart';
import 'package:bhaichara/features/profile/data/repositories/follow_repository_impl.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return FollowRepositoryImpl(supabase);
});

// ─── Search (no cache, user-driven) ──────────────────────────────────────────
final searchUsersProvider = FutureProvider.family<List<UserEntity>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(followRepositoryProvider).searchUsers(query);
});

// ─── Other user profile — kept alive so the chat AppBar never flickers ────────
final otherUserProfileProvider = FutureProvider.family<UserEntity?, String>((ref, userId) async {
  ref.keepAlive(); // ← never dispose; profile data doesn't change frequently
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(SupabaseConstants.profilesTable)
      .select()
      .eq('id', userId)
      .single();
  return UserEntity.fromMap(response);
});

// ─── Follow status ────────────────────────────────────────────────────────────
final followStatusProvider = StreamProvider.family<FollowStatus?, String>((ref, otherUserId) {
  ref.keepAlive();
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (myId == null) return Stream.value(null);
  return ref.watch(followRepositoryProvider).streamFollowStatus(myId, otherUserId);
});

// ─── Pending follow requests ──────────────────────────────────────────────────
final pendingFollowRequestsProvider = StreamProvider<List<FollowEntity>>((ref) {
  ref.keepAlive();
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (myId == null) return Stream.value([]);
  return ref.watch(followRepositoryProvider).streamPendingRequests(myId);
});

// ─── Accepted friends — WhatsApp-style: kept in memory forever ────────────────
// This means the Friends tab shows INSTANTLY on every open, with live updates
// from the Supabase stream in the background.
final acceptedFriendsProvider = StreamProvider<List<UserEntity>>((ref) {
  ref.keepAlive(); // ← THE KEY FIX: never discard the friends list
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (myId == null) return Stream.value([]);
  return ref.watch(followRepositoryProvider).streamAcceptedFriends(myId);
});

// ─── Follow actions ───────────────────────────────────────────────────────────
final followActionsProvider = Provider((ref) {
  final repository = ref.watch(followRepositoryProvider);
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  return FollowActions(repository, myId, ref);
});

class FollowActions {
  final FollowRepository repository;
  final String? myId;
  final Ref ref;

  FollowActions(this.repository, this.myId, this.ref);

  Future<void> followUser(String targetUserId) async {
    await repository.followUser(targetUserId);
  }

  Future<void> cancelRequest(String targetUserId) async {
    if (myId == null) return;
    await repository.cancelRequest(myId!, targetUserId);
  }

  Future<void> acceptRequest(String requestId) async {
    await repository.acceptRequest(requestId);
  }

  Future<void> rejectRequest(String requestId) async {
    await repository.rejectRequest(requestId);
  }
}
