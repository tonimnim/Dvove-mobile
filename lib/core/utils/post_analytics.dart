import 'package:flutter/foundation.dart';

/// Simple analytics for tracking post behavior
/// No logging in production - analytics removed for smaller app size
class PostAnalytics {
  static void trackPostCreated(String type, bool hasMedia, {int? mediaCount}) {
    // No logging in production
  }

  static void trackPostFailed(String reason, {int? attempt}) {
    // No logging in production
  }

  static void trackPostSynced(Duration syncTime, {String? type}) {
    // No logging in production
  }

  static void trackUploadProgress(double progress, {bool hasMedia = false}) {
    // No logging in production
  }

  static void trackRetry(int attempt, String reason) {
    // No logging in production
  }

  /// Test scenario tracking for validation
  static void trackTestScenario(String scenario, {bool success = true}) {
    // No logging in production
  }
}