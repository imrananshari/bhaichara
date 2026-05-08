import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:bhaichara/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:bhaichara/features/messaging/data/repositories/messaging_repository_impl.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MessagingRepositoryImpl(supabase);
});

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENT REALTIME CHANNEL MANAGER (WhatsApp-style)
// Opens ONE channel per user at app-launch and keeps it alive forever.
// Sender writes to this channel; receiver reads from it — zero handshake lag.
// ─────────────────────────────────────────────────────────────────────────────
class RealtimeChannelManager {
  final SupabaseClient _supabase;
  final String _myId;
  RealtimeChannel? _inboundChannel;

  // Callbacks registered by the active chat screen
  final Map<String, void Function(MessageEntity)> _listeners = {};

  RealtimeChannelManager(this._supabase, this._myId) {
    _open();
  }

  void _open() {
    _inboundChannel = _supabase.channel('inbox:$_myId');
    _inboundChannel!
        .onBroadcast(
          event: 'msg',
          callback: (payload) {
            try {
              final msg = MessageEntity.fromMap(Map<String, dynamic>.from(payload));
              for (final cb in _listeners.values) {
                cb(msg);
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// Broadcasts a message to the recipient's persistent inbox channel.
  Future<void> broadcast(String receiverId, Map<String, dynamic> payload) async {
    // Use a fire-and-forget ephemeral channel for SENDING.
    // We don't wait for subscription — we send immediately via Postgres REST.
    // The DB stream on the receiver side handles persistence-based delivery.
    // The broadcast is best-effort for instant delivery.
    final outChannel = _supabase.channel('inbox:$receiverId');
    bool sent = false;
    outChannel.subscribe((status, [err]) async {
      if (status == RealtimeSubscribeStatus.subscribed && !sent) {
        sent = true;
        await outChannel.sendBroadcastMessage(event: 'msg', payload: payload);
        await _supabase.removeChannel(outChannel);
      }
    });
    // Clean up after 5s regardless
    Timer(const Duration(seconds: 5), () {
      if (!sent) _supabase.removeChannel(outChannel);
    });
  }

  void addListener(String key, void Function(MessageEntity) callback) {
    _listeners[key] = callback;
  }

  void removeListener(String key) {
    _listeners.remove(key);
  }

  void dispose() {
    if (_inboundChannel != null) {
      _supabase.removeChannel(_inboundChannel!);
    }
  }
}

final realtimeChannelManagerProvider = Provider<RealtimeChannelManager?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return null;

  final manager = RealtimeChannelManager(supabase, myId);
  ref.onDispose(manager.dispose);
  return manager;
});

// ─────────────────────────────────────────────────────────────────────────────
// SERVER STREAM (Supabase Postgres Realtime – backup / history)
// ─────────────────────────────────────────────────────────────────────────────
// ─── SERVER STREAM — kept alive so navigating back to chat shows history ──────
// This is how WhatsApp works: messages are in memory, not re-fetched.
final chatMessagesProvider = StreamProvider.family<List<MessageEntity>, String>((ref, otherUserId) {
  ref.keepAlive(); // ← Never dispose — same as WhatsApp's local DB cache
  final repository = ref.watch(messagingRepositoryProvider);
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (myId == null) return Stream.value([]);
  return repository.streamMessages(myId, otherUserId);
});

// ─────────────────────────────────────────────────────────────────────────────
// OPTIMISTIC (pending) MESSAGES — shown instantly before server confirms
// ─────────────────────────────────────────────────────────────────────────────
class PendingMessagesNotifier extends Notifier<List<MessageEntity>> {
  @override
  List<MessageEntity> build() => [];

  void add(MessageEntity message) => state = [...state, message];
  void remove(String id) => state = state.where((m) => m.id != id).toList();
}

final pendingMessagesProvider =
    NotifierProvider<PendingMessagesNotifier, List<MessageEntity>>(PendingMessagesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// BROADCAST INBOX — incoming messages pushed by sender's device in real-time
// ─────────────────────────────────────────────────────────────────────────────
class BroadcastInboxNotifier extends Notifier<List<MessageEntity>> {
  @override
  List<MessageEntity> build() {
    ref.keepAlive(); // ← Inbox stays alive — new messages never lost on nav
    // Register this notifier as a listener on the persistent channel
    final manager = ref.watch(realtimeChannelManagerProvider);
    manager?.addListener('inbox_notifier', (msg) {
      // Only add if not already in the list (de-dupe by id)
      if (!state.any((m) => m.id == msg.id)) {
        state = [msg, ...state];
      }
    });
    ref.onDispose(() => manager?.removeListener('inbox_notifier'));
    return [];
  }

  void clear() => state = [];
}


final broadcastInboxProvider =
    NotifierProvider<BroadcastInboxNotifier, List<MessageEntity>>(BroadcastInboxNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// COMBINED PROVIDER — merges pending + broadcast + server into one list
// This is what the chat screen watches.
// ─────────────────────────────────────────────────────────────────────────────
final chatMessagesWithOptimisticProvider =
    Provider.family<AsyncValue<List<MessageEntity>>, String>((ref, otherUserId) {
  final serverAsync = ref.watch(chatMessagesProvider(otherUserId));
  final pending = ref.watch(pendingMessagesProvider);
  final broadcast = ref.watch(broadcastInboxProvider);

  return serverAsync.when(
    data: (server) {
      final relevantPending = pending.where((m) => m.receiverId == otherUserId).toList();
      final relevantBroadcast = broadcast.where(
        (m) => m.senderId == otherUserId || m.receiverId == otherUserId,
      ).toList();

      // Priority: pending (optimistic) > broadcast (instant) > server (persistent)
      final all = [...relevantPending, ...relevantBroadcast, ...server];
      final seen = <String>{};
      return AsyncValue.data(all.where((m) => seen.add(m.id)).toList());
    },
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MESSAGES
// ─────────────────────────────────────────────────────────────────────────────
final groupMessagesProvider = StreamProvider.family<List<MessageEntity>, String>((ref, circleId) {
  final repository = ref.watch(messagingRepositoryProvider);
  return repository.streamGroupMessages(circleId);
});

// ─────────────────────────────────────────────────────────────────────────────
// RECENT CHATS (chat list with unread counts)
// ─────────────────────────────────────────────────────────────────────────────
final recentChatsWithMetadataProvider = StreamProvider<List<ChatSummary>>((ref) {
  ref.keepAlive(); // ← Chat list stays alive — no reload when switching tabs
  final supabase = ref.watch(supabaseClientProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return Stream.value([]);

  return supabase
      .from(SupabaseConstants.messagesTable)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((list) {
        final messages = list.map((m) => MessageEntity.fromMap(m)).toList();
        final summaries = <String, ChatSummary>{};

        for (final msg in messages) {
          final otherId = msg.senderId == myId ? msg.receiverId : msg.senderId;
          final key = msg.circleId ?? otherId;
          if (key == null) continue;

          if (!summaries.containsKey(key)) {
            summaries[key] = ChatSummary(lastMessage: msg, unreadCount: 0);
          }

          if (msg.receiverId == myId && !msg.isRead) {
            summaries[key] = summaries[key]!.copyWith(
              unreadCount: summaries[key]!.unreadCount + 1,
            );
          }
        }

        return summaries.values.toList()
          ..sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
      });
});

class ChatSummary {
  final MessageEntity lastMessage;
  final int unreadCount;

  ChatSummary({required this.lastMessage, required this.unreadCount});

  ChatSummary copyWith({MessageEntity? lastMessage, int? unreadCount}) => ChatSummary(
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGING ACTIONS — the single entry-point for sending / deleting messages
// ─────────────────────────────────────────────────────────────────────────────
final messagingActionsProvider = Provider((ref) {
  final repository = ref.watch(messagingRepositoryProvider);
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  final channelManager = ref.watch(realtimeChannelManagerProvider);
  return MessagingActions(repository, myId, ref, channelManager);
});

class MessagingActions {
  final MessagingRepository _repository;
  final Ref _ref;
  final RealtimeChannelManager? _channelManager;

  MessagingActions(this._repository, String? myId, this._ref, this._channelManager);

  Future<void> sendMessage({
    required String senderId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    // Use microseconds for a unique but ordered ID
    final tempId = '${DateTime.now().microsecondsSinceEpoch}';

    // ── STEP 1: Show message on screen IMMEDIATELY (0 ms) ────────────────────
    final optimisticMsg = MessageEntity(
      id: tempId,
      senderId: senderId,
      receiverId: receiverId,
      circleId: circleId,
      content: content,
      type: type,
      createdAt: DateTime.now(),
      isOptimistic: true,
    );
    _ref.read(pendingMessagesProvider.notifier).add(optimisticMsg);

    // ── STEP 2: Send to DB + broadcast in parallel (non-blocking) ────────────
    try {
      // Fire both concurrently — don't await sequentially
      final dbFuture = _repository.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        circleId: circleId,
        content: content,
        type: type,
        id: tempId,
      );

      // Broadcast to receiver's persistent inbox channel for instant delivery
      if (receiverId != null && _channelManager != null) {
        _channelManager.broadcast(receiverId, {
          'id': tempId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'circle_id': circleId,
          'content': content, // plaintext for broadcast; DB stores encrypted
          'type': type.name,
          'is_read': false,
          'is_encrypted': false,
          'iv': null,
          'created_at': DateTime.now().toIso8601String(),
          'is_optimistic': false,
        });
      }

      await dbFuture;

      // Remove optimistic after DB confirms (3s buffer for stream to arrive)
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(pendingMessagesProvider.notifier).remove(tempId);
      });
    } catch (e) {
      // On failure, remove the optimistic message so the user can retry
      _ref.read(pendingMessagesProvider.notifier).remove(tempId);
    }
  }

  Future<void> deleteMessage(String messageId) =>
      _repository.deleteMessageForEveryone(messageId);

  Future<void> markAsRead(String messageId) =>
      _repository.markAsRead(messageId);
}
