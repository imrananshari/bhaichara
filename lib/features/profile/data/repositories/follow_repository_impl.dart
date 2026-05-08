import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';
import 'package:bhaichara/features/profile/domain/repositories/follow_repository.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';

class FollowRepositoryImpl implements FollowRepository {
  final SupabaseClient _supabase;

  FollowRepositoryImpl(this._supabase);

  @override
  Future<List<FollowEntity>> getPendingRequests(String userId) async {
    final response = await _supabase
        .from(SupabaseConstants.followsTable)
        .select()
        .eq('following_id', userId)
        .eq('status', 'pending');
    
    return (response as List).map((map) => FollowEntity.fromMap(map)).toList();
  }

  @override
  Stream<List<FollowEntity>> streamPendingRequests(String userId) {
    return _supabase
        .from(SupabaseConstants.followsTable)
        .stream(primaryKey: ['id'])
        .map((list) => list
            .where((map) => 
                map['following_id'] == userId && 
                map['status'] == 'pending')
            .map((map) => FollowEntity.fromMap(map))
            .toList());
  }

  @override
  Stream<FollowStatus?> streamFollowStatus(String userId1, String userId2) {
    return _supabase
        .from(SupabaseConstants.followsTable)
        .stream(primaryKey: ['id'])
        .map((list) {
          final record = list.firstWhere(
            (m) => (m['follower_id'] == userId1 && m['following_id'] == userId2) ||
                   (m['follower_id'] == userId2 && m['following_id'] == userId1),
            orElse: () => <String, dynamic>{},
          );
          
          if (record.isEmpty) return null;
          
          final statusString = record['status'] as String;
          if (statusString == 'accepted') return FollowStatus.accepted;
          if (statusString == 'rejected') return FollowStatus.rejected;
          return FollowStatus.pending;
        });
  }

  @override
  Future<void> cancelRequest(String followerId, String followingId) async {
    await _supabase
        .from(SupabaseConstants.followsTable)
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    await _supabase
        .from(SupabaseConstants.followsTable)
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  @override
  Future<void> rejectRequest(String requestId) async {
    // We delete on reject to allow the user to follow again later (like Instagram)
    await _supabase
        .from(SupabaseConstants.followsTable)
        .delete()
        .eq('id', requestId);
  }

  @override
  Future<void> followUser(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from(SupabaseConstants.followsTable).insert({
      'follower_id': myId,
      'following_id': targetUserId,
      'status': 'pending',
    });
  }

  @override
  Future<FollowStatus?> getFollowStatus(String userId1, String userId2) async {
    final response = await _supabase
        .from(SupabaseConstants.followsTable)
        .select()
        .or('and(follower_id.eq.$userId1,following_id.eq.$userId2),and(follower_id.eq.$userId2,following_id.eq.$userId1)')
        .maybeSingle();
    
    if (response == null) return null;

    final statusString = response['status'] as String;
    if (statusString == 'accepted') return FollowStatus.accepted;
    if (statusString == 'rejected') return FollowStatus.rejected;
    return FollowStatus.pending;
  }

  @override
  Stream<List<UserEntity>> streamAcceptedFriends(String userId) {
    return _supabase
        .from(SupabaseConstants.followsTable)
        .stream(primaryKey: ['id'])
        .asyncMap((list) async {
          final acceptedFollows = list.where((m) => 
            m['status'] == 'accepted' && 
            (m['follower_id'] == userId || m['following_id'] == userId)
          ).toList();
          
          if (acceptedFollows.isEmpty) return [];
          
          final friendIds = acceptedFollows.map((m) => 
            m['follower_id'] == userId ? m['following_id'] : m['follower_id']
          ).toList();
          
          final profilesResponse = await _supabase
              .from(SupabaseConstants.profilesTable)
              .select()
              .inFilter('id', friendIds);
              
          return (profilesResponse as List).map((m) => UserEntity.fromMap(m)).toList();
        });
  }

  @override
  Future<List<UserEntity>> searchUsers(String query) async {
    final response = await _supabase
        .from(SupabaseConstants.profilesTable)
        .select()
        .or('username.ilike.%$query%,full_name.ilike.%$query%')
        .limit(20);
    
    return (response as List).map((map) => UserEntity.fromMap(map)).toList();
  }
}
