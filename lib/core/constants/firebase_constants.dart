/// Firebase Realtime Database path constants.
///
/// Structure mirrors the spec in the project prompt:
///   /messages/{conversationId}/{messageId}
///   /messageStatus/{conversationId}/{messageId}/{userId}
///   /typing/{conversationId}/{userId}
///   /online/{userId}
///   /calls/{userId}
///   /live/{roomId}/comments/{commentId}
class FirebaseConstants {
  FirebaseConstants._();

  // ── Root node names ───────────────────────────────────────────────────────
  static const String _messages = 'messages';
  static const String _messageStatus = 'messageStatus';
  static const String _typing = 'typing';
  static const String _online = 'online';
  static const String _calls = 'calls';
  static const String _live = 'live';

  // ── Message paths ─────────────────────────────────────────────────────────

  /// /messages/{conversationId}
  static String conversationMessages(String conversationId) =>
      '$_messages/$conversationId';

  /// /messages/{conversationId}/{messageId}
  static String messagePath(String conversationId, String messageId) =>
      '$_messages/$conversationId/$messageId';

  // ── Message status paths ──────────────────────────────────────────────────

  /// /messageStatus/{conversationId}
  static String conversationMessageStatus(String conversationId) =>
      '$_messageStatus/$conversationId';

  /// /messageStatus/{conversationId}/{messageId}
  static String messageStatusPath(String conversationId, String messageId) =>
      '$_messageStatus/$conversationId/$messageId';

  /// /messageStatus/{conversationId}/{messageId}/{userId}
  static String messageStatus(
          String conversationId, String messageId, String userId) =>
      '$_messageStatus/$conversationId/$messageId/$userId';

  // ── Typing indicator paths ────────────────────────────────────────────────

  /// /typing/{conversationId}/{userId}
  static String typing(String conversationId, String userId) =>
      '$_typing/$conversationId/$userId';

  // ── Online presence paths ─────────────────────────────────────────────────

  /// /online/{userId}
  static String online(String userId) => '$_online/$userId';

  // ── Call signaling paths ──────────────────────────────────────────────────

  /// /calls/{userId}
  static String calls(String userId) => '$_calls/$userId';

  // ── Live stream paths ─────────────────────────────────────────────────────

  /// /live/{roomId}/comments
  static String liveComments(String roomId) => '$_live/$roomId/comments';

  /// /live/{roomId}/comments/{commentId}
  static String liveComment(String roomId, String commentId) =>
      '$_live/$roomId/comments/$commentId';

  // ── Helper: deterministic DM conversation ID ──────────────────────────────
  /// Sorted join of two user IDs ensures both users always compute the same key.
  static String dmConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
