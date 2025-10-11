import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../auth/models/user.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get current user profile from API
  /// Calls GET /api/v1/auth/user
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/user');

      if (response.data['success'] == true) {
        final userData = response.data['data'];

        return User.fromJson(userData);
      } else {
        throw Exception('Failed to get user profile: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      throw Exception('Failed to load profile: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  /// Upload profile photo and return photo URL
  /// Calls POST /api/v1/auth/upload-profile-photo with FormData
  Future<User> uploadProfilePhoto(String imagePath) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'profile_photo',
        await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      ));

      final response = await _apiClient.dio.post(
        '/auth/upload-profile-photo',
        data: formData,
      );

      if (response.data['success'] == true) {
        // Now get the updated user profile
        return await getCurrentUser();
      } else {
        throw Exception('Failed to upload photo: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        throw Exception('File too large. Please choose a smaller image.');
      } else if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors['profile_photo'] != null) {
          throw Exception('Invalid image format. Please use JPG, PNG, or WebP.');
        }
      }

      throw Exception('Failed to upload photo: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Update user profile (for future phases)
  /// Calls PUT /api/v1/auth/user
  Future<User> updateProfile({
    String? username,
    String? profilePhoto,
    String? officialName,
    String? officeAddress,
  }) async {
    try {
      final requestData = <String, dynamic>{};
      if (username != null) requestData['username'] = username;
      if (profilePhoto != null) requestData['profile_photo'] = profilePhoto;
      if (officialName != null) requestData['official_name'] = officialName;
      if (officeAddress != null) requestData['office_address'] = officeAddress;

      final response = await _apiClient.dio.put('/auth/user', data: requestData);

      if (response.data['success'] == true) {
        final userData = response.data['data'];

        return User.fromJson(userData);
      } else {
        throw Exception('Failed to update profile: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        // Validation errors
        final errors = e.response?.data['errors'];
        if (errors != null && errors['username'] != null) {
          throw Exception('Username already taken');
        }
        throw Exception('Validation failed');
      }

      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
