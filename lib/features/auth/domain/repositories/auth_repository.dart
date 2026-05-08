import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream to listen to auth state changes (login/logout)
  Stream<UserEntity?> get authStateChanges;

  /// Get the currently logged-in user's profile
  Future<UserEntity?> getCurrentUser();

  /// Validate an invite code before allowing signup
  Future<bool> validateInviteCode(String code);

  /// Mark an invite code as used and link to the new user
  Future<void> consumeInviteCode(String code, String userId);

  /// Get the circle ID associated with an invite code
  Future<String?> getCircleIdFromInvite(String code);

  /// Sign up with Email and Password (triggers OTP to email)
  Future<void> signUpWithEmail(String email, String password, String fullName, {String? avatarUrl});

  /// Sign in with Email and Password
  Future<void> signInWithPassword(String email, String password);

  /// Verify the Email OTP to complete sign up
  Future<void> verifyEmailOTP(String email, String otp);

  /// Sign out the current user
  Future<void> signOut();

  /// Sign in with Google
  Future<void> signInWithGoogle();

  /// Update user profile (name, username, avatarUrl, circleId)
  Future<void> updateProfile({required String userId, String? fullName, String? username, String? avatarUrl, String? circleId});

  /// Create a new community Circle (for Chief/SuperAdmin)
  Future<String> createCircle(String name, String userId);
}
