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
      if (e.response?.statusCode == 422) {
        // Always show our custom message for validation errors
        throw Exception('Please enter at least 2 characters');
      }
      throw Exception('Connection error. Please check your internet.');
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow; // Preserve our custom error messages
      }
      throw Exception('Search failed. Please try again.');
    }
  }
}