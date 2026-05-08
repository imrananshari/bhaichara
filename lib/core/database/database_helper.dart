import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';

/// sqflite local database — single source of truth for the chat UI.
///
/// The UI NEVER reads from Firebase or Supabase directly; it only watches
/// streams from this helper, which are updated whenever the repository
/// writes new data (from Firebase RTDB or on send).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  // Per-conversation change notifiers that drive reactive streams.
  final Map<String, StreamController<void>> _convControllers = {};

  // Global notifier for the recent-chats list.
  final StreamController<void> _recentChatsCtrl =
      StreamController<void>.broadcast();

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'bhaichara_chat.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id               TEXT    PRIMARY KEY,
            conversation_id  TEXT    NOT NULL,
            sender_id        TEXT    NOT NULL,
            receiver_id      TEXT,
            circle_id        TEXT,
            content          TEXT    NOT NULL,
            type             TEXT    NOT NULL DEFAULT 'text',
            status           TEXT    NOT NULL DEFAULT 'sending',
            media_url        TEXT,
            media_duration   INTEGER,
            reply_to_id      TEXT,
            is_deleted       INTEGER NOT NULL DEFAULT 0,
            is_synced        INTEGER NOT NULL DEFAULT 0,
            created_at       INTEGER NOT NULL
          )
        ''');

        await db.execute(
            'CREATE INDEX idx_conv ON messages (conversation_id, created_at)');
        await db.execute(
            'CREATE INDEX idx_sender ON messages (sender_id)');
        await db.execute(
            'CREATE INDEX idx_unsynced ON messages (is_synced)');
      },
    );
  }

  // ── Write operations ──────────────────────────────────────────────────────

  /// Insert or replace a message. Fires reactive streams.
  Future<void> saveMessage(MessageEntity msg) async {
    final db = await database;
    await db.insert(
      'messages',
      msg.toSqfliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify(msg.conversationId);
  }

  /// Update a message's delivery status (and optionally its sync flag).
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status, {
    bool? isSynced,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{'status': status.name};
    if (isSynced != null) updates['is_synced'] = isSynced ? 1 : 0;

    await db.update(
      'messages',
      updates,
      where: 'id = ?',
      whereArgs: [messageId],
    );

    final row = await db.query(
      'messages',
      columns: ['conversation_id'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (row.isNotEmpty) {
      _notify(row.first['conversation_id'] as String);
    }
  }

  /// Soft-delete a message by setting is_deleted = 1.
  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    final row = await db.query(
      'messages',
      columns: ['conversation_id'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (row.isNotEmpty) {
      _notify(row.first['conversation_id'] as String);
    }
  }

  /// Mark all messages from others in a conversation as read.
  Future<void> markConversationRead(
      String conversationId, String myUserId) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': MessageStatus.read.name},
      where:
          'conversation_id = ? AND sender_id != ? AND status != ? AND is_deleted = 0',
      whereArgs: [conversationId, myUserId, MessageStatus.read.name],
    );
    _notify(conversationId);
  }

  // ── Read operations ───────────────────────────────────────────────────────

  Future<List<MessageEntity>> getMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ? AND is_deleted = 0',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(MessageEntity.fromSqfliteMap).toList();
  }

  Future<List<String>> getUnreadMessageIds(
      String conversationId, String myUserId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: ['id'],
      where:
          'conversation_id = ? AND sender_id != ? AND status != ? AND is_deleted = 0',
      whereArgs: [conversationId, myUserId, MessageStatus.read.name],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<List<MessageEntity>> getUnsyncedMessages() async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'is_synced = 0 AND is_deleted = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(MessageEntity.fromSqfliteMap).toList();
  }

  Future<DateTime?> getLastMessageTimestamp(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: ['created_at'],
      where: 'conversation_id = ? AND is_synced = 1',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
        rows.first['created_at'] as int);
  }

  // ── Reactive streams (UI subscribes to these) ─────────────────────────────

  /// Emits the full message list for [conversationId] whenever anything changes.
  Stream<List<MessageEntity>> watchMessages(String conversationId) async* {
    yield await getMessages(conversationId);
    final ctrl = _changeController(conversationId);
    await for (final _ in ctrl.stream) {
      yield await getMessages(conversationId);
    }
  }

  /// Emits the latest-message-per-conversation list whenever anything changes.
  Stream<List<RecentChatData>> watchRecentChats(String myUserId) async* {
    yield await _buildRecentChats(myUserId);
    await for (final _ in _recentChatsCtrl.stream) {
      yield await _buildRecentChats(myUserId);
    }
  }

  Future<List<RecentChatData>> _buildRecentChats(String myUserId) async {
    final db = await database;

    // Latest message per conversation involving this user.
    final rows = await db.rawQuery('''
      SELECT m.*
      FROM messages m
      INNER JOIN (
        SELECT conversation_id, MAX(created_at) AS max_ts
        FROM messages
        WHERE (sender_id = ? OR receiver_id = ?) AND is_deleted = 0
        GROUP BY conversation_id
      ) latest ON m.conversation_id = latest.conversation_id
                AND m.created_at = latest.max_ts
      ORDER BY m.created_at DESC
    ''', [myUserId, myUserId]);

    final List<RecentChatData> result = [];
    for (final row in rows) {
      final msg = MessageEntity.fromSqfliteMap(row);

      final unreadRows = await db.rawQuery('''
        SELECT COUNT(*) AS cnt
        FROM messages
        WHERE conversation_id = ?
          AND sender_id != ?
          AND status != ?
          AND is_deleted = 0
      ''', [msg.conversationId, myUserId, MessageStatus.read.name]);

      final unread = (unreadRows.first['cnt'] as int?) ?? 0;

      final otherId =
          msg.senderId == myUserId ? msg.receiverId : msg.senderId;

      result.add(RecentChatData(
        conversationId: msg.conversationId,
        otherUserId: otherId,
        circleId: msg.circleId,
        lastMessage: msg,
        unreadCount: unread,
      ));
    }
    return result;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  StreamController<void> _changeController(String conversationId) {
    return _convControllers.putIfAbsent(
      conversationId,
      () => StreamController<void>.broadcast(),
    );
  }

  void _notify(String conversationId) {
    final ctrl = _convControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(null);
    if (!_recentChatsCtrl.isClosed) _recentChatsCtrl.add(null);
  }

  Future<void> close() async {
    for (final c in _convControllers.values) {
      if (!c.isClosed) c.close();
    }
    _convControllers.clear();
    if (!_recentChatsCtrl.isClosed) _recentChatsCtrl.close();
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class RecentChatData {
  final String conversationId;
  final String? otherUserId;
  final String? circleId;
  final MessageEntity lastMessage;
  final int unreadCount;

  const RecentChatData({
    required this.conversationId,
    this.otherUserId,
    this.circleId,
    required this.lastMessage,
    required this.unreadCount,
  });
}
