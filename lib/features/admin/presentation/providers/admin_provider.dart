import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:bhaichara/features/admin/domain/repositories/admin_repository.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminRepositoryImpl(supabase);
});

final pendingUsersProvider = StreamProvider<List<UserEntity>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingUsers();
});

final allMembersProvider = StreamProvider<List<UserEntity>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllMembers();
});

final invitesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchInvites();
});
