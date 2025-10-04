import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class SubscriptionService {
  final ApiClient _apiClient;

  SubscriptionService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Renew subscription via M-PESA
  /// Calls POST /api/v1/subscription/renew
  Future<Map<String, dynamic>> renewSubscription(String phoneNumber) async {
    try {
      final response = await _apiClient.post('/subscription/renew', data: {
        'phone_number': phoneNumber,
      });

      if (response.data['success'] == true) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to initiate payment');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Only officials can renew subscriptions');
      } else if (e.response?.statusCode == 422) {
        // Check for validation errors first
        final errors = e.response?.data['errors'];
        if (errors != null && errors['phone_number'] != null) {
          throw Exception(errors['phone_number'][0]);
        }

        // Otherwise use the main message (e.g., active subscription error)
        final message = e.response?.data['message'];
        if (message != null) {
          throw Exception(message);
        }

        throw Exception('Invalid request');
      }

      throw Exception('Failed to initiate payment. Please try again.');
    } catch (e) {
      throw Exception('Failed to initiate payment: $e');
    }
  }
}
