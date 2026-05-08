import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/constants/firebase_constants.dart';
import 'package:bhaichara/core/database/database_helper.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/messaging/data/repositories/messaging_repository_impl.dart';
import 'package:bhaichara/features/messaging/domain/entities/message_entity.dart';
import 'package:bhaichara/features/messaging/domain/repositories/messaging_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = MessagingRepositoryImpl(
    DatabaseHelper.instance,
    supabase,
    FirebaseDatabase.instance,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

// ── Message stream (sqflite — never Firebase directly in UI) ──────────────────

/// Emits the full, ordered message list for [conversationId].
/// keepAlive ensures messages are not re-fetched on tab switch.
final chatMessagesProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, conversationId) {
  ref.keepAlive();
  return ref.watch(messagingRepositoryProvider).watchMessages(conversationId);
});

// ── Recent chats stream ───────────────────────────────────────────────────────

final recentChatsProvider = StreamProvider<List<RecentChatData>>((ref) {
  ref.keepAlive();
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (myId == null) return Stream.value([]);
  return ref.watch(messagingRepositoryProvider).watchRecentChats(myId);
});

// ── Typing indicator ──────────────────────────────────────────────────────────

/// Parameter class for the typing provider family.
typedef TypingArgs = ({String convId, String otherUserId});

final typingProvider = StreamProvider.family<bool, TypingArgs>((ref, args) {
  return ref
      .watch(messagingRepositoryProvider)
      .watchTyping(args.convId, args.otherUserId);
});

// ── Online status ─────────────────────────────────────────────────────────────

final onlineStatusProvider = StreamProvider.family<bool, String>((ref, userId) {
  return ref.watch(messagingRepositoryProvider).watchOnlineStatus(userId);
});

// ── Group messages (also from sqflite via Firebase listener) ─────────────────

/// For group chat the conversationId IS the circleId.
final groupMessagesProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, circleId) {
  ref.keepAlive();
  return ref.watch(messagingRepositoryProvider).watchMessages(circleId);
});

// ── Actions ───────────────────────────────────────────────────────────────────

final messagingActionsProvider = Provider<MessagingActions>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  final actions = MessagingActions(repo, myId);
  ref.onDispose(actions.dispose);
  return actions;
});

class MessagingActions {
  final MessagingRepository _repo;
  final String? _myId;

  Timer? _typingTimer;

  MessagingActions(this._repo, this._myId);

  String? get myId => _myId;

  // ── Conversation ID helpers ───────────────────────────────────────────────

  /// Deterministic DM conversation key shared by both users.
  static String dmConversationId(String userId1, String userId2) =>
      FirebaseConstants.dmConversationId(userId1, userId2);

  // ── Firebase listener management ─────────────────────────────────────────

  void startListening(String conversationId) {
    if (_myId == null) return;
    _repo.startConversationListener(conversationId, _myId!);
  }

  void stopListening(String conversationId) {
    _repo.stopConversationListener(conversationId);
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String conversationId,
    String? receiverId,
    String? circleId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    int? mediaDuration,
    String? replyToId,
  }) async {
    if (_myId == null) return;
    await _repo.sendMessage(
      senderId: _myId!,
      conversationId: conversationId,
      receiverId: receiverId,
      circleId: circleId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
      replyToId: replyToId,
    );
  }

  // ── Typing ────────────────────────────────────────────────────────────────

  void onTyping(String conversationId, bool isTyping) {
    if (_myId == null) return;
    _typingTimer?.cancel();
    _repo.setTyping(conversationId, _myId!, isTyping);
    if (isTyping) {
      // Auto-clear typing after 3 s of no new keystrokes
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _repo.setTyping(conversationId, _myId!, false);
      });
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<void> markRead(String conversationId) async {
    if (_myId == null) return;
    await _repo.markConversationRead(conversationId, _myId!);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId, String conversationId) =>
      _repo.deleteMessage(messageId, conversationId);

  // ── Online status ─────────────────────────────────────────────────────────

  Future<void> setOnline(bool isOnline) async {
    if (_myId == null) return;
    await _repo.setOnlineStatus(_myId!, isOnline);
  }

  // ── Foreground restore sync ───────────────────────────────────────────────

  Future<void> syncOnResume(String conversationId) async {
    if (_myId == null) return;
    await _repo.syncMissedMessages(conversationId, _myId!);
  }

  // ── Offline queue ─────────────────────────────────────────────────────────

  Future<void> retryOfflineQueue() async {
    if (_myId == null) return;
    await _repo.retryOfflineQueue(_myId!);
  }

  void dispose() {
    _typingTimer?.cancel();
    if (_myId != null) {
      _repo.setOnlineStatus(_myId!, false).catchError((_) {});
    }
  }
}

// Keep the ChatSummary alias so existing group_chat_tab.dart compiles unchanged.
@Deprecated('Use RecentChatData from DatabaseHelper instead')
typedef ChatSummary = RecentChatData;
