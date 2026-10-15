import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import '../utils/error_messages.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Receives private chat alerts through FCM and stores each signed-in user's
/// device token in Supabase. Server credentials never enter this client.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat messages',
    description: 'Alerts for new Apni Gari messages',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _openedController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _activeUserId;
  Map<String, dynamic>? _pendingOpen;
  bool _ready = false;

  Stream<Map<String, dynamic>> get openedChats => _openedController.stream;
  Map<String, dynamic>? takePendingOpen() {
    final pending = _pendingOpen;
    _pendingOpen = null;
    return pending;
  }

  Future<void> initialize() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _publishOpen(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } on FormatException {
          debugLog('Ignoring malformed chat notification payload.');
        } on TypeError {
          debugLog('Ignoring malformed chat notification payload.');
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    try {
      // Firebase's native Android configuration is supplied by
      // android/app/google-services.json, which contains project-specific IDs.
      await Firebase.initializeApp();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_handleForegroundMessage(message));
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _publishOpen(message.data),
      );
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) _publishOpen(initialMessage.data);
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
        final userId = _activeUserId;
        if (userId != null) unawaited(_saveTokenSafely(userId, token));
      });
      _ready = true;
    } catch (error) {
      // The rest of the app remains usable until Firebase is configured.
      debugLog('Push notifications are not configured yet: $error');
    }
  }

  Future<void> registerForUser(String userId) async {
    if (!_ready || userId.isEmpty) return;
    if (_activeUserId == userId) return;
    _activeUserId = userId;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _saveToken(userId, token);
    } catch (error) {
      debugLog('Could not register this device for message alerts: $error');
    }
  }

  Future<void> unregisterForUser(String userId) async {
    if (!_ready || userId.isEmpty) return;
    _activeUserId = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supabase.instance.client
          .from('push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (error) {
      debugLog('Could not unregister this device notification token: $error');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != userId) return;
    await client.from('push_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> _saveTokenSafely(String userId, String token) async {
    try {
      await _saveToken(userId, token);
    } catch (error) {
      debugLog('Could not update this device notification token: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'New message';
    final body = message.notification?.body ?? 'You have a new chat message.';
    await _local.show(
      id: message.messageId.hashCode.abs(),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat messages',
          channelDescription: 'Alerts for new Apni Gari messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _publishOpen(Map<String, dynamic> data) {
    if (data['thread_id'] == null || data['listing_id'] == null) return;
    _pendingOpen = data;
    _openedController.add(data);
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _openedController.close();
  }
}
