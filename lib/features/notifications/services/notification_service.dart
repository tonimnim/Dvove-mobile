import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/notification.dart' as models;

/// Service for handling notification API calls
class NotificationService {
  final ApiClient _apiClient;

  // Simple memory cache
  static List<models.Notification>? _cachedNotifications;
  static DateTime? _lastCacheTime;
  static String? _lastCacheKey;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  NotificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetch user notifications with optional filtering
  /// GET /api/v1/user/notifications
  Future<models.NotificationResponse> getNotifications({
    bool? unreadOnly,
    String? type, // 'alert', 'new_post', 'subscription'
    String? priority, // 'high', 'medium', 'low'
    int? perPage,
    int? page,
  }) async {
    try {
      // Create cache key based on filters
      final cacheKey = '${unreadOnly}_${type}_${priority}_${perPage}_${page}';

      // Check cache for first page requests only
      if (page == 1 && _cachedNotifications != null &&
          _lastCacheTime != null && _lastCacheKey == cacheKey &&
          DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
        return models.NotificationResponse(
          success: true,
          notifications: _cachedNotifications!,
          meta: models.NotificationMeta(
            currentPage: 1,
            lastPage: 1,
            perPage: _cachedNotifications!.length,
            total: _cachedNotifications!.length,
            unreadCount: _cachedNotifications!.where((n) => !n.isRead).length,
          ),
        );
      }

      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (unreadOnly == true) queryParams['unread_only'] = 'true';
      if (type != null) queryParams['type'] = type;
      if (priority != null) queryParams['priority'] = priority;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();

      final response = await _apiClient.get(
        '/user/notifications',
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final notificationResponse = models.NotificationResponse.fromJson(response.data);

        // Cache first page results only
        if (page == 1) {
          _cachedNotifications = notificationResponse.notifications;
          _lastCacheTime = DateTime.now();
          _lastCacheKey = cacheKey;
        }

        return notificationResponse;
      } else {
        throw Exception('Failed to fetch notifications: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      throw Exception('Failed to load notifications: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// Clear cache when notifications change
  static void _clearCache() {
    _cachedNotifications = null;
    _lastCacheTime = null;
    _lastCacheKey = null;
  }

  /// Mark a single notification as read
  /// POST /api/v1/user/notifications/{notification_id}/read
  Future<models.Notification> markAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post('/user/notifications/$notificationId/read');

      if (response.data['success'] == true) {
        _clearCache(); // Clear cache when notification changes
        return models.Notification.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to mark notification as read: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('You cannot modify this notification');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Notification not found');
      }

      throw Exception('Failed to mark notification as read: ${e.message}');
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  /// POST /api/v1/user/notifications/read-all
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await _apiClient.post('/user/notifications/read-all');

      if (response.data['success'] == true) {
        final data = response.data['data'];

        _clearCache(); // Clear cache when notifications change

        return {
          'success': true,
          'message': response.data['message'],
          'updated_count': data['updated_count'],
          'remaining_unread': data['remaining_unread'],
        };
      } else {
        throw Exception('Failed to mark all notifications as read: ${response.data['message']}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to mark all notifications as read: ${e.message}');
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Get unread notification count only (efficient for badges)
  Future<int> getUnreadCount() async {
    try {
      // Fetch only 1 notification to get meta data with unread count
      final response = await getNotifications(perPage: 1);
      return response.meta.unreadCount;
    } catch (e) {
      return 0; // Return 0 on error to avoid breaking UI
    }
  }

  /// Get emergency alerts only (high priority)
  Future<models.NotificationResponse> getEmergencyAlerts({int? perPage, int? page}) async {
    return getNotifications(
      type: 'alert',
      priority: 'high',
      perPage: perPage,
      page: page,
    );
  }

  /// Get unread notifications only
  Future<models.NotificationResponse> getUnreadNotifications({int? perPage, int? page}) async {
    return getNotifications(
      unreadOnly: true,
      perPage: perPage,
      page: page,
    );
  }
}