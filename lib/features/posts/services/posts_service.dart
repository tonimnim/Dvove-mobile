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

      // Debug logging
      print('[PostsService] Fetching posts from: ${_apiClient.dio.options.baseUrl}${ApiEndpoints.posts}');
      print('[PostsService] Query params: $queryParams');

      final response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );

      final List<Post> posts = (response.data['data'] as List)
          .map((json) => Post.fromJson(json))
          .toList();

      return {
        'success': true,
        'posts': posts,
        'meta': response.data['meta'],
        'links': response.data['links'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Get single post
  Future<Map<String, dynamic>> getPost(int postId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.postDetails(postId));
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
  Future<Map<String, dynamic>> likePost(int postId) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.likePost(postId));

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
  Future<Map<String, dynamic>> unlikePost(int postId) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.unlikePost(postId));

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
  Future<Map<String, dynamic>> getComments(int postId, {int page = 1}) async {
    return _commentsService.getComments(postId, page: page);
  }

  // Add comment to a post
  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    return _commentsService.addComment(postId, content);
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
      // Debug logging
      print('[PostsService] Creating post at: ${_apiClient.dio.options.baseUrl}${ApiEndpoints.posts}');
      print('[PostsService] Type: $type, Content length: ${content.length}');

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
    required int postId,
    required String content,
    required String type,
    DateTime? expiresAt,
    String? priority,
    bool commentsEnabled = true,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.updatePost(postId),
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
  Future<Map<String, dynamic>> deletePost(int postId) async {
    try {
      await _apiClient.delete(ApiEndpoints.deletePost(postId));

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