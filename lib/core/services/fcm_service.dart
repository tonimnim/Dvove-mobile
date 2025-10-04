import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/auth/providers/auth_provider.dart';

class FcmService {
  static final FcmService instance = FcmService._internal();
  factory FcmService() => instance;
  FcmService._internal();

  FirebaseMessaging? _firebaseMessaging;
  bool _isInitialized = false;

  /// Initialize FCM and set up token refresh listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    _firebaseMessaging = FirebaseMessaging.instance;
    _isInitialized = true;

    // Request notification permissions
    await _requestPermissions();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // Token will be updated when AuthProvider is available
      // This is handled in registerToken() calls
    });
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging?.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
      // Permissions granted
    }
  }

  /// Get and register FCM token with backend
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
      // Silently fail - FCM token registration is not critical
    }
  }
}
