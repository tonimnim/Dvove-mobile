import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../models/comment.dart';

class CommentsService {
  static const String _commentsPrefix = 'comments_cache_';
  static const String _lastCheckPrefix = 'comments_last_check_';
  static const int _cacheExpiryHours = 1; // Cache comments for 1 hour

  final ApiClient _apiClient;
  final Map<int, List<Comment>> _memoryCache = {};

  CommentsService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get comments with caching support
  Future<Map<String, dynamic>> getComments(int postId, {int page = 1, bool forceRefresh = false}) async {
    try {
      final cacheKey = '$_commentsPrefix${postId}_$page';
      final lastCheckKey = '$_lastCheckPrefix${postId}_$page';

      // Check memory cache first
      if (!forceRefresh && _memoryCache.containsKey(postId)) {
        return {
          'success': true,
          'comments': _memoryCache[postId]!,
          'meta': {'from_cache': true},
        };
      }

      // Check persistent cache if not forcing refresh
      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        final lastCheck = prefs.getString(lastCheckKey);

        if (cachedData != null && lastCheck != null) {
          final lastCheckTime = DateTime.parse(lastCheck);
          final cacheAge = DateTime.now().difference(lastCheckTime);

          // Use cached data if less than 1 hour old
          if (cacheAge.inHours < _cacheExpiryHours) {
            final List<dynamic> cachedJson = jsonDecode(cachedData);
            final List<Comment> cachedComments = cachedJson
                .map((json) => Comment.fromJson(json))
                .toList();

            // Update memory cache
            _memoryCache[postId] = cachedComments;

            return {
              'success': true,
              'comments': cachedComments,
              'meta': {'from_cache': true},
            };
          }
        }
      }

      // Fetch from API
      final response = await _apiClient.get(
        '/posts/$postId/comments',
        queryParameters: {
          'page': page,
          'per_page': 20,
        },
      );

      // Parse comments and ads from response
      final List<Comment> comments = (response.data['data'] as List)
          .map((json) => Comment.fromJson(json))
          .toList();

      // Update caches
      _memoryCache[postId] = comments;
      await _updatePersistentCache(cacheKey, lastCheckKey, comments);

      return {
        'success': true,
        'comments': comments,
        'meta': response.data['meta'],
        'has_ads': response.data['has_ads'],
      };
    } catch (e) {
      print('Failed to fetch comments: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Update persistent cache
  Future<void> _updatePersistentCache(String cacheKey, String lastCheckKey, List<Comment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = comments.map((c) => c.toJson()).toList();

      await prefs.setString(cacheKey, jsonEncode(commentsJson));
      await prefs.setString(lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to update comments cache: $e');
    }
  }

  /// Add comment to a post
  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    try {
      final response = await _apiClient.post(
        '/posts/$postId/comment',
        data: {'content': content},
      );

      final comment = Comment.fromJson(response.data['data']);

      // Clear cache for this post to force refresh
      await _clearCacheForPost(postId);

      return {
        'success': true,
        'comment': comment,
        'message': response.data['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Edit comment
  Future<Map<String, dynamic>> editComment(int commentId, String content) async {
    try {
      final response = await _apiClient.put(
        '/comments/$commentId',
        data: {'content': content},
      );

      final comment = Comment.fromJson(response.data['data']);

      // Clear all caches since we don't know which post this comment belongs to
      await clearAllCache();

      return {
        'success': true,
        'comment': comment,
        'message': response.data['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Delete comment
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final response = await _apiClient.delete('/comments/$commentId');

      // Clear all caches since we don't know which post this comment belongs to
      await clearAllCache();

      return {
        'success': true,
        'message': response.data['message'] ?? 'Comment deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Clear cache for a specific post
  Future<void> _clearCacheForPost(int postId) async {
    // Clear memory cache
    _memoryCache.remove(postId);

    // Clear persistent cache for all pages of this post
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Remove all cache entries for this post (all pages)
      for (String key in keys) {
        // Use underscore separator to ensure exact post ID match
        if (key.startsWith('${_commentsPrefix}${postId}_') ||
            key.startsWith('${_lastCheckPrefix}${postId}_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Failed to clear persistent cache for post $postId: $e');
    }
  }

  /// Clear all caches
  Future<void> clearAllCache() async {
    try {
      _memoryCache.clear();

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith(_commentsPrefix) || key.startsWith(_lastCheckPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Failed to clear comments cache: $e');
    }
  }

  /// Force refresh comments for a post
  Future<Map<String, dynamic>> refreshComments(int postId, {int page = 1}) async {
    return getComments(postId, page: page, forceRefresh: true);
  }
}