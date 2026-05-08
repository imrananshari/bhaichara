import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_bubble.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_input_bar.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';

class GroupChatTab extends ConsumerStatefulWidget {
  const GroupChatTab({super.key});

  @override
  ConsumerState<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends ConsumerState<GroupChatTab> {
  String? _circleId;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _circleId = user?.circleId;

    if (_circleId != null) {
      final myId = user?.id;
      if (myId != null) {
        // Open Firebase listener for the group conversation
        Future.microtask(() {
          ref.read(messagingActionsProvider).startListening(_circleId!);
          ref.read(messagingActionsProvider).markRead(_circleId!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final circleId = user?.circleId;

    if (circleId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('No circle joined yet',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final messagesAsync = ref.watch(groupMessagesProvider(circleId));

    return Column(
      children: [
        // Group header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
                bottom: BorderSide(
                    color: AppColors.primary.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.group, color: Colors.black),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Circle Group Chat',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('Real-time · Firebase RTDB',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined,
                    color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messagesAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('No group messages yet',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[messages.length - 1 - index];
                  return ChatBubble(
                    message: msg,
                    isMe: msg.senderId == user?.id,
                    senderName:
                        msg.senderId == user?.id ? null : 'Member',
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Input
        ChatInputBar(
          onSend: (text) {
            if (user != null) {
              ref.read(messagingActionsProvider).sendMessage(
                    conversationId: circleId,
                    circleId: circleId,
                    content: text,
                  );
            }
          },
          onPickImage: () {},
          onTyping: (isTyping) {
            if (user != null) {
              ref
                  .read(messagingActionsProvider)
                  .onTyping(circleId, isTyping);
            }
          },
        ),
      ],
    );
  }
}
