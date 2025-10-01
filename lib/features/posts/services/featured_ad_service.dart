import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../models/post.dart';
import '../../auth/models/user.dart';

class FeaturedAdService {
  static const String _featuredAdKey = 'featured_ad_cache';
  static const String _lastCheckKey = 'featured_ad_last_check';

  final ApiClient _apiClient;
  Post? _cachedFeaturedAd;

  FeaturedAdService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get cached featured ad (only valid until app restart)
  Post? get featuredAd => _cachedFeaturedAd;

  /// Check for featured ads on app startup
  Future<void> checkFeaturedAdOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      final lastCheck = prefs.getString(_lastCheckKey);

      // Only check once per day to minimize API calls
      if (lastCheck == today) {
        return;
      }

      // Make API call to get featured ads
      final response = await _apiClient.get('/ads', queryParameters: {
        'featured_only': true,
        'per_page': 1,
      });

      if (response.data['success'] == true) {
        final ads = response.data['data'] as List;
        if (ads.isNotEmpty) {
          // Convert ad to Post object for seamless integration
          final adData = ads.first;
          _cachedFeaturedAd = _convertAdToPost(adData);
        }
      }

      // Update last check date
      await prefs.setString(_lastCheckKey, today);
    } catch (e) {
      // Silently fail - featured ads are optional
      print('Failed to fetch featured ad: $e');
    }
  }

  /// Convert ad JSON to Post object for seamless UI integration
  Post _convertAdToPost(Map<String, dynamic> adJson) {
    return Post(
      id: adJson['id'],
      content: adJson['content'] ?? '',
      type: 'announcement', // Default type for ads
      mediaUrls: adJson['image_url'] != null ? [adJson['image_url']] : [],
      county: County(
        id: adJson['county']?['id'] ?? 0,
        name: adJson['county']?['name'] ?? 'Featured',
        slug: adJson['county']?['slug'] ?? 'featured',
      ),
      author: PostAuthor(
        id: 0, // Special ID for ads
        name: adJson['advertiser_name'] ?? 'Sponsored',
        profilePhoto: null,
        isOfficial: true, // Ads are "official"
      ),
      likesCount: 0,
      commentsCount: 0,
      viewsCount: adJson['impressions_count'] ?? 0,
      isLiked: false,
      createdAt: DateTime.now(),
      humanTime: 'sponsored',
      commentsEnabled: false, // Disable comments on ads
      // Ad-specific fields
      itemType: 'ad',
      adType: adJson['ad_type'] ?? 'featured',
      clickUrl: adJson['click_url'],
      advertiserName: adJson['advertiser_name'],
    );
  }

  /// Clear cached featured ad (for testing or logout)
  void clearCache() {
    _cachedFeaturedAd = null;
  }
}