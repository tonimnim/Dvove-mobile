import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/constants.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  AuthService({ApiClient? apiClient, SecureStorage? storage})
      : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? SecureStorage();

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required int countyId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'county_id': countyId,
        },
      );

      try {
        final data = response.data['data'];

        final user = User.fromJson(data['user']);

        final message = response.data['message'];

        return {
          'success': true,
          'user': user,
          'message': message,
          'email_verification_required': data['email_verification_required'],
          'email': data['email'],
          'expires_in': data['expires_in'],
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Failed to process registration response: $e',
        };
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final responseData = e.response?.data;

        final errors = responseData?['errors'];

        if (errors != null && errors is Map<String, dynamic>) {

          // Extract user-friendly error messages - handle multiple errors intelligently
          String finalMessage = '';

          bool hasUsernameError = errors.containsKey('username') && errors['username'] is List && errors['username'].isNotEmpty;
          bool hasEmailError = errors.containsKey('email') && errors['email'] is List && errors['email'].isNotEmpty;

          if (hasUsernameError && hasEmailError) {
            // Both username and email are taken
            finalMessage = 'Both this username and email are already taken. Please choose different credentials.';
          } else if (hasUsernameError) {
            // Only username error
            String message = errors['username'].first.toString();
            if (message.contains('already been taken')) {
              finalMessage = 'This username is already taken. Please choose a different username.';
            } else {
              finalMessage = message;
            }
          } else if (hasEmailError) {
            // Only email error
            String message = errors['email'].first.toString();
            if (message.contains('already been taken')) {
              finalMessage = 'This email address is already registered. Please use a different email or try logging in.';
            } else {
              finalMessage = message;
            }
          } else {
            // Fallback to first error found
            final firstField = errors.keys.first;
            final firstMessages = errors[firstField];
            if (firstMessages is List && firstMessages.isNotEmpty) {
              finalMessage = firstMessages.first.toString();
            }
          }

          return {
            'success': false,
            'message': finalMessage,
          };
        }
      }

      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String login, // Can be username, phone, or email
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          'login': login,
          'password': password,
        },
      );

      final data = response.data['data'];
      final token = data['token'];
      final user = User.fromJson(data['user']);

      // Save token and user data
      await _storage.saveToken(token);
      await _storage.saveUserData(jsonEncode(data['user']));

      return {
        'success': true,
        'user': user,
        'token': token,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
      await _storage.clearAll();

      return {
        'success': true,
        'message': 'Logged out successfully',
      };
    } catch (e) {
      // Clear local storage even if API call fails
      await _storage.clearAll();
      return {
        'success': true,
        'message': 'Logged out locally',
      };
    }
  }

  Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    try {
      // If not forcing refresh, check cached data first
      if (!forceRefresh) {
        final cachedUserData = await _storage.getUserData();
        if (cachedUserData != null) {
          return User.fromJson(jsonDecode(cachedUserData));
        }
      }

      // Fetch fresh data from API
      final response = await _apiClient.get(ApiEndpoints.user);
      final user = User.fromJson(response.data['data']);

      // Cache the fresh user data
      await _storage.saveUserData(jsonEncode(response.data['data']));

      return user;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyEmailCode,
        data: {
          'email': email,
          'code': code,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Email verified successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> resendEmailCode({
    required String email,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.resendEmailCode,
        data: {
          'email': email,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Verification code sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<bool> isLoggedIn() async {
    return await _storage.hasToken();
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _apiClient.post(
        '/auth/fcm-token',
        data: {'fcm_token': fcmToken},
      );
    } catch (e) {
      // Silently fail - FCM token update is not critical
    }
  }

  // Save updated user data to local storage
  Future<void> saveUserToStorage(User user) async {
    try {
      await _storage.saveUserData(jsonEncode(user.toJson()));
    } catch (e) {
      // Silently fail - non-critical
    }
  }
}