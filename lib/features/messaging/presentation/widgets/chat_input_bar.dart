import 'package:flutter/material.dart';
import 'package:bhaichara/core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onPickImage;
  final VoidCallback onVoiceChat;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onPickImage,
    required this.onVoiceChat,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _isWriting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
      setState(() => _isWriting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: widget.onPickImage,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                maxLines: 5,
                minLines: 1,
                onChanged: (text) {
                  setState(() => _isWriting = text.trim().isNotEmpty);
                },
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isWriting
                ? Container(
                    key: const ValueKey('send'),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black, size: 20),
                      onPressed: _handleSend,
                    ),
                  )
                : Row(
                    key: const ValueKey('actions'),
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
                        onPressed: widget.onPickImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic_none, color: AppColors.primary),
                        onPressed: widget.onVoiceChat,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

