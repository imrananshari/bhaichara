import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/features/admin/domain/repositories/admin_repository.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

class AdminRepositoryImpl implements AdminRepository {
  final SupabaseClient _supabase;

  AdminRepositoryImpl(this._supabase);

  @override
  Stream<List<UserEntity>> watchPendingUsers() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'pending')
        .order('created_at')
        .map((data) => data.map((json) => UserEntity.fromMap(json)).toList());
  }

  @override
  Stream<List<UserEntity>> watchAllMembers() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .neq('role', 'pending')
        .order('full_name')
        .map((data) => data.map((json) => UserEntity.fromMap(json)).toList());
  }

  @override
  Future<void> approveUser(String userId) async {
    await _supabase
        .from('profiles')
        .update({'role': 'member'})
        .eq('id', userId);
  }

  @override
  Future<void> declineUser(String userId) async {
    // In a real app, we might just soft-delete or block.
    // For now, we remove the profile.
    await _supabase
        .from('profiles')
        .delete()
        .eq('id', userId);
  }

  @override
  Future<void> updateUserRole(String userId, String role) async {
    await _supabase
        .from('profiles')
        .update({'role': role})
        .eq('id', userId);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchInvites() {
    return _supabase
        .from('invites')
        .stream(primaryKey: ['code'])
        .order('created_at', ascending: false);
  }

  @override
  Future<String> generateInviteCode() async {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid ambiguous chars
    final random = Random();
    final code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    
    final currentUser = _supabase.auth.currentUser;
    
    await _supabase.from('invites').insert({
      'code': code,
      'created_by': currentUser?.id,
    });
    
    return code;
  }
}
