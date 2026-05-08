import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';

abstract class MessagingRepository {
  /// Stream messages between two users (1-on-1)
  Stream<List<MessageEntity>> streamMessages(String userId1, String userId2);

  /// Stream messages for a specific group
  Stream<List<MessageEntity>> streamGroupMessages(String circleId);

  /// Send a message
  Future<void> sendMessage({
    required String senderId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type = MessageType.text,
    String? id, // Optional ID for syncing optimistic/broadcast
  });


  /// Mark messages as read
  Future<void> markAsRead(String messageId);

  /// Delete message for everyone
  Future<void> deleteMessageForEveryone(String messageId);
}
