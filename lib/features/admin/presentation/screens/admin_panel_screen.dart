import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/admin/presentation/providers/admin_provider.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Admin Console', style: TextStyle(color: AppColors.textPrimary)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Approvals'),
              Tab(text: 'Community'),
              Tab(text: 'Invites'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PendingApprovalsTab(),
            CommunityTab(),
            InvitesTab(),
          ],
        ),
      ),
    );
  }
}

class PendingApprovalsTab extends ConsumerWidget {
  const PendingApprovalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsers = ref.watch(pendingUsersProvider);

    return pendingUsers.when(
      data: (users) {
        if (users.isEmpty) {
          return const Center(
            child: Text('No pending approvals', style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _PendingUserCard(user: user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class CommunityTab extends ConsumerWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMembers = ref.watch(allMembersProvider);

    return allMembers.when(
      data: (users) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              color: AppColors.surface,
              child: ListTile(
                title: Text(user.fullName ?? 'Anonymous', style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('Role: ${user.role.name}', style: const TextStyle(color: AppColors.primary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.role == UserRole.member) 
                      TextButton(
                        onPressed: () => ref.read(adminRepositoryProvider).updateUserRole(user.id, 'superAdmin'),
                        child: const Text('Make Admin', style: TextStyle(color: AppColors.accent)),
                      ),
                    if (user.role == UserRole.superAdmin)
                      TextButton(
                        onPressed: () => ref.read(adminRepositoryProvider).updateUserRole(user.id, 'member'),
                        child: const Text('Revoke Admin', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class InvitesTab extends ConsumerWidget {
  const InvitesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              final code = await ref.read(adminRepositoryProvider).generateInviteCode();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Generated Code: $code')),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Generate New Invite Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: invites.when(
            data: (list) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final invite = list[index];
                  final isUsed = invite['is_used'] as bool;
                  return Card(
                    color: AppColors.surface,
                    child: ListTile(
                      title: Text(invite['code'], style: const TextStyle(
                        color: AppColors.textPrimary, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      )),
                      subtitle: Text(isUsed ? 'Used' : 'Active', style: TextStyle(
                        color: isUsed ? AppColors.textSecondary : Colors.green,
                      )),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: AppColors.textSecondary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invite['code']));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _PendingUserCard extends ConsumerStatefulWidget {
  const _PendingUserCard({required this.user});
  final UserEntity user;

  @override
  ConsumerState<_PendingUserCard> createState() => _PendingUserCardState();
}

class _PendingUserCardState extends ConsumerState<_PendingUserCard> {
  bool _isLoading = false;

  Future<void> _handleAction(Future<void> Function() action, String successMessage) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: widget.user.avatarUrl != null 
                  ? CachedNetworkImageProvider(widget.user.avatarUrl!) 
                  : null,
                child: widget.user.avatarUrl == null
                  ? Text(
                      (widget.user.fullName?.isNotEmpty == true) 
                          ? widget.user.fullName![0].toUpperCase() 
                          : '?', 
                      style: const TextStyle(color: AppColors.primary)
                    )
                  : null,
              ),
              title: Text(widget.user.fullName ?? 'Anonymous', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(widget.user.email ?? 'No email', style: const TextStyle(color: AppColors.textSecondary)),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color: AppColors.primary),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    label: const Text('Member', style: TextStyle(color: Colors.green)),
                    onPressed: () => _handleAction(
                      () => ref.read(adminRepositoryProvider).approveUser(widget.user.id),
                      'Approved as Member',
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.admin_panel_settings, color: AppColors.accent, size: 20),
                    label: const Text('Admin', style: TextStyle(color: AppColors.accent)),
                    onPressed: () => _handleAction(
                      () => ref.read(adminRepositoryProvider).updateUserRole(widget.user.id, 'superAdmin'),
                      'Approved as Super Admin',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    tooltip: 'Decline',
                    onPressed: () => _handleAction(
                      () => ref.read(adminRepositoryProvider).declineUser(widget.user.id),
                      'User Declined',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
