import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'comments_service.dart';

class PostsService {
  final ApiClient _apiClient;
  final CommentsService _commentsService;

  PostsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _commentsService = CommentsService(apiClient: apiClient);

  // Fetch posts with pagination
  Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int perPage = 20,
    String? type,
    int? countyId,
    String? search,
    Map<String, String>? headers,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'per_page': perPage,
        if (type != null) 'type': type,
        if (countyId != null) 'county_id': countyId,
        if (search != null) 'search': search,
      };

      final response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );

      print('🔍 [POSTS_SERVICE] Raw response.data keys: ${response.data.keys}');
      print('🔍 [POSTS_SERVICE] response.data["data"] length: ${(response.data['data'] as List).length}');

      // Parse all items (posts + ads) from the data array
      final List<Post> posts = (response.data['data'] as List)
          .map((json) {
            try {
              return Post.fromJson(json);
            } catch (e) {
              print('⚠️ [POSTS_SERVICE] Error parsing item: ${json['id']} - $e');
              return null;
            }
          })
          .where((post) => post != null)
          .cast<Post>()
          .toList();

      print('✅ [POSTS_SERVICE] Parsed ${posts.length} items (posts + ads) successfully');

      return {
        'success': true,
        'posts': posts,
        'meta': response.data['meta'],
        'links': response.data['links'],
      };
    } catch (e) {
      print('❌ [POSTS_SERVICE] Exception in getPosts: $e');
      print('📍 [POSTS_SERVICE] Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Get single post
  Future<Map<String, dynamic>> getPost(String postId) async {
    try {
      // Parse numeric ID (ads can't be fetched individually)
      final numericId = int.parse(postId.replaceFirst('ad_', ''));
      final response = await _apiClient.get(ApiEndpoints.postDetails(numericId));
      final post = Post.fromJson(response.data['data']);

      return {
        'success': true,
        'post': post,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Like a post
  Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      // Parse numeric ID (ads can't be liked)
      final numericId = int.parse(postId.replaceFirst('ad_', ''));
      final response = await _apiClient.post(ApiEndpoints.likePost(numericId));

      return {
        'success': true,
        'is_liked': response.data['data']['is_liked'],
        'likes_count': response.data['data']['likes_count'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Unlike a post
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      // Parse numeric ID (ads can't be unliked)
      final numericId = int.parse(postId.replaceFirst('ad_', ''));
      final response = await _apiClient.post(ApiEndpoints.unlikePost(numericId));

      return {
        'success': true,
        'is_liked': response.data['data']['is_liked'],
        'likes_count': response.data['data']['likes_count'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Get comments for a post with caching
  Future<Map<String, dynamic>> getComments(String postId, {int page = 1}) async {
    // Parse numeric ID (ads can't have comments)
    final numericId = int.parse(postId.replaceFirst('ad_', ''));
    return _commentsService.getComments(numericId, page: page);
  }

  // Add comment to a post
  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    // Parse numeric ID (ads can't have comments)
    final numericId = int.parse(postId.replaceFirst('ad_', ''));
    return _commentsService.addComment(numericId, content);
  }

  // Edit comment
  Future<Map<String, dynamic>> editComment(int commentId, String content) async {
    return _commentsService.editComment(commentId, content);
  }

  // Delete comment
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    return _commentsService.deleteComment(commentId);
  }

  // Report a post
  Future<Map<String, dynamic>> reportPost(
    int postId,
    String reason,
    String? description,
  ) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.posts}/$postId/report',
        data: {
          'reason': reason,
          if (description != null) 'description': description,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Post reported successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Create a new post with media support
  Future<Map<String, dynamic>> createPost({
    required String content,
    required String type,
    List<String>? imagePaths,
    DateTime? expiresAt,
    String? priority,
  }) async {
    try {
      // Use FormData for multipart upload when media is present
      dynamic data;

      if (imagePaths != null && imagePaths.isNotEmpty) {
        // Create FormData for file upload
        final formData = FormData();

        // Add text fields
        if (content.isNotEmpty) formData.fields.add(MapEntry('content', content));
        formData.fields.add(MapEntry('type', type));
        // Don't send comments_enabled in FormData - backend defaults to true

        if (expiresAt != null) {
          formData.fields.add(MapEntry('expires_at', expiresAt.toIso8601String()));
        }
        if (priority != null) {
          formData.fields.add(MapEntry('priority', priority));
        }

        // Add images
        for (String imagePath in imagePaths) {
          formData.files.add(MapEntry(
            'images[]',
            await MultipartFile.fromFile(
              imagePath,
              filename: imagePath.split('/').last,
            ),
          ));
        }

        data = formData;
      } else {
        // Use regular JSON for text-only posts
        data = {
          'content': content,
          'type': type,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          if (priority != null) 'priority': priority,
          'comments_enabled': true,
        };
      }

      final response = await _apiClient.post(
        ApiEndpoints.createPost,
        data: data,
      );

      final post = Post.fromJson(response.data['data']);

      return {
        'success': true,
        'post': post,
        'message': response.data['message'] ?? 'Post created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Update/Edit a post
  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String content,
    required String type,
    DateTime? expiresAt,
    String? priority,
    bool commentsEnabled = true,
  }) async {
    try {
      // Parse numeric ID (ads can't be edited)
      final numericId = int.parse(postId.replaceFirst('ad_', ''));
      final response = await _apiClient.put(
        ApiEndpoints.updatePost(numericId),
        data: {
          'content': content,
          'type': type,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          if (priority != null) 'priority': priority,
          'comments_enabled': commentsEnabled,
        },
      );

      final post = Post.fromJson(response.data['data']);

      return {
        'success': true,
        'post': post,
        'message': response.data['message'] ?? 'Post updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Delete a post
  Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      // Parse numeric ID (ads can't be deleted)
      final numericId = int.parse(postId.replaceFirst('ad_', ''));
      await _apiClient.delete(ApiEndpoints.deletePost(numericId));

      return {
        'success': true,
        'message': 'Post deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}