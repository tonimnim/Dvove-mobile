import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../models/comment.dart';

class CommentsService {
  static const String _commentsPrefix = 'comments_cache_';
  static const String _lastCheckPrefix = 'comments_last_check_';
  static const int _cacheExpiryHours = 1;

  final ApiClient _apiClient;
  final Map<int, List<Comment>> _memoryCache = {};

  CommentsService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getComments(int postId, {int page = 1, bool forceRefresh = false}) async {
    try {
      final cacheKey = '$_commentsPrefix${postId}_$page';
      final lastCheckKey = '$_lastCheckPrefix${postId}_$page';

      if (!forceRefresh && _memoryCache.containsKey(postId)) {
        return {
          'success': true,
          'comments': _memoryCache[postId]!,
          'meta': {'from_cache': true},
        };
      }

      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        final lastCheck = prefs.getString(lastCheckKey);

        if (cachedData != null && lastCheck != null) {
          final lastCheckTime = DateTime.parse(lastCheck);
          final cacheAge = DateTime.now().difference(lastCheckTime);

          if (cacheAge.inHours < _cacheExpiryHours) {
            final List<dynamic> cachedJson = jsonDecode(cachedData);
            final List<Comment> cachedComments = cachedJson
                .map((json) => Comment.fromJson(json))
                .toList();

            _memoryCache[postId] = cachedComments;

            return {
              'success': true,
              'comments': cachedComments,
              'meta': {'from_cache': true},
            };
          }
        }
      }

      final response = await _apiClient.get(
        '/posts/$postId/comments',
        queryParameters: {
          'page': page,
          'per_page': 20,
        },
      );

      final List<Comment> comments = (response.data['data'] as List)
          .map((json) => Comment.fromJson(json))
          .toList();

      _memoryCache[postId] = comments;
      await _updatePersistentCache(cacheKey, lastCheckKey, comments);

      return {
        'success': true,
        'comments': comments,
        'meta': response.data['meta'],
        'has_ads': response.data['has_ads'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<void> _updatePersistentCache(String cacheKey, String lastCheckKey, List<Comment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = comments.map((c) => c.toJson()).toList();

      await prefs.setString(cacheKey, jsonEncode(commentsJson));
      await prefs.setString(lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
    }
  }

  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    try {
      final response = await _apiClient.post(
        '/posts/$postId/comment',
        data: {'content': content},
      );

      final comment = Comment.fromJson(response.data['data']);

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

  Future<Map<String, dynamic>> editComment(int commentId, String content) async {
    try {
      final response = await _apiClient.put(
        '/comments/$commentId',
        data: {'content': content},
      );

      final comment = Comment.fromJson(response.data['data']);

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

  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final response = await _apiClient.delete('/comments/$commentId');

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

  Future<Map<String, dynamic>> upvoteComment(int commentId) async {
    try {
      final response = await _apiClient.post('/comments/$commentId/upvote');

      return {
        'success': true,
        'score': response.data['data']['score'],
        'action': response.data['data']['action'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> downvoteComment(int commentId) async {
    try {
      final response = await _apiClient.post('/comments/$commentId/downvote');

      return {
        'success': true,
        'score': response.data['data']['score'],
        'action': response.data['data']['action'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<void> _clearCacheForPost(int postId) async {
    _memoryCache.remove(postId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith('${_commentsPrefix}${postId}_') ||
            key.startsWith('${_lastCheckPrefix}${postId}_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
    }
  }

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
    }
  }

  Future<Map<String, dynamic>> refreshComments(int postId, {int page = 1}) async {
    return getComments(postId, page: page, forceRefresh: true);
  }
}