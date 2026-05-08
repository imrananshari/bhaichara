import 'package:flutter/material.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String? senderName;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.senderName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _DeletedBubble(isMe: isMe);

    return GestureDetector(
      onLongPress: isMe ? onDelete : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary.withOpacity(0.18)
                : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            border: Border.all(
              color: isMe
                  ? AppColors.primary.withOpacity(0.25)
                  : Colors.white10,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group chat sender name
              if (!isMe && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName!,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              // Reply preview
              if (message.replyToId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                          color: AppColors.primary.withOpacity(0.6), width: 3),
                    ),
                  ),
                  child: Text(
                    'Reply',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),

              // Message content
              _buildContent(),

              const SizedBox(height: 3),

              // Timestamp + tick row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(width: 36),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt.toLocal()),
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.55),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _StatusTick(status: message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (message.type) {
      case MessageType.image:
        return _ImageBubble(url: message.mediaUrl);
      case MessageType.audio:
        return _AudioBubble(
            url: message.mediaUrl,
            durationSeconds: message.mediaDuration ?? 0);
      default:
        return Text(
          message.content,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        );
    }
  }
}

// ── 4-state tick widget ───────────────────────────────────────────────────────

class _StatusTick extends StatelessWidget {
  final MessageStatus status;
  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        // Clock icon — saved locally, not yet in Firebase
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: AppColors.textSecondary.withOpacity(0.4),
        );

      case MessageStatus.sent:
        // Single grey tick — in Firebase, not yet delivered
        return Icon(Icons.done, size: 15, color: AppColors.tickUnread);

      case MessageStatus.delivered:
        // Double grey ticks — receiver's device received it
        return Icon(Icons.done_all, size: 15, color: AppColors.tickUnread);

      case MessageStatus.read:
        // Double VIOLET ticks — receiver has opened the chat
        return Icon(Icons.done_all, size: 15, color: AppColors.tickRead);
    }
  }
}

// ── Deleted bubble ────────────────────────────────────────────────────────────

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  const _DeletedBubble({required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block,
                size: 14,
                color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              isMe ? 'You deleted this message' : 'This message was deleted',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image bubble ──────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final String? url;
  const _ImageBubble({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppColors.textSecondary),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        // ImageKit transformation: 300px wide thumbnail
        '$url?tr=w-300,fo-auto',
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                height: 160,
                color: AppColors.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          color: AppColors.surface,
          child: const Center(
              child: Icon(Icons.broken_image, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

// ── Audio bubble ──────────────────────────────────────────────────────────────

class _AudioBubble extends StatelessWidget {
  final String? url;
  final int durationSeconds;
  const _AudioBubble({this.url, required this.durationSeconds});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_fill,
            color: AppColors.primary, size: 36),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDuration(durationSeconds),
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
