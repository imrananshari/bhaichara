enum MessageType {
  text,
  image,
  video,
  audio,
  document,
}

class MessageEntity {
  final String id;
  final String senderId;
  final String? receiverId;
  final String? circleId;
  final String content;
  final MessageType type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final bool isEncrypted;
  final String? iv;
  final bool isOptimistic;


  const MessageEntity({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.circleId,
    required this.content,
    this.type = MessageType.text,
    this.isRead = false,
    required this.createdAt,
    this.deletedAt,
    this.isEncrypted = false,
    this.iv,
    this.isOptimistic = false,
  });


  bool get isDeleted => deletedAt != null;

  factory MessageEntity.fromMap(Map<String, dynamic> map) {
    return MessageEntity(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String?,
      circleId: map['circle_id'] as String?,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      deletedAt: map['deleted_at'] != null 
          ? DateTime.parse(map['deleted_at'] as String) 
          : null,
      isEncrypted: map['is_encrypted'] as bool? ?? false,
      iv: map['iv'] as String?,
      isOptimistic: map['is_optimistic'] as bool? ?? false,
    );

  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'circle_id': circleId,
      'content': content,
      'type': type.name,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_encrypted': isEncrypted,
      'iv': iv,
      'is_optimistic': isOptimistic,
    };

  }
}
