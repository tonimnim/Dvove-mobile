import 'package:flutter/foundation.dart';

/// Simple analytics for tracking post behavior
/// Only prints to console in debug mode - no external services
class PostAnalytics {
  static void trackPostCreated(String type, bool hasMedia, {int? mediaCount}) {
    if (kDebugMode) {
      print('[ANALYTICS] Post created: type=$type, hasMedia=$hasMedia, mediaCount=${mediaCount ?? 0}');
    }
  }

  static void trackPostFailed(String reason, {int? attempt}) {
    if (kDebugMode) {
      print('[ANALYTICS] Post failed: reason=$reason, attempt=${attempt ?? 1}');
    }
  }

  static void trackPostSynced(Duration syncTime, {String? type}) {
    if (kDebugMode) {
      print('[ANALYTICS] Post synced: duration=${syncTime.inSeconds}s, type=${type ?? 'unknown'}');
    }
  }

  static void trackUploadProgress(double progress, {bool hasMedia = false}) {
    if (kDebugMode && progress == 1.0) {
      print('[ANALYTICS] Upload completed: hasMedia=$hasMedia');
    }
  }

  static void trackRetry(int attempt, String reason) {
    if (kDebugMode) {
      print('[ANALYTICS] Retry attempt $attempt: reason=$reason');
    }
  }

  /// Test scenario tracking for validation
  static void trackTestScenario(String scenario, {bool success = true}) {
    if (kDebugMode) {
      print('[TEST] Scenario: $scenario - ${success ? 'PASSED ✅' : 'FAILED ❌'}');
    }
  }
}