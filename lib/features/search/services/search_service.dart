import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../../posts/models/post.dart';

class SearchService {
  final ApiClient _apiClient;

  SearchService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Search for posts using the backend API
  /// Returns a list of posts matching the search query
  Future<Map<String, dynamic>> search({
    required String query,
    String? type,
    int? countyId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'page': page,
        'per_page': perPage,
        if (type != null) 'type': type,
        if (countyId != null) 'county_id': countyId,
      };

      // Debug logging
      print('[SearchService] Searching with params: $queryParams');

      final response = await _apiClient.get(
        ApiEndpoints.search,
        queryParameters: queryParams,
      );

      // Parse posts using existing Post model
      final List<Post> posts = (response.data['data'] as List)
          .map((json) => Post.fromJson(json))
          .toList();

      return {
        'success': true,
        'posts': posts,
        'meta': response.data['meta'],
        'links': response.data['links'],
        'searchTerm': query,
      };
    } on DioException catch (e) {
      print('[SearchService] API Error: ${e.message}');
      if (e.response?.statusCode == 422) {
        throw Exception('Search query is required');
      }
      throw Exception('Search failed: ${e.message}');
    } catch (e) {
      print('[SearchService] Error: $e');
      throw Exception('Search failed: $e');
    }
  }
}