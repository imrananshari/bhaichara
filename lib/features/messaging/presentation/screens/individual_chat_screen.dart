import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_bubble.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/chat_input_bar.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:bhaichara/features/profile/presentation/providers/follow_provider.dart';
import 'package:bhaichara/core/network/supabase_client.dart';

class IndividualChatScreen extends ConsumerStatefulWidget {
  final String userId;
  const IndividualChatScreen({super.key, required this.userId});

  @override
  ConsumerState<IndividualChatScreen> createState() =>
      _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen>
    with WidgetsBindingObserver {
  late final String _convId;
  late final String? _myId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _myId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    if (_myId != null) {
      _convId = MessagingActions.dmConversationId(_myId!, widget.userId);

      // Open Firebase RTDB listener for this conversation
      ref.read(messagingActionsProvider).startListening(_convId);

      // Mark all existing messages as read as soon as screen opens
      Future.microtask(
          () => ref.read(messagingActionsProvider).markRead(_convId));
    } else {
      _convId = '${widget.userId}_unknown';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _myId != null) {
      // Re-sync any messages missed while app was in background
      ref.read(messagingActionsProvider).syncOnResume(_convId);
      ref.read(messagingActionsProvider).markRead(_convId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clear typing indicator when leaving the screen
    if (_myId != null) {
      ref.read(messagingActionsProvider).onTyping(_convId, false);
    }
    // We intentionally do NOT stop the listener so background messages
    // still reach sqflite even after navigating away.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(_convId));
    final userAsync = ref.watch(otherUserProfileProvider(widget.userId));
    final typingAsync =
        ref.watch(typingProvider((convId: _convId, otherUserId: widget.userId)));
    final onlineAsync = ref.watch(onlineStatusProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: userAsync.when(
          data: (user) => Row(
            children: [
              _AvatarWithOnline(
                avatarUrl: user?.avatarUrl,
                name: user?.fullName,
                isOnline: onlineAsync.asData?.value ?? false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: typingAsync.asData?.value == true
                          ? const Text(
                              'typing…',
                              key: ValueKey('typing'),
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.accent),
                            )
                          : onlineAsync.asData?.value == true
                              ? const Text(
                                  'online',
                                  key: ValueKey('online'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success),
                                )
                              : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Chat'),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                          Icon(Icons.chat_bubble_outline,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'No messages yet.\nSay something!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // reversed: index 0 = latest message
                      final msg = messages[messages.length - 1 - index];
                      return ChatBubble(
                        message: msg,
                        isMe: msg.senderId == _myId,
                        onDelete: msg.senderId == _myId
                            ? () => _confirmDelete(context, msg.id)
                            : null,
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
              ),
            ),
            ChatInputBar(
              onSend: (text) {
                if (_myId != null) {
                  ref.read(messagingActionsProvider).sendMessage(
                        conversationId: _convId,
                        receiverId: widget.userId,
                        content: text,
                      );
                  ref.read(messagingActionsProvider).onTyping(_convId, false);
                }
              },
              onPickImage: () {},
              onTyping: (isTyping) {
                ref.read(messagingActionsProvider).onTyping(_convId, isTyping);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete message?'),
        content: const Text('This will delete the message for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(messagingActionsProvider)
                  .deleteMessage(messageId, _convId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete for Everyone',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Avatar with online dot ────────────────────────────────────────────────────

class _AvatarWithOnline extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final bool isOnline;

  const _AvatarWithOnline({
    this.avatarUrl,
    this.name,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primary.withOpacity(0.3),
          backgroundImage:
              avatarUrl != null ? NetworkImage('$avatarUrl?tr=w-80,h-80,fo-face') : null,
          child: avatarUrl == null
              ? Text(
                  (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold),
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
