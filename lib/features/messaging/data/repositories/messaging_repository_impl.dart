import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/core/constants/firebase_constants.dart';
import 'package:bhaichara/core/database/database_helper.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:bhaichara/features/messaging/domain/repositories/messaging_repository.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final DatabaseHelper _db;
  final SupabaseClient _supabase;
  final FirebaseDatabase _rtdb;

  /// Active Firebase subscriptions, keyed by conversationId.
  /// Each entry holds the two subscriptions for that conversation
  /// (incoming messages + status updates).
  final Map<String, List<StreamSubscription<dynamic>>> _subscriptions = {};

  MessagingRepositoryImpl(this._db, this._supabase, this._rtdb);

  // ── UI-facing streams (sqflite only) ─────────────────────────────────────

  @override
  Stream<List<MessageEntity>> watchMessages(String conversationId) =>
      _db.watchMessages(conversationId);

  @override
  Stream<List<RecentChatData>> watchRecentChats(String myUserId) =>
      _db.watchRecentChats(myUserId);

  // ── SEND MESSAGE ──────────────────────────────────────────────────────────
  //
  // Flow (WhatsApp exact):
  //   1. Save to sqflite with status='sending'  → message appears instantly
  //   2. Push to Firebase RTDB                  → receiver gets it in 10-50 ms
  //   3. Update Supabase conversations metadata  → best-effort, background
  //   4. Update sqflite status='sent'            → single grey tick
  @override
  Future<void> sendMessage({
    required String senderId,
    required String conversationId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    int? mediaDuration,
    String? replyToId,
  }) async {
    final messageId =
        '${DateTime.now().millisecondsSinceEpoch}_${senderId.substring(0, 8)}';
    final now = DateTime.now();

    final msg = MessageEntity(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      circleId: circleId,
      content: content,
      type: type,
      status: MessageStatus.sending,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
      replyToId: replyToId,
      createdAt: now,
      isSynced: false,
    );

    // STEP 1 — save locally, show instantly
    await _db.saveMessage(msg);

    try {
      // STEP 2 — push to Firebase RTDB
      await _rtdb
          .ref(FirebaseConstants.messagePath(conversationId, messageId))
          .set({
        'id': messageId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'circle_id': circleId,
        'content': content,
        'type': type.name,
        'media_url': mediaUrl,
        'media_duration': mediaDuration,
        'reply_to_id': replyToId,
        'created_at': now.millisecondsSinceEpoch,
        'is_deleted': false,
      });

      // STEP 3 — update Supabase conversations table (best-effort)
      _updateSupabaseConversationMeta(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        circleId: circleId,
        content: content,
        type: type,
        timestamp: now,
      );

      // STEP 4 — mark as sent (single grey tick)
      await _db.updateMessageStatus(messageId, MessageStatus.sent,
          isSynced: true);
    } catch (_) {
      // Keep is_synced=0 so the offline queue retries on reconnect.
    }
  }

  // ── FIREBASE LISTENER ─────────────────────────────────────────────────────
  //
  // Receiving flow:
  //   Firebase onChildAdded fires
  //   → save to sqflite
  //   → write 'delivered' to /messageStatus/{conv}/{msg}/{myId}
  //   → sqflite stream updates the UI
  //
  // Tick update flow (sender side):
  //   Firebase onChildChanged on /messageStatus/{conv} fires
  //   → update sqflite status to delivered/read
  @override
  void startConversationListener(String conversationId, String myUserId) {
    if (_subscriptions.containsKey(conversationId)) return;
    _subscriptions[conversationId] = [];

    // ── 1. Listen for NEW incoming messages ─────────────────────────────────
    final msgRef = _rtdb
        .ref(FirebaseConstants.conversationMessages(conversationId))
        .orderByChild('created_at')
        .startAt(DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch
            .toDouble());

    final msgSub = msgRef.onChildAdded.listen((event) async {
      final raw = event.snapshot.value;
      if (raw == null) return;

      final map = Map<String, dynamic>.from(raw as Map);
      final msgId = event.snapshot.key!;
      final senderId = map['sender_id'] as String?;
      if (senderId == null) return;

      // Only process messages from the other party
      if (senderId != myUserId) {
        final incoming =
            MessageEntity.fromFirebaseMap(msgId, conversationId, map);
        await _db.saveMessage(incoming);

        // Write 'delivered' to Firebase so the sender's tick updates
        await _rtdb
            .ref(FirebaseConstants.messageStatus(
                conversationId, msgId, myUserId))
            .set('delivered');
      }
    });
    _subscriptions[conversationId]!.add(msgSub);

    // ── 2. Listen for status updates on MY sent messages (tick changes) ─────
    final statusRef = _rtdb
        .ref(FirebaseConstants.conversationMessageStatus(conversationId));

    final statusSub = statusRef.onChildChanged.listen((event) async {
      final messageId = event.snapshot.key!;
      final raw = event.snapshot.value;
      if (raw == null) return;

      final statusMap = Map<String, dynamic>.from(raw as Map);

      // For DM: the other user is the only entry that is not myUserId.
      for (final entry in statusMap.entries) {
        if (entry.key == myUserId) continue;
        final statusStr = entry.value as String?;
        if (statusStr == 'read') {
          await _db.updateMessageStatus(
              messageId, MessageStatus.read, isSynced: true);
        } else if (statusStr == 'delivered') {
          await _db.updateMessageStatus(
              messageId, MessageStatus.delivered, isSynced: true);
        }
      }
    });
    _subscriptions[conversationId]!.add(statusSub);
  }

  @override
  void stopConversationListener(String conversationId) {
    final subs = _subscriptions.remove(conversationId);
    if (subs != null) {
      for (final s in subs) {
        s.cancel();
      }
    }
  }

  // ── MARK READ ─────────────────────────────────────────────────────────────
  //
  // READ flow:
  //   User opens chat screen
  //   → batch-update all unread in Firebase messageStatus → 'read'
  //   → sender's listener fires → ticks go violet
  @override
  Future<void> markConversationRead(
      String conversationId, String myUserId) async {
    final unreadIds = await _db.getUnreadMessageIds(conversationId, myUserId);
    if (unreadIds.isEmpty) return;

    final updates = <String, dynamic>{};
    for (final id in unreadIds) {
      updates[
              '${FirebaseConstants.messageStatusPath(conversationId, id)}/$myUserId'] =
          'read';
    }
    await _rtdb.ref().update(updates);
    await _db.markConversationRead(conversationId, myUserId);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteMessage(String messageId, String conversationId) async {
    await _rtdb
        .ref(FirebaseConstants.messagePath(conversationId, messageId))
        .update({'is_deleted': true});
    await _db.deleteMessage(messageId);
  }

  // ── SYNC MISSED MESSAGES (foreground restore) ─────────────────────────────

  @override
  Future<void> syncMissedMessages(
      String conversationId, String myUserId) async {
    try {
      final lastTs = await _db.getLastMessageTimestamp(conversationId);
      final startAt =
          lastTs?.millisecondsSinceEpoch.toDouble() ?? 0;

      final snapshot = await _rtdb
          .ref(FirebaseConstants.conversationMessages(conversationId))
          .orderByChild('created_at')
          .startAfter(startAt)
          .get();

      if (!snapshot.exists || snapshot.value == null) return;

      final messages = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in messages.entries) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        final msg =
            MessageEntity.fromFirebaseMap(entry.key, conversationId, map);
        await _db.saveMessage(msg);

        if (msg.senderId != myUserId) {
          await _rtdb
              .ref(FirebaseConstants.messageStatus(
                  conversationId, msg.id, myUserId))
              .set('delivered');
        }
      }
    } catch (_) {
      // Non-critical — UI will show what is already in sqflite
    }
  }

  // ── TYPING INDICATOR ──────────────────────────────────────────────────────

  @override
  Future<void> setTyping(
      String conversationId, String userId, bool isTyping) async {
    final ref = _rtdb.ref(FirebaseConstants.typing(conversationId, userId));
    if (isTyping) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }

  @override
  Stream<bool> watchTyping(String conversationId, String otherUserId) {
    return _rtdb
        .ref(FirebaseConstants.typing(conversationId, otherUserId))
        .onValue
        .map((event) => event.snapshot.value != null);
  }

  // ── ONLINE PRESENCE ───────────────────────────────────────────────────────

  @override
  Future<void> setOnlineStatus(String userId, bool isOnline) async {
    final ref = _rtdb.ref(FirebaseConstants.online(userId));
    if (isOnline) {
      await ref.set(ServerValue.timestamp);
      // Auto-remove on disconnect so presence is always accurate
      await ref.onDisconnect().remove();
    } else {
      await ref.remove();
    }
  }

  @override
  Stream<bool> watchOnlineStatus(String userId) {
    return _rtdb
        .ref(FirebaseConstants.online(userId))
        .onValue
        .map((event) => event.snapshot.value != null);
  }

  // ── OFFLINE QUEUE RETRY ───────────────────────────────────────────────────

  @override
  Future<void> retryOfflineQueue(String myUserId) async {
    final unsynced = await _db.getUnsyncedMessages();
    for (final msg in unsynced) {
      try {
        await _rtdb
            .ref(FirebaseConstants.messagePath(
                msg.conversationId, msg.id))
            .set({
          'id': msg.id,
          'conversation_id': msg.conversationId,
          'sender_id': msg.senderId,
          'receiver_id': msg.receiverId,
          'circle_id': msg.circleId,
          'content': msg.content,
          'type': msg.type.name,
          'media_url': msg.mediaUrl,
          'media_duration': msg.mediaDuration,
          'reply_to_id': msg.replyToId,
          'created_at': msg.createdAt.millisecondsSinceEpoch,
          'is_deleted': false,
        });
        await _db.updateMessageStatus(msg.id, MessageStatus.sent,
            isSynced: true);
      } catch (_) {
        // Still offline — will retry next time
      }
    }
  }

  // ── Supabase conversations metadata (best-effort) ─────────────────────────

  void _updateSupabaseConversationMeta({
    required String conversationId,
    required String senderId,
    String? receiverId,
    String? circleId,
    required String content,
    required MessageType type,
    required DateTime timestamp,
  }) {
    final preview =
        type == MessageType.text ? content : '📎 ${type.name}';
    final trimmed =
        preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;

    _supabase.from('conversations').upsert({
      'id': conversationId,
      'last_message_preview': trimmed,
      'last_message_at': timestamp.toIso8601String(),
      'last_sender_id': senderId,
    }).catchError((_) {});
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final subs in _subscriptions.values) {
      for (final s in subs) {
        s.cancel();
      }
    }
    _subscriptions.clear();
  }
}
