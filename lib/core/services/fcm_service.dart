import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle subscription refresh in background
  if (message.data['action'] == 'refresh_subscription') {
    // The next time user opens the app, auth will be refreshed
    // Background refresh is handled by the foreground handler when app is opened
  }
}

class FcmService {
  static final FcmService instance = FcmService._internal();
  factory FcmService() => instance;
  FcmService._internal();

  FirebaseMessaging? _firebaseMessaging;
  bool _isInitialized = false;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized) return;

    _navigatorKey = navigatorKey;
    _firebaseMessaging = FirebaseMessaging.instance;
    _isInitialized = true;

    await _requestPermissions();
    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _firebaseMessaging?.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      'Default Channel',
      description: 'Default notification channel for app notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _navigateBasedOnNotificationType(data);
      } catch (e) {
      }
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging?.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Handle subscription refresh action
    if (message.data['action'] == 'refresh_subscription') {
      await _refreshSubscriptionStatus();
    }

    // Show local notification for foreground messages
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Default Channel',
            icon: '@drawable/ic_notification',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> _refreshSubscriptionStatus() async {
    // Refresh the user's subscription status from the API
    if (_navigatorKey?.currentContext != null) {
      try {
        final authProvider = _navigatorKey!.currentContext!.read<AuthProvider>();
        await authProvider.refreshUser();
      } catch (e) {
        // Silent fail - user will see updated status on next app open
      }
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateBasedOnNotificationType(message.data);
  }

  void _navigateBasedOnNotificationType(Map<String, dynamic> data) {
    if (_navigatorKey?.currentState == null) return;

    final type = data['type'];
    final articleId = data['article_id'];
    final postId = data['post_id'];

    if (type == 'constitution_daily' && articleId != null) {
      _navigatorKey!.currentState!.pushNamed(
        '/article-detail',
        arguments: {'articleId': articleId},
      );
    } else if (type == 'new_post' && postId != null) {
      _navigatorKey!.currentState!.pushNamed(
        '/post-detail',
        arguments: {'postId': postId},
      );
    } else if (type == 'alert' && postId != null) {
      _navigatorKey!.currentState!.pushNamed(
        '/post-detail',
        arguments: {'postId': postId},
      );
    }
  }

  Future<void> registerToken(AuthProvider authProvider) async {
    if (!_isInitialized || !authProvider.isAuthenticated) {
      return;
    }

    try {
      final token = await _firebaseMessaging?.getToken();
      if (token != null && token.isNotEmpty) {
        await authProvider.updateFcmToken(token);
      }
    } catch (e) {
    }
  }
}
