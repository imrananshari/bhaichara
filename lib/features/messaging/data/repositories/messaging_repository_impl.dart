import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:bhaichara/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';
import 'package:bhaichara/core/services/encryption_service.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final SupabaseClient _supabase;
  EncryptionService? _encryptionService;

  MessagingRepositoryImpl(this._supabase);

  Future<EncryptionService> _getEncryptionService() async {
    if (_encryptionService == null) {
      _encryptionService = EncryptionService(_supabase);
      await _encryptionService!.initialize();
    }
    return _encryptionService!;
  }

  @override
  Stream<List<MessageEntity>> streamMessages(String userId1, String userId2) {
    return _supabase
        .from(SupabaseConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list
            .where((m) =>
                (m['sender_id'] == userId1 && m['receiver_id'] == userId2) ||
                (m['sender_id'] == userId2 && m['receiver_id'] == userId1))
            .map((m) => MessageEntity.fromMap(m))
            .toList());
  }

  @override
  Stream<List<MessageEntity>> streamGroupMessages(String circleId) {
    return _supabase
        .from(SupabaseConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .eq('circle_id', circleId)
        .order('created_at', ascending: false)
        .map((list) => list.map((m) => MessageEntity.fromMap(m)).toList());
  }

  @override
  Future<void> sendMessage({
    required String senderId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type = MessageType.text,
    String? id,
  }) async {
    String finalContent = content;
    String? iv;
    bool isEncrypted = false;

    // Encrypt 1-on-1 messages
    if (receiverId != null) {
      try {
        final encryption = await _getEncryptionService();
        final encryptedData = await encryption.encryptMessage(
          recipientId: receiverId,
          plaintext: content,
        );
        finalContent = encryptedData['ciphertext']!;
        iv = encryptedData['iv'];
        isEncrypted = true;
      } catch (e) {
        // Fallback to plaintext so message is never lost
      }
    }

    final messageId = id ?? DateTime.now().microsecondsSinceEpoch.toString();

    // Insert into DB — this is the only responsibility of the repository now.
    // Broadcast is handled by RealtimeChannelManager in the provider layer.
    await _supabase.from(SupabaseConstants.messagesTable).insert({
      'id': messageId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'circle_id': circleId,
      'content': finalContent,
      'type': type.name,
      'is_read': false,
      'is_encrypted': isEncrypted,
      'iv': iv,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> markAsRead(String messageId) async {
    await _supabase
        .from(SupabaseConstants.messagesTable)
        .update({'is_read': true})
        .eq('id', messageId);
  }

  @override
  Future<void> deleteMessageForEveryone(String messageId) async {
    await _supabase
        .from(SupabaseConstants.messagesTable)
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }
}
