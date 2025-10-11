import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../models/poll.dart';

class PollsService {
  final ApiClient _apiClient;

  PollsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getPolls({String? status}) async {
    try {
      final queryParams = status != null ? {'status': status} : null;
      final response = await _apiClient.get(
        ApiEndpoints.polls,
        queryParameters: queryParams,
      );

      final List<Poll> polls = (response.data['data'] as List)
          .map((json) => Poll.fromJson(json))
          .toList();

      return {
        'success': true,
        'polls': polls,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> getPoll(int pollId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.pollDetails(pollId));
      final poll = Poll.fromJson(response.data['data']);

      return {
        'success': true,
        'poll': poll,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> vote(int pollId, Map<String, dynamic> voteData) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.votePoll(pollId),
        data: voteData,
      );

      final poll = Poll.fromJson(response.data['poll']);

      return {
        'success': true,
        'poll': poll,
        'message': response.data['message'] ?? 'Vote submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> getResults(int pollId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.pollResults(pollId));

      return {
        'success': true,
        'results': response.data,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}
