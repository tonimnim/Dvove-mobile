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

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated && _user != null;
  bool get isOfficial => _user?.isOfficial ?? false;
  bool get canCreatePosts => _user?.canCreatePosts ?? false;
  String get displayName => _user?.displayName ?? '';

  Future<void> initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _authService.getCurrentUser(forceRefresh: false);
        _isAuthenticated = _user != null;
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize auth';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading immediately

    try {
      final result = await _authService.login(
        login: login,
        password: password,
      );

      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = true;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Single notification at the end
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required int countyId,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
        countyId: countyId,
      );

      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = false;
        _errorMessage = null;
        return true;
      } else {
        if (result.containsKey('errors') && result['errors'] != null) {
          final errors = result['errors'] as Map<String, dynamic>;
          final errorMessages = <String>[];

          errors.forEach((field, messages) {
            if (messages is List) {
              for (String message in messages.cast<String>()) {
                String friendlyMessage = _makeFriendlyErrorMessage(field, message);
                errorMessages.add(friendlyMessage);
              }
            }
          });

          _errorMessage = errorMessages.join('\n');
        } else {
          _errorMessage = result['message'] ?? 'Registration failed';
        }
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during registration';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Single notification at the end
    }
  }

  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    try {
      final result = await _authService.verifyEmailCode(
        email: email,
        code: code,
      );

      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = true;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Email verification failed';
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during email verification';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Single notification at the end
    }
  }

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

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
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

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      final result = await _authService.deleteAccount();

      if (result['success']) {
        IntelligentCacheService.instance.clearCache();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        _user = null;
        _isAuthenticated = false;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to delete account';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Single notification at the end
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _authService.updateFcmToken(fcmToken);
  }

  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    await _authService.saveUserToStorage(updatedUser);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (!_isAuthenticated) return;

    try {
      final user = await _authService.getCurrentUser(forceRefresh: true);
      if (user != null) {
        _user = user;
        notifyListeners();
      }
    } catch (e) {
      // Silent fail - subscription status will be updated on next app open
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _makeFriendlyErrorMessage(String field, String message) {
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

    if (field == 'username' && message.contains('already been taken')) {
      return 'This username is already taken. Please choose a different username.';
    }

    if (field == 'email' && message.contains('already been taken')) {
      return 'This email address is already registered. Please use a different email or try logging in.';
    }

    if (field == 'password' && message.contains('confirmation')) {
      return 'Passwords do not match. Please make sure both password fields are identical.';
    }

    return friendlyMessage;
  }
}