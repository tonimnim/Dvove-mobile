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

      final data = response.data['data'];
      final message = response.data['message'];

      return {
        'success': true,
        'message': message,
        'email_verification_required': data['email_verification_required'],
        'email': data['email'],
        'expires_in': data['expires_in'],
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final responseData = e.response?.data;

        final errors = responseData?['errors'];

        if (errors != null && errors is Map<String, dynamic>) {
          String finalMessage = '';

          bool hasUsernameError = errors.containsKey('username') && errors['username'] is List && errors['username'].isNotEmpty;
          bool hasEmailError = errors.containsKey('email') && errors['email'] is List && errors['email'].isNotEmpty;

          if (hasUsernameError && hasEmailError) {
            finalMessage = 'Both this username and email are already taken. Please choose different credentials.';
          } else if (hasUsernameError) {
            String message = errors['username'].first.toString();
            if (message.contains('already been taken')) {
              finalMessage = 'This username is already taken. Please choose a different username.';
            } else {
              finalMessage = message;
            }
          } else if (hasEmailError) {
            String message = errors['email'].first.toString();
            if (message.contains('already been taken')) {
              finalMessage = 'This email address is already registered. Please use a different email or try logging in.';
            } else {
              finalMessage = message;
            }
          } else {
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
    required String login,
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
      await _storage.clearAll();
      return {
        'success': true,
        'message': 'Logged out locally',
      };
    }
  }

  Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cachedUserData = await _storage.getUserData();
        if (cachedUserData != null) {
          return User.fromJson(jsonDecode(cachedUserData));
        }
      }

      final response = await _apiClient.get(ApiEndpoints.user);
      final user = User.fromJson(response.data['data']);

      await _storage.saveUserData(jsonEncode(response.data['data']));

      return user;
    } catch (e) {
      final cachedUserData = await _storage.getUserData();
      if (cachedUserData != null) {
        return User.fromJson(jsonDecode(cachedUserData));
      }
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
    }
  }

  Future<void> saveUserToStorage(User user) async {
    try {
      await _storage.saveUserData(jsonEncode(user.toJson()));
    } catch (e) {
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      await _apiClient.delete('/auth/account');
      await _storage.clearAll();

      return {
        'success': true,
        'message': 'Account deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Password changed successfully',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map<String, dynamic>) {
          final firstField = errors.keys.first;
          final firstMessages = errors[firstField];
          if (firstMessages is List && firstMessages.isNotEmpty) {
            return {
              'success': false,
              'message': firstMessages.first.toString(),
            };
          }
        }
      }

      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed to change password',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final response = await _apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Password reset code sent to your email',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map<String, dynamic>) {
          final firstField = errors.keys.first;
          final firstMessages = errors[firstField];
          if (firstMessages is List && firstMessages.isNotEmpty) {
            return {
              'success': false,
              'message': firstMessages.first.toString(),
            };
          }
        }
      }

      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed to send reset code',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/reset-password',
        data: {
          'email': email,
          'code': code,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Password reset successfully',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map<String, dynamic>) {
          final firstField = errors.keys.first;
          final firstMessages = errors[firstField];
          if (firstMessages is List && firstMessages.isNotEmpty) {
            return {
              'success': false,
              'message': firstMessages.first.toString(),
            };
          }
        }
      }

      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed to reset password',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}