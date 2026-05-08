enum MessageType {
  text,
  image,
  audio,
  video,
  document,
}

/// Four-state delivery status for WhatsApp-exact tick display.
enum MessageStatus {
  /// Saved to sqflite, not yet pushed to Firebase. Shows clock icon.
  sending,

  /// Pushed to Firebase RTDB. Shows single grey tick.
  sent,

  /// Receiver's device received the message. Shows double grey ticks.
  delivered,

  /// Receiver opened the conversation. Shows double violet ticks.
  read,
}

class MessageEntity {
  final String id;

  /// Deterministic conversation key.
  /// • DM  : sorted join  "uid1_uid2"
  /// • Group: circle_id
  final String conversationId;

  final String senderId;
  final String? receiverId;
  final String? circleId;
  final String content;
  final MessageType type;
  final MessageStatus status;

  /// CDN URL for image / audio / video messages (ImageKit).
  final String? mediaUrl;

  /// Duration in seconds for audio messages.
  final int? mediaDuration;

  /// ID of the message being replied to.
  final String? replyToId;

  final bool isDeleted;

  /// Whether this message has been successfully pushed to Firebase RTDB.
  /// Messages with isSynced=false are retried in the offline queue.
  final bool isSynced;

  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    this.circleId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sending,
    this.mediaUrl,
    this.mediaDuration,
    this.replyToId,
    this.isDeleted = false,
    this.isSynced = false,
    required this.createdAt,
  });

  bool get isOptimistic => status == MessageStatus.sending;

  // ── sqflite serialisation ──────────────────────────────────────────────────

  Map<String, dynamic> toSqfliteMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'circle_id': circleId,
        'content': content,
        'type': type.name,
        'status': status.name,
        'media_url': mediaUrl,
        'media_duration': mediaDuration,
        'reply_to_id': replyToId,
        'is_deleted': isDeleted ? 1 : 0,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MessageEntity.fromSqfliteMap(Map<String, dynamic> map) {
    return MessageEntity(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String?,
      circleId: map['circle_id'] as String?,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      mediaUrl: map['media_url'] as String?,
      mediaDuration: map['media_duration'] as int?,
      replyToId: map['reply_to_id'] as String?,
      isDeleted: (map['is_deleted'] as int?) == 1,
      isSynced: (map['is_synced'] as int?) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  // ── Firebase RTDB deserialisation ──────────────────────────────────────────

  factory MessageEntity.fromFirebaseMap(
    String messageId,
    String conversationId,
    Map<String, dynamic> map,
  ) {
    return MessageEntity(
      id: messageId,
      conversationId: conversationId,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String?,
      circleId: map['circle_id'] as String?,
      content: map['content'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      // Messages arriving from Firebase are already at least 'sent'.
      status: MessageStatus.sent,
      mediaUrl: map['media_url'] as String?,
      mediaDuration: map['media_duration'] as int?,
      replyToId: map['reply_to_id'] as String?,
      isDeleted: map['is_deleted'] as bool? ?? false,
      isSynced: true,
      createdAt: map['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
    );
  }

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? circleId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    String? mediaUrl,
    int? mediaDuration,
    String? replyToId,
    bool? isDeleted,
    bool? isSynced,
    DateTime? createdAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      circleId: circleId ?? this.circleId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
