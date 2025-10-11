import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../models/post.dart';
import 'comments_service.dart';

class PostsService {
  final ApiClient _apiClient;
  final CommentsService _commentsService;

  PostsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _commentsService = CommentsService(apiClient: apiClient);

  Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int perPage = 20,
    String? type,
    String? excludeType,
    int? countyId,
    String? search,
    Map<String, String>? headers,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'per_page': perPage,
        if (type != null) 'type': type,
        if (excludeType != null) 'exclude_type': excludeType,
        if (countyId != null) 'county_id': countyId,
        if (search != null) 'search': search,
      };

      final response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );

      final List<Post> posts = (response.data['data'] as List)
          .map((json) {
            try {
              return Post.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .where((post) => post != null)
          .cast<Post>()
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

  Future<Map<String, dynamic>> getPost(String postId) async {
    try {
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

  Future<Map<String, dynamic>> likePost(String postId) async {
    try {
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

  Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
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

  Future<Map<String, dynamic>> getComments(String postId, {int page = 1}) async {
    final numericId = int.parse(postId.replaceFirst('ad_', ''));
    return _commentsService.getComments(numericId, page: page);
  }

  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    final numericId = int.parse(postId.replaceFirst('ad_', ''));
    return _commentsService.addComment(numericId, content);
  }

  Future<Map<String, dynamic>> editComment(int commentId, String content) async {
    return _commentsService.editComment(commentId, content);
  }

  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    return _commentsService.deleteComment(commentId);
  }

  Future<Map<String, dynamic>> upvoteComment(int commentId) async {
    return _commentsService.upvoteComment(commentId);
  }

  Future<Map<String, dynamic>> downvoteComment(int commentId) async {
    return _commentsService.downvoteComment(commentId);
  }

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

  Future<Map<String, dynamic>> createPost({
    required String content,
    required String type,
    String? scope,
    List<String>? imagePaths,
    DateTime? expiresAt,
    String? priority,
  }) async {
    try {
      dynamic data;

      if (imagePaths != null && imagePaths.isNotEmpty) {
        final formData = FormData();

        if (content.isNotEmpty) formData.fields.add(MapEntry('content', content));
        formData.fields.add(MapEntry('type', type));
        if (scope != null) formData.fields.add(MapEntry('scope', scope));

        if (expiresAt != null) {
          formData.fields.add(MapEntry('expires_at', expiresAt.toIso8601String()));
        }
        if (priority != null) {
          formData.fields.add(MapEntry('priority', priority));
        }

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
        data = {
          'content': content,
          'type': type,
          if (scope != null) 'scope': scope,
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

  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String content,
    required String type,
    DateTime? expiresAt,
    String? priority,
    bool commentsEnabled = true,
    List<String>? newImagePaths,
    List<String>? keepImageUrls,
  }) async {
    try {
      final numericId = int.parse(postId.replaceFirst('ad_', ''));

      dynamic data;

      if (newImagePaths != null && newImagePaths.isNotEmpty) {
        final formData = FormData();

        if (content.isNotEmpty) formData.fields.add(MapEntry('content', content));
        formData.fields.add(MapEntry('type', type));

        if (expiresAt != null) {
          formData.fields.add(MapEntry('expires_at', expiresAt.toIso8601String()));
        }
        if (priority != null) {
          formData.fields.add(MapEntry('priority', priority));
        }
        formData.fields.add(MapEntry('comments_enabled', commentsEnabled.toString()));

        if (keepImageUrls != null && keepImageUrls.isNotEmpty) {
          for (String url in keepImageUrls) {
            formData.fields.add(MapEntry('keep_images[]', url));
          }
        }

        for (String imagePath in newImagePaths) {
          formData.files.add(MapEntry(
            'new_images[]',
            await MultipartFile.fromFile(
              imagePath,
              filename: imagePath.split('/').last,
            ),
          ));
        }

        data = formData;
      } else {
        data = {
          'content': content,
          'type': type,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          if (priority != null) 'priority': priority,
          'comments_enabled': commentsEnabled,
          if (keepImageUrls != null && keepImageUrls.isNotEmpty) 'keep_images': keepImageUrls,
        };
      }

      final response = await _apiClient.put(
        ApiEndpoints.updatePost(numericId),
        data: data,
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

  Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
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