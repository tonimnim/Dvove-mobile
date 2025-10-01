import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../../../core/services/intelligent_cache_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated && _user != null;
  bool get isOfficial => _user?.isOfficial ?? false;
  bool get canCreatePosts => _user?.canCreatePosts ?? false;
  String get displayName => _user?.displayName ?? '';

  // Initialize auth state (check if user is already logged in)
  Future<void> initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        // Force refresh user data from server to get latest profile photo
        _user = await _authService.getCurrentUser(forceRefresh: true);
        _isAuthenticated = _user != null;
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize auth';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login({
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        login: login,
        password: password,
      );

      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = true;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during login';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required int countyId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
        countyId: countyId,
      );

      print('[AuthProvider] Register result: $result');

      if (result['success']) {
        // Don't set as authenticated yet - user needs to verify email first
        _user = result['user'];
        _isAuthenticated = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        // Prioritize specific validation errors over generic messages
        if (result.containsKey('errors') && result['errors'] != null) {
          final errors = result['errors'] as Map<String, dynamic>;
          final errorMessages = <String>[];

          errors.forEach((field, messages) {
            if (messages is List) {
              for (String message in messages.cast<String>()) {
                // Make error messages more user-friendly
                String friendlyMessage = _makeFriendlyErrorMessage(field, message);
                errorMessages.add(friendlyMessage);
              }
            }
          });

          _errorMessage = errorMessages.join('\n');
        } else {
          _errorMessage = result['message'] ?? 'Registration failed';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during registration';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify Email Code
  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyEmailCode(
        email: email,
        code: code,
      );

      if (result['success']) {
        // Email verified, user can now login
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Email verification failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during email verification';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Resend Email Code
  Future<bool> resendEmailCode(String email) async {
    try {
      final result = await _authService.resendEmailCode(email: email);
      if (!result['success']) {
        _errorMessage = result['message'];
        notifyListeners();
      }
      return result['success'];
    } catch (e) {
      _errorMessage = 'Failed to resend verification code';
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear all caches
      await _authService.logout();
      IntelligentCacheService.instance.clearCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } finally {
      _user = null;
      _isAuthenticated = false;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update FCM token
  Future<void> updateFcmToken(String fcmToken) async {
    await _authService.updateFcmToken(fcmToken);
  }

  // Update user (for profile updates)
  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    // Update local storage cache to persist across app restarts
    await _authService.saveUserToStorage(updatedUser);
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helper method to create user-friendly error messages
  String _makeFriendlyErrorMessage(String field, String message) {
    // Map common validation messages to user-friendly ones
    final Map<String, String> fieldNames = {
      'username': 'Username',
      'email': 'Email address',
      'password': 'Password',
      'county_id': 'County',
    };

    final Map<String, String> commonMessages = {
      'has already been taken': 'is already in use. Please try a different one.',
      'is required': 'is required.',
      'must be at least': 'must be at least',
      'is invalid': 'is not valid.',
      'does not match': 'does not match.',
      'is too short': 'is too short.',
      'is too long': 'is too long.',
    };

    String friendlyFieldName = fieldNames[field] ?? field.replaceAll('_', ' ');
    String friendlyMessage = message;

    // Replace common patterns with friendlier versions
    commonMessages.forEach((pattern, replacement) {
      if (message.toLowerCase().contains(pattern.toLowerCase())) {
        if (pattern == 'has already been taken') {
          friendlyMessage = '$friendlyFieldName $replacement';
        } else if (pattern == 'is required') {
          friendlyMessage = '$friendlyFieldName $replacement';
        } else {
          friendlyMessage = message.replaceAll(pattern, replacement);
        }
      }
    });

    // Handle specific cases
    if (field == 'username' && message.contains('already been taken')) {
      return 'This username is already taken. Please choose a different username.';
    }

    if (field == 'email' && message.contains('already been taken')) {
      return 'This email address is already registered. Please use a different email or try logging in.';
    }

    if (field == 'password' && message.contains('confirmation')) {
      return 'Passwords do not match. Please make sure both password fields are identical.';
    }

    // If no specific friendly message found, return the original with field name
    return friendlyMessage;
  }
}