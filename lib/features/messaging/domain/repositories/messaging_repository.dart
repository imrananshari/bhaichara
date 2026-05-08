import 'package:bhaichara/core/database/database_helper.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';

abstract class MessagingRepository {
  // ── UI-facing streams (read ONLY from sqflite) ────────────────────────────

  /// Reactive stream of all messages for [conversationId], ordered oldest→newest.
  Stream<List<MessageEntity>> watchMessages(String conversationId);

  /// Reactive stream of the latest message per conversation for the chat list.
  Stream<List<RecentChatData>> watchRecentChats(String myUserId);

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String senderId,
    required String conversationId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type,
    String? mediaUrl,
    int? mediaDuration,
    String? replyToId,
  });

  // ── Firebase listeners ────────────────────────────────────────────────────

  /// Open a Firebase RTDB listener for [conversationId].
  /// Safe to call multiple times — only one listener per conversation.
  void startConversationListener(String conversationId, String myUserId);

  /// Cancel and remove the listener for [conversationId].
  void stopConversationListener(String conversationId);

  // ── Read receipts ─────────────────────────────────────────────────────────

  /// Batch-update all unread messages in Firebase to 'read' and mirror in sqflite.
  Future<void> markConversationRead(String conversationId, String myUserId);

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId, String conversationId);

  // ── Sync on foreground restore ────────────────────────────────────────────

  /// Fetch messages missed while the app was in background and save to sqflite.
  Future<void> syncMissedMessages(String conversationId, String myUserId);

  // ── Typing indicator ──────────────────────────────────────────────────────

  Future<void> setTyping(String conversationId, String userId, bool isTyping);
  Stream<bool> watchTyping(String conversationId, String otherUserId);

  // ── Online presence ───────────────────────────────────────────────────────

  Future<void> setOnlineStatus(String userId, bool isOnline);
  Stream<bool> watchOnlineStatus(String userId);

  // ── Offline queue ─────────────────────────────────────────────────────────

  /// Re-push every message that failed to sync (is_synced = 0).
  Future<void> retryOfflineQueue(String myUserId);

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose();
}
