import 'package:flutter/material.dart';
import 'package:bhaichara/core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onPickImage;

  /// Called whenever the typing state changes (true = user is typing).
  final Function(bool isTyping)? onTyping;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onPickImage,
    this.onTyping,
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
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _isWriting = false);
    // Notify stopped typing after send
    widget.onTyping?.call(false);
  }

  void _onChanged(String text) {
    final writing = text.trim().isNotEmpty;
    if (writing != _isWriting) {
      setState(() => _isWriting = writing);
      widget.onTyping?.call(writing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
            top: BorderSide(color: AppColors.primary.withOpacity(0.1))),
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
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
                maxLines: 5,
                minLines: 1,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Message…',
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
                ? _SendButton(key: const ValueKey('send'), onSend: _handleSend)
                : _ActionsRow(
                    key: const ValueKey('actions'),
                    onPickImage: widget.onPickImage,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onSend;
  const _SendButton({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.send, color: Colors.black, size: 20),
        onPressed: onSend,
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final VoidCallback onPickImage;
  const _ActionsRow({super.key, required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined,
              color: AppColors.textSecondary),
          onPressed: onPickImage,
        ),
        IconButton(
          icon: const Icon(Icons.mic_none, color: AppColors.primary),
          onPressed: () {},
        ),
      ],
    );
  }
}
