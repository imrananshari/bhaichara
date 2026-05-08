import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/auth/domain/repositories/auth_repository.dart';

/// Provider for the AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(supabase);
});

/// StreamProvider to listen to authentication state changes
final currentSessionProvider = StreamProvider<Session?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});

final authStateProvider = StreamProvider<UserEntity?>((ref) async* {
  final sessionAsync = ref.watch(currentSessionProvider);
  
  // If we are still waiting for the initial session state, don't emit anything yet
  if (sessionAsync.isLoading && !sessionAsync.hasValue) {
    return;
  }

  final session = sessionAsync.value;
  if (session == null) {
    yield null;
    return;
  }
  
  final supabase = ref.watch(supabaseClientProvider);
  final stream = supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', session.user.id)
      .map((data) {
        if (data.isEmpty) {
          return UserEntity(id: session.user.id, role: UserRole.pending);
        }
        return UserEntity.fromMap(data.first);
      });
      
  yield* stream;
});

/// AsyncNotifierProvider to manage invite code validation state
final inviteCodeValidationProvider = AsyncNotifierProvider<InviteCodeNotifier, bool?>(() {
  return InviteCodeNotifier();
});

class InviteCodeNotifier extends AsyncNotifier<bool?> {
  @override
  FutureOr<bool?> build() {
    return null; // initial state
  }

  Future<bool> validateCode(String code) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final isValid = await repository.validateInviteCode(code);
      
      if (isValid) {
        // Fetch circle_id associated with this invite
        final circleId = await repository.getCircleIdFromInvite(code);
        
        // Store in signup data
        ref.read(signupDataProvider.notifier).updateData({
          'inviteCode': code,
          'circleId': circleId,
        });
      }
      
      state = AsyncData(isValid);
      return isValid;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
  
  void reset() {
    state = const AsyncData(null);
  }
}

class SignupDataNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};

  void updateData(Map<String, dynamic> data) {
    state = {...state, ...data};
  }
}

/// Holds the signup data (email, password, fullName, inviteCode) temporarily across screens
final signupDataProvider = NotifierProvider<SignupDataNotifier, Map<String, dynamic>>(() {
  return SignupDataNotifier();
});

/// Provider for auth actions (signup, login, etc)
final authActionsProvider = Provider((ref) {
  return ref.watch(authRepositoryProvider);
});


