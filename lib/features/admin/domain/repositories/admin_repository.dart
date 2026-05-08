import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

abstract class AdminRepository {
  /// Fetches all users with 'pending' status
  Stream<List<UserEntity>> watchPendingUsers();

  /// Fetches all users (except pending) to manage roles
  Stream<List<UserEntity>> watchAllMembers();

  /// Approves a user by setting their role to 'member'
  Future<void> approveUser(String userId);

  /// Declines a user (removes their profile)
  Future<void> declineUser(String userId);

  /// Updates a user's role (e.g., from 'member' to 'superAdmin')
  Future<void> updateUserRole(String userId, String role);

  /// Fetches all active invite codes
  Stream<List<Map<String, dynamic>>> watchInvites();

  /// Generates a new unique invite code
  Future<String> generateInviteCode();
}
