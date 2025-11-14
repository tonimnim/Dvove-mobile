import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dead simple secure storage - no caching, no complexity
class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Token operations
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // User data operations
  Future<void> saveUserData(String userData) async {
    await _storage.write(key: _userKey, value: userData);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: _userKey);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: _userKey);
  }

  // Clear everything
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Simple token check - this is all splash needs!
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}