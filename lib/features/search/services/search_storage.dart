import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SearchStorage {
  static const _storage = FlutterSecureStorage();
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxSearches = 15;
  static const int _expirationDays = 30;

  /// Add a search query to recent searches
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    final searches = await getRecentSearches();
    final now = DateTime.now();

    // Remove if already exists (to move to top)
    searches.removeWhere((item) => item['query'] == query);

    // Add to beginning
    searches.insert(0, {
      'query': query,
      'timestamp': now.toIso8601String(),
    });

    // Keep only the last N searches
    if (searches.length > _maxSearches) {
      searches.removeRange(_maxSearches, searches.length);
    }

    await _storage.write(key: _recentSearchesKey, value: jsonEncode(searches));
  }

  /// Get recent searches (non-expired)
  Future<List<Map<String, dynamic>>> getRecentSearches() async {
    try {
      final data = await _storage.read(key: _recentSearchesKey);
      if (data == null) return [];

      final List<dynamic> searches = jsonDecode(data);
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: _expirationDays));

      // Filter out expired searches
      final validSearches = searches
          .cast<Map<String, dynamic>>()
          .where((item) {
            final timestamp = DateTime.parse(item['timestamp']);
            return timestamp.isAfter(cutoff);
          })
          .toList();

      // Save cleaned list back (auto-cleanup)
      if (validSearches.length != searches.length) {
        await _storage.write(key: _recentSearchesKey, value: jsonEncode(validSearches));
      }

      return validSearches;
    } catch (e) {
      print('[SearchStorage] Error loading recent searches: $e');
      return [];
    }
  }

  /// Get recent search queries as strings
  Future<List<String>> getRecentSearchQueries() async {
    final searches = await getRecentSearches();
    return searches.map((item) => item['query'] as String).toList();
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    await _storage.delete(key: _recentSearchesKey);
  }

  /// Check if we have any recent searches
  Future<bool> hasRecentSearches() async {
    final searches = await getRecentSearches();
    return searches.isNotEmpty;
  }
}