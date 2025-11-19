import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hybrid secure storage with SharedPreferences fallback
/// Fixes auto-logout on Samsung A21, Redmi, and other devices with aggressive battery optimization
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true, // Auto-reset if corrupted
    ),
  );

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Token operations with fallback
  Future<void> saveToken(String token) async {
    // Try to save to secure storage
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      // Silent fail - SharedPreferences backup will work
      print('SecureStorage: Failed to save token to secure storage: $e');
    }

    // ALWAYS save to SharedPreferences as backup (for problematic devices)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('SecureStorage: Failed to save token to SharedPreferences: $e');
    }
  }

  Future<String?> getToken() async {
    // Try secure storage first (more secure)
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (e) {
      print('SecureStorage: Failed to read token from secure storage: $e');
    }

    // Fallback to SharedPreferences (handles Samsung/Redmi issues)
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('SecureStorage: Failed to read token from SharedPreferences: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    // Delete from both storages
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      print('SecureStorage: Failed to delete token from secure storage: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      print('SecureStorage: Failed to delete token from SharedPreferences: $e');
    }
  }

  // User data operations with fallback
  Future<void> saveUserData(String userData) async {
    // Try to save to secure storage
    try {
      await _storage.write(key: _userKey, value: userData);
    } catch (e) {
      print('SecureStorage: Failed to save user data to secure storage: $e');
    }

    // ALWAYS save to SharedPreferences as backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, userData);
    } catch (e) {
      print('SecureStorage: Failed to save user data to SharedPreferences: $e');
    }
  }

  Future<String?> getUserData() async {
    // Try secure storage first
    try {
      final userData = await _storage.read(key: _userKey);
      if (userData != null && userData.isNotEmpty) {
        return userData;
      }
    } catch (e) {
      print('SecureStorage: Failed to read user data from secure storage: $e');
    }

    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userKey);
    } catch (e) {
      print('SecureStorage: Failed to read user data from SharedPreferences: $e');
      return null;
    }
  }

  Future<void> deleteUserData() async {
    // Delete from both storages
    try {
      await _storage.delete(key: _userKey);
    } catch (e) {
      print('SecureStorage: Failed to delete user data from secure storage: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (e) {
      print('SecureStorage: Failed to delete user data from SharedPreferences: $e');
    }
  }

  // Clear everything
  Future<void> clearAll() async {
    // Clear both storages
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('SecureStorage: Failed to clear secure storage: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      print('SecureStorage: Failed to clear SharedPreferences: $e');
    }
  }

  // Simple token check - this is all splash needs!
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}