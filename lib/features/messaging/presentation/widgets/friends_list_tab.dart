import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/features/profile/presentation/providers/follow_provider.dart';
import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:bhaichara/core/network/supabase_client.dart';

class FriendsListTab extends ConsumerStatefulWidget {
  const FriendsListTab({super.key});

  @override
  ConsumerState<FriendsListTab> createState() => _FriendsListTabState();
}

class _FriendsListTabState extends ConsumerState<FriendsListTab> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchUsersProvider(_searchQuery));

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search people across villages...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                icon: Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        
        // Results
        Expanded(
          child: _searchQuery.isEmpty 
            ? const _DefaultFriendsList()
            : searchResults.when(
                data: (users) => _SearchResultsList(users: users),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
        ),
      ],
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final List<UserEntity> users;
  const _SearchResultsList({required this.users});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No users found.', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final status = ref.watch(followStatusProvider(user.id));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.05)),
          ),
          color: AppColors.surface,
          child: ListTile(
            onTap: () {
              context.push(AppRoutes.userProfile.replaceAll(':id', user.id));
            },
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? Text(user.fullName?[0] ?? '?') : null,
            ),
            title: Text(user.fullName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('@${user.username ?? 'user'}', style: const TextStyle(fontSize: 13)),
            trailing: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: status.when(
                data: (followStatus) {
                  if (followStatus == null) {
                    return ElevatedButton(
                      onPressed: () async {
                        await ref.read(followActionsProvider).followUser(user.id);
                        ref.invalidate(followStatusProvider(user.id));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Follow request sent to ${user.fullName}'), backgroundColor: AppColors.primary),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Follow', style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }
                  if (followStatus == FollowStatus.accepted) {
                    return const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text('Following', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    );
                  }
                  return const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text('Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  );
                },
                loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, st) => const Icon(Icons.error, color: Colors.red, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DefaultFriendsList extends ConsumerWidget {
  const _DefaultFriendsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentChatsAsync = ref.watch(recentChatsWithMetadataProvider);
    final friendsAsync = ref.watch(acceptedFriendsProvider);
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;


    return recentChatsAsync.when(
      data: (summaries) {
        return friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty && summaries.isEmpty) {

              return const Center(
                child: Text(
                  'No friends yet. Search to add people!',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            // Create a map of friends for quick lookup
            final friendMap = {for (final f in friends) f.id: f};
            
            // Build the list of items to show
            final List<Widget> listItems = [];

            // 1. Add Recent Chats
            for (final summary in summaries) {
              final msg = summary.lastMessage;
              final otherId = msg.senderId == myId ? msg.receiverId : msg.senderId;
              if (otherId == null) continue;
              
              final friend = friendMap[otherId];
              if (friend == null) continue; 
              
              friendMap.remove(otherId);

              listItems.add(_FriendChatTile(
                friend: friend,
                lastMessage: msg,
                unreadCount: summary.unreadCount,
              ));
            }


            // 2. Add remaining friends who have no messages
            for (final friend in friendMap.values) {
              listItems.add(_FriendChatTile(
                friend: friend,
              ));
            }

            return ListView(children: listItems);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _FriendChatTile extends ConsumerWidget {
  final UserEntity friend;
  final MessageEntity? lastMessage;
  final int unreadCount;

  const _FriendChatTile({
    required this.friend,
    this.lastMessage,
    this.unreadCount = 0,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () {
        context.push(AppRoutes.individualChat.replaceAll(':id', friend.id));
      },
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
        child: friend.avatarUrl == null ? Text(friend.fullName?[0] ?? '?') : null,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            friend.fullName ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (lastMessage != null)
            Text(
              DateFormat('HH:mm').format(lastMessage!.createdAt.toLocal()),
              style: TextStyle(
                color: unreadCount > 0 ? const Color(0xFF25D366) : AppColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage != null 
                  ? (lastMessage!.isEncrypted ? 'Message' : lastMessage!.content)
                  : '@${friend.username ?? 'user'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: lastMessage != null ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            else if (lastMessage != null && lastMessage!.senderId != friend.id)
              Icon(
                lastMessage!.isRead ? Icons.done_all : Icons.done,
                size: 16, 
                color: lastMessage!.isRead ? const Color(0xFF34B7F1) : AppColors.textSecondary.withValues(alpha: 0.5)
              ),
          ],
        ),
      ),

    );
  }
}
