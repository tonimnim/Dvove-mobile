import '../../core/api/api_client.dart';
import '../utils/constants.dart';

class AdTrackingService {
  final ApiClient _apiClient = ApiClient();

  // Keep track of impressions to avoid duplicates
  static final Set<int> _trackedImpressions = {};

  // Reset tracked impressions when navigating away
  static void resetTracking() {
    _trackedImpressions.clear();
  }

  // Track impression - fire and forget
  Future<void> trackImpression({
    required int adId,
    required String context,
  }) async {
    // Skip if already tracked
    if (_trackedImpressions.contains(adId)) return;

    _trackedImpressions.add(adId);

    try {
      await _apiClient.post(
        ApiEndpoints.adImpression(adId),
        data: {'context': context},
      );
    } catch (e) {
      // Silently fail - don't block UI
      print('[AdTracking] Impression failed: $e');
    }
  }

  // Track click - fire and forget
  Future<String?> trackClick({
    required int adId,
    required String context,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.adClick(adId),
        data: {'context': context},
      );

      // Return click URL from response
      return response.data['click_url'];
    } catch (e) {
      // Silently fail - don't block UI
      print('[AdTracking] Click failed: $e');
      return null;
    }
  }
}