import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_bubble.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_input_bar.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:bhaichara/features/profile/presentation/providers/follow_provider.dart';
import 'package:bhaichara/core/network/supabase_client.dart';

class IndividualChatScreen extends ConsumerWidget {
  final String userId;
  const IndividualChatScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesWithOptimisticProvider(userId));
    final userAsync = ref.watch(otherUserProfileProvider(userId));
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: userAsync.when(
          data: (user) => Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                child: user?.avatarUrl == null ? const Icon(Icons.person, color: Colors.black, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Online',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (e, st) => const Text('Error'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'),
                    opacity: 0.05,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(AppColors.background, BlendMode.darken),
                  ),
                ),
                child: messagesAsync.when(
                  skipLoadingOnRefresh: true, // ← show old data while refreshing
                  skipLoadingOnReload: true,  // ← no spinner on re-open
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet. Say hi!'));
                    }
                    return ListView.builder(
                      reverse: true, // Show latest at bottom
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return ChatBubble(
                          message: msg,
                          isMe: msg.senderId == myId,
                          onDelete: () => _showDeleteDialog(context, ref, msg.id),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),

              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0), // Extra gap from bottom
              child: ChatInputBar(
                onSend: (text) {
                  if (myId != null) {
                    ref.read(messagingActionsProvider).sendMessage(
                      senderId: myId,
                      receiverId: userId,
                      content: text,
                    );
                  }
                },
                onPickImage: () {},
                onVoiceChat: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This will delete the message for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(messagingActionsProvider).deleteMessage(messageId);
              Navigator.pop(context);
            },
            child: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
