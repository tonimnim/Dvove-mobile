import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../models/post.dart';

class OfficialPostsService {
  final ApiClient _apiClient;

  OfficialPostsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Create a new post with optimized multipart upload
  Future<Map<String, dynamic>> createPost({
    required String content,
    required String type,
    String? priority,
    DateTime? expiresAt,
    List<File>? images,
    bool commentsEnabled = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Build FormData for efficient multipart upload
      final formData = FormData.fromMap({
        'content': content,
        'type': type,
        'comments_enabled': commentsEnabled ? 1 : 0,
        if (priority != null) 'priority': priority,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      });

      // Add images if provided
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final file = images[i];

          // Check file size (5MB limit per image for performance)
          final fileSize = await file.length();

          if (fileSize > 5 * 1024 * 1024) {
            return {
              'success': false,
              'message': 'Image ${i + 1} exceeds 5MB limit',
            };
          }

          formData.files.add(MapEntry(
            'images[$i]',
            await MultipartFile.fromFile(
              file.path,
              filename: 'image_$i.jpg',
            ),
          ));
        }
      }

      final response = await _apiClient.post(
        ApiEndpoints.createPost,
        data: formData,
        options: Options(
          sendTimeout: Duration(seconds: 60), // 60 seconds for upload
          receiveTimeout: Duration(seconds: 60),
        ),
        onSendProgress: onProgress != null ? (sent, total) {
          final progress = sent / total;
          onProgress(progress);
        } : null,
      );

      return {
        'success': true,
        'message': 'Post created successfully',
        'post': Post.fromJson(response.data['data']),
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return {
          'success': false,
          'message': 'You don\'t have permission to create posts. Only county officials can post.',
        };
      }
      if (e.response?.statusCode == 422) {
        // Handle validation errors
        final errors = e.response?.data['errors'];
        final firstError = errors?.values.first?.first;
        return {
          'success': false,
          'message': firstError ?? 'Validation failed',
        };
      }
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to create post. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Update an existing post
  Future<Map<String, dynamic>> updatePost({
    required int postId,
    required String content,
    required String type,
    String? priority,
    DateTime? expiresAt,
    bool commentsEnabled = true,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.updatePost(postId),
        data: {
          'content': content,
          'type': type,
          'comments_enabled': commentsEnabled,
          if (priority != null) 'priority': priority,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        },
      );

      return {
        'success': true,
        'message': 'Post updated successfully',
        'post': response.data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update post',
      };
    }
  }

  // Delete a post
  Future<Map<String, dynamic>> deletePost(int postId) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.deletePost(postId),
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Post deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete post',
      };
    }
  }

  // Get official's own posts
  Future<Map<String, dynamic>> getMyPosts({
    int page = 1,
    String? status,
    String? type,
  }) async {
    try {
      final queryParams = {
        'page': page,
        if (status != null) 'status': status,
        if (type != null) 'type': type,
      };

      final response = await _apiClient.get(
        ApiEndpoints.myPosts,
        queryParameters: queryParams,
      );

      return {
        'success': true,
        'posts': response.data['data'],
        'meta': response.data['meta'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load posts',
      };
    }
  }

  // Get post analytics
  Future<Map<String, dynamic>> getPostAnalytics(int postId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.postAnalytics(postId),
      );

      return {
        'success': true,
        'analytics': response.data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load analytics',
      };
    }
  }
}