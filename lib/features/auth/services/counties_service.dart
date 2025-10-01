import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../models/user.dart';

class CountiesService {
  final ApiClient _apiClient;

  CountiesService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getCounties() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.counties);

      final List<County> counties = (response.data['data'] as List)
          .map((json) => County.fromJson(json))
          .toList();

      return {
        'success': true,
        'counties': counties,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
        'counties': <County>[],
      };
    }
  }
}