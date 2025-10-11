import '../../../core/api/api_client.dart';
import '../models/constitution_chapter.dart';
import '../models/constitution_article.dart';
import '../models/constitution_search_result.dart';
import '../models/constitution_daily.dart';
import '../database/constitution_database.dart';

/// Cache-first constitution service for optimal performance
/// Strategy: Memory → SQLite → Network (only if needed)
class ConstitutionService {
  final ApiClient _apiClient = ApiClient();
  final ConstitutionDatabase _cache = ConstitutionDatabase.instance;

  /// Get all chapters with article counts
  /// Cache strategy: Memory → SQLite → Network
  Future<List<ConstitutionChapter>> getChapters() async {
    try {
      // Check cache validity first - clear if outdated
      final isCacheValid = await _cache.isCacheValid();
      if (!isCacheValid) {
        await _cache.clearCache();
      }

      // Try cache first
      final cached = await _cache.getChapters();
      if (cached != null) {
        return cached;
      }

      // Cache miss - fetch from network
      final response = await _apiClient.get('/constitution/chapters');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final chapters = data.map((json) => ConstitutionChapter.fromJson(json as Map<String, dynamic>)).toList();

      // Save to cache for next time
      await _cache.saveChapters(chapters);
      await _cache.markCacheValid();

      return chapters;
    } catch (e) {
      throw Exception('Failed to load chapters: ${e.toString()}');
    }
  }

  /// Get single article by ID with full content
  /// Cache strategy: Memory → SQLite → Network
  Future<ConstitutionArticle> getArticle(String articleId) async {
    try {
      // Try cache first
      final cached = await _cache.getArticle(articleId);
      if (cached != null) {
        return cached;
      }

      // Cache miss - fetch from network
      final response = await _apiClient.get('/constitution/articles/$articleId');
      final data = response.data['data'] as Map<String, dynamic>;

      // Pass entire response to model (includes article, chapter, part)
      final article = ConstitutionArticle.fromJson(data);

      // Extract chapter ID for cache storage
      final chapterId = data['chapter']?['id']?.toString() ?? 'unknown';

      // Save to cache for next time
      await _cache.saveArticle(article, chapterId);

      return article;
    } catch (e) {
      throw Exception('Failed to load article: ${e.toString()}');
    }
  }

  /// Get all articles for a specific chapter
  /// Cache strategy: Memory → SQLite → Network
  Future<List<ConstitutionArticle>> getChapterArticles(String chapterId) async {
    try {
      // Try cache first
      final cached = await _cache.getChapterArticles(chapterId);
      if (cached != null) {
        return cached;
      }

      // Cache miss - fetch from network
      final response = await _apiClient.get('/constitution/chapters/$chapterId/articles');
      final data = response.data['data'] as Map<String, dynamic>;
      final List<dynamic> articlesData = data['articles'] as List<dynamic>;
      final articles = articlesData.map((json) => ConstitutionArticle.fromJson(json as Map<String, dynamic>)).toList();

      // Save to cache for next time (batch save for efficiency)
      await _cache.saveChapterArticles(chapterId, articles);

      return articles;
    } catch (e) {
      throw Exception('Failed to load chapter articles: ${e.toString()}');
    }
  }

  /// Get daily article with AI-generated insight
  Future<ConstitutionDaily> getDailyArticle() async {
    try {
      final response = await _apiClient.get('/constitution/daily-article');
      return ConstitutionDaily.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load daily article: ${e.toString()}');
    }
  }

  /// Search articles by query
  Future<List<ConstitutionSearchResult>> search(String query) async {
    try {
      final response = await _apiClient.get(
        '/constitution/search',
        queryParameters: {'q': query},  // Backend expects 'q' not 'query'
      );
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data.map((json) => ConstitutionSearchResult.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to search articles: ${e.toString()}');
    }
  }

  /// Ask AI to explain an article
  Future<String> askAI(String articleId, String question) async {
    try {
      final response = await _apiClient.post(
        '/constitution/articles/$articleId/ai-explain',
        data: {'question': question},
      );
      return response.data['data']['explanation'] as String;
    } catch (e) {
      throw Exception('Failed to get AI explanation: ${e.toString()}');
    }
  }

  /// Initialize cache - call this on app start
  /// Checks if cache is valid for current app version
  Future<void> initializeCache() async {
    final isValid = await _cache.isCacheValid();

    if (!isValid) {
      await _cache.clearCache();
    }
  }

  /// Clear all cached data (for settings/debug)
  Future<void> clearAllCache() async {
    await _cache.clearCache();
  }
}
