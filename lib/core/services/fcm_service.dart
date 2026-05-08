import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles background message delivery from FCM.
///
/// Must be a top-level function — called by Firebase when the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this is called.
  debugPrint('[FCM] Background message: ${message.messageId}');
  await FcmService.instance.handleIncomingMessage(message);
}

class FcmService {
  FcmService._internal();
  static final FcmService instance = FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback so the rest of the app can react to taps on notifications.
  Function(Map<String, dynamic> data)? onNotificationTap;

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Request permission (Android 13+ requires explicit grant)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Set up local notifications for foreground display
    await _initLocalNotifications();

    // Get and cache the FCM token
    _fcmToken = await _fcm.getToken();
    debugPrint('[FCM] Token: $_fcmToken');

    // Refresh token listener
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('[FCM] Token refreshed: $token');
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap when app was in background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Notification tap when app was killed
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ── Local notifications setup ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            onNotificationTap?.call(data);
          } catch (_) {}
        }
      },
    );

    // High-importance notification channel for Android
    const channel = AndroidNotificationChannel(
      'bhaichara_messages',
      'Bhaichara Messages',
      description: 'Chat messages, calls and live alerts',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Message handling ──────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'bhaichara_messages',
          'Bhaichara Messages',
          channelDescription: 'Chat messages, calls and live alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    onNotificationTap?.call(message.data);
  }

  Future<void> handleIncomingMessage(RemoteMessage message) async {
    // Background handling — save to sqflite if needed.
    // The main Firebase RTDB listener handles this when the app restores.
    debugPrint('[FCM] Handling background: ${message.data}');
  }

  // ── Token management ──────────────────────────────────────────────────────

  /// Subscribe to a topic (e.g. for group notifications).
  Future<void> subscribeToTopic(String topic) =>
      _fcm.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  /// Save current [fcmToken] to the Supabase profiles table, and re-save
  /// whenever the token refreshes.  Call once after login.
  void registerTokenWithProfile(
    Future<void> Function(String token) saveCallback,
  ) {
    if (_fcmToken != null) {
      saveCallback(_fcmToken!).catchError((_) {});
    }
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      saveCallback(token).catchError((_) {});
    });
  }

  /// One-shot: save current token only (no refresh listener).
  Future<void> saveFcmTokenToProfile(
    Future<void> Function(String token) saveCallback,
  ) async {
    if (_fcmToken != null) {
      await saveCallback(_fcmToken!);
    }
  }
}
