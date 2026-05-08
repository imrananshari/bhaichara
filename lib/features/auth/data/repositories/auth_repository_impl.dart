import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  Stream<UserEntity?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((data) async {
      final session = data.session;
      if (session == null) return null;
      
      // Fetch user profile from the database
      return await getCurrentUser();
    });
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', user.id)
          .single();
      
      return UserEntity.fromMap(response);
    } catch (e) {
      // Profile might not exist yet during initial signup
      return UserEntity(id: user.id, role: UserRole.pending);
    }
  }

  @override
  Future<bool> validateInviteCode(String code) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.invitesTable)
          .select('is_used')
          .eq('code', code)
          .single();
      
      return response['is_used'] == false;
    } catch (e) {
      return false; // Code doesn't exist or error
    }
  }

  @override
  Future<void> consumeInviteCode(String code, String userId) async {
    await _supabase
        .from(SupabaseConstants.invitesTable)
        .update({'is_used': true, 'used_by': userId})
        .eq('code', code);
  }

  @override
  Future<String?> getCircleIdFromInvite(String code) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.invitesTable)
          .select('circle_id')
          .eq('code', code)
          .single();
      return response['circle_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password, String fullName, {String? avatarUrl}) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'avatar_url': avatarUrl,
      },
    );
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> verifyEmailOTP(String email, String otp) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.signup,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // For Web, Supabase handles the flow via a popup/redirect
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'com.bhaichara.bhaichara://login-callback',
      );
    } else {
      // For Mobile, use native Google Sign In (v7.2.0+ API)
      final webClientId = SupabaseConstants.googleClientId;

      final googleSignIn = GoogleSignIn.instance;
      
      // Mandatory initialization for v7.x
      await googleSignIn.initialize(serverClientId: webClientId);
      
      final googleUser = await googleSignIn.authenticate();
      
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No Google ID Token found.');
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    }
  }

  @override
  Future<void> updateProfile({required String userId, String? fullName, String? username, String? avatarUrl, String? circleId}) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (circleId != null) updates['circle_id'] = circleId;
    
    if (updates.isEmpty) return;
    await _supabase
        .from(SupabaseConstants.profilesTable)
        .update(updates)
        .eq('id', userId);
  }

  @override
  Future<String> createCircle(String name, String userId) async {
    final response = await _supabase
        .from('circles')
        .insert({
          'name': name,
          'created_by': userId,
        })
        .select('id')
        .single();
    
    final circleId = response['id'] as String;
    
    // Automatically update the creator's profile with this circleId
    await updateProfile(userId: userId, circleId: circleId);
    
    return circleId;
  }

  Future<String?> getInviteCircleId(String code) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.invitesTable)
          .select('circle_id')
          .eq('code', code)
          .single();
      return response['circle_id'] as String?;
    } catch (e) {
      return null;
    }
  }
}
