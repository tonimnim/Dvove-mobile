import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler (required for background operations)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background notifications are automatically shown by Firebase
  // This handler is only for data processing
  // The OS displays the notification if message.notification is present
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

    // Setup listeners
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {});

    // Initialize notifications (await to ensure channels are created before notifications arrive)
    await _initializeLocalNotifications();
    await _requestPermissions();

    // Check for initial message
    _firebaseMessaging?.getInitialMessage().then((initialMessage) {
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    });

    _isInitialized = true;
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

    // High priority channel for alerts and important notifications
    const highPriorityChannel = AndroidNotificationChannel(
      'default_channel',
      'Important Notifications',
      description: 'Alerts and important updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Subtle channel for daily constitution articles (Instagram-style)
    const dailyArticleChannel = AndroidNotificationChannel(
      'constitution_daily',
      'Daily Constitution Article',
      description: 'Daily constitution article - subtle notification with sound',
      importance: Importance.low,
      playSound: true, // Uses system default notification sound
      enableVibration: false, // No vibration for subtle experience
      showBadge: true,
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(highPriorityChannel);
    await android?.createNotificationChannel(dailyArticleChannel);
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
    final messageType = message.data['type'];
    final action = message.data['action'];

    // Handle subscription-related notifications
    if (action == 'refresh_subscription' || messageType == 'payment_success') {
      await _refreshSubscriptionStatus();

      // If payment success, show success feedback
      if (messageType == 'payment_success') {
        _showPaymentSuccessNotification();
      }
    }

    // Show local notification for foreground messages
    final notification = message.notification;
    if (notification != null) {
      // Determine channel and style based on notification type
      final isConstitutionDaily = messageType == 'constitution_daily';

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isConstitutionDaily ? 'constitution_daily' : 'default_channel',
            isConstitutionDaily ? 'Daily Constitution Article' : 'Important Notifications',
            channelDescription: isConstitutionDaily
                ? 'Daily constitution article - subtle notification'
                : 'Alerts and important updates',
            icon: '@drawable/ic_notification',
            importance: isConstitutionDaily ? Importance.low : Importance.high,
            priority: isConstitutionDaily ? Priority.low : Priority.high,
            playSound: true, // Uses system default sound for all notifications
            enableVibration: !isConstitutionDaily, // Vibration only for important notifications
            onlyAlertOnce: isConstitutionDaily,
            // BigTextStyle for expandable preview (Instagram-style)
            styleInformation: BigTextStyleInformation(
              notification.body ?? '',
              contentTitle: notification.title,
              summaryText: isConstitutionDaily ? 'Article of the Day' : null,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true, // Uses system default sound
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
    } else if (type == 'payment_success') {
      // Refresh subscription status and show success feedback
      _refreshSubscriptionStatus();
      _showPaymentSuccessNotification();
    }
  }

  void _showPaymentSuccessNotification() {
    // Show success snackbar to user
    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      final messenger = ScaffoldMessenger.maybeOf(context);

      messenger?.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payment Successful!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your subscription has been renewed',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF01775A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
