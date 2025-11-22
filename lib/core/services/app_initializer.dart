import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import '../../main.dart';
import 'fcm_service.dart';
import 'intelligent_cache_service.dart';

/// Lazy app initialization - initializes Firebase and background services
/// Call this from HomeScreen or LoginScreen after navigation
class AppInitializer {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize FCM (await to ensure notification channels are created)
      await FcmService.instance.initialize(navigatorKey: navigatorKey);

      // Start cache service (non-blocking)
      IntelligentCacheService.instance.initialize();

      _isInitialized = true;
    } catch (e, stackTrace) {
      // Log errors in debug mode only (won't show in production)
      if (kDebugMode) {
        print('AppInitializer: Firebase initialization failed - $e');
        print('Stack trace: $stackTrace');
      }
      // App continues to work without Firebase (graceful degradation)
    }
  }
}
