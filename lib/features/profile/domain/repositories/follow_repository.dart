import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

abstract class FollowRepository {
  /// Send a follow request to another user
  Future<void> followUser(String targetUserId);

  /// Accept a follow request
  Future<void> acceptRequest(String requestId);

  /// Reject a follow request
  Future<void> rejectRequest(String requestId);

  /// Get follow relationship status between two users
  Future<FollowStatus?> getFollowStatus(String userId1, String userId2);

  /// Get pending follow requests for a user
  Future<List<FollowEntity>> getPendingRequests(String userId);

  /// Stream incoming pending requests for a user
  Stream<List<FollowEntity>> streamPendingRequests(String userId);

  /// Stream follow relationship status between two users
  Stream<FollowStatus?> streamFollowStatus(String userId1, String userId2);

  /// Cancel a pending follow request (Unsend)
  Future<void> cancelRequest(String followerId, String followingId);

  /// Stream all accepted friends for a user
  Stream<List<UserEntity>> streamAcceptedFriends(String userId);

  /// Search for users across all circles
  Future<List<UserEntity>> searchUsers(String query);
}
