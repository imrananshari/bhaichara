import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_bubble.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_input_bar.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';


class GroupChatTab extends ConsumerWidget {
  const GroupChatTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final circleId = user?.circleId;

    if (circleId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No circle joined yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final messagesStream = ref.watch(groupMessagesProvider(circleId));

    return Column(
      children: [
        // Group Info Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.1))),
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
                    Text(
                      'Circle Group Chat',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Real-time messaging',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
        ),
        
        // Chat Area
        Expanded(
          child: messagesStream.when(
            data: (messages) => ListView.builder(
              padding: const EdgeInsets.all(8),
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return ChatBubble(
                  message: msg,
                  isMe: msg.senderId == user?.id,
                  senderName: msg.senderId == user?.id ? 'You' : 'Member',
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
        
        // Input Area
        ChatInputBar(
          onSend: (text) {
            if (user != null) {
              ref.read(messagingActionsProvider).sendMessage(
                senderId: user.id,
                circleId: circleId,
                content: text,
              );
            }
          },
          onPickImage: () {},
          onVoiceChat: () {},
        ),
      ],
    );
  }
}
