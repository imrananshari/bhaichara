import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:intl/intl.dart';
import 'package:bhaichara/core/services/encryption_service.dart';

class ChatBubble extends ConsumerStatefulWidget {
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
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  String? _decryptedContent;
  bool _isDecrypting = false;

  @override
  void initState() {
    super.initState();
    _handleDecryption();
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content || 
        oldWidget.message.isEncrypted != widget.message.isEncrypted) {
      _handleDecryption();
    }
  }

  Future<void> _handleDecryption() async {
    if (!widget.message.isEncrypted || widget.message.isDeleted) return;

    if (mounted) setState(() => _isDecrypting = true);
    try {
      final myId = widget.isMe ? widget.message.senderId : widget.message.receiverId;
      final otherPartyId = widget.isMe ? widget.message.receiverId : widget.message.senderId;
      
      if (otherPartyId == null) throw Exception('No other party ID');

      final decrypted = await ref.read(encryptionServiceProvider).decryptMessage(
        otherPartyId: otherPartyId,
        ciphertext: widget.message.content,
        iv: widget.message.iv ?? '',
      );
      if (mounted) {
        setState(() {
          _decryptedContent = decrypted;
          _isDecrypting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _decryptedContent = widget.message.content; // Fallback to raw if error
          _isDecrypting = false;
        });
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final senderName = widget.senderName;
    final onDelete = widget.onDelete;

    if (message.isDeleted) {
      return _buildDeletedBubble();
    }

    final displayContent = message.isOptimistic
        ? message.content
        : (message.isEncrypted 
            ? (_decryptedContent ?? '') // Silent loading
            : message.content);


    return GestureDetector(
      onLongPress: isMe ? onDelete : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            border: Border.all(
              color: isMe ? AppColors.primary.withOpacity(0.3) : Colors.white12,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                displayContent,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt.toLocal()),
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),

                  if (isMe) ...[
                    const SizedBox(width: 4),
                    if (message.isOptimistic)
                      Icon(
                        Icons.access_time, // Clock icon for pending
                        size: 13,
                        color: AppColors.textSecondary.withOpacity(0.3),
                      )
                    else
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 15,
                        color: message.isRead ? const Color(0xFF34B7F1) : AppColors.textSecondary.withOpacity(0.5),
                      ),
                  ],

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble() {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              widget.isMe ? 'You deleted this message' : 'This message was deleted',
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
