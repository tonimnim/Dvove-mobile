import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/constitution_chapter.dart';
import '../models/constitution_article.dart';

/// High-performance constitution cache with version-based invalidation
/// CTO Strategy: Cache forever, only refresh on app version change
class ConstitutionDatabase {
  static final ConstitutionDatabase instance = ConstitutionDatabase._init();
  static Database? _database;

  // Memory cache for ultra-fast access
  static List<ConstitutionChapter>? _chaptersCache;
  static Map<String, ConstitutionArticle> _articlesCache = {};
  static Map<String, List<ConstitutionArticle>> _chapterArticlesCache = {};

  ConstitutionDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('constitution.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Chapters table
    await db.execute('''
      CREATE TABLE chapters(
        id TEXT PRIMARY KEY,
        raw_id TEXT NOT NULL,
        number TEXT NOT NULL,
        number_text TEXT,
        title TEXT NOT NULL,
        article_count INTEGER NOT NULL,
        has_parts INTEGER DEFAULT 0,
        cached_at TEXT
      )
    ''');

    // Articles table with full JSON for clauses
    await db.execute('''
      CREATE TABLE articles(
        id TEXT PRIMARY KEY,
        raw_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        article_number TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        chapter_title TEXT,
        part_title TEXT,
        clauses_json TEXT,
        cached_at TEXT
      )
    ''');

    // Index for fast chapter article lookups
    await db.execute('''
      CREATE INDEX idx_articles_chapter ON articles(chapter_id)
    ''');
  }

  /// Check if cache is valid for current app version
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedVersion = prefs.getString('constitution_cache_version');
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    return cachedVersion == currentVersion;
  }

  /// Mark cache as valid for current app version
  Future<void> markCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    await prefs.setString('constitution_cache_version', packageInfo.version);
  }

  /// Clear all caches (memory + disk)
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('chapters');
    await db.delete('articles');

    _chaptersCache = null;
    _articlesCache.clear();
    _chapterArticlesCache.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('constitution_cache_version');
  }

  /// Get chapters with multi-level caching
  /// Level 1: Memory → Level 2: SQLite → Level 3: Network
  Future<List<ConstitutionChapter>?> getChapters() async {
    // Level 1: Memory cache (instant)
    if (_chaptersCache != null) {
      return _chaptersCache;
    }

    // Level 2: Disk cache
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('chapters');

    if (maps.isNotEmpty) {
      _chaptersCache = maps.map((map) => ConstitutionChapter(
        id: int.parse(map['id']),
        rawId: map['raw_id'],
        chapterNumber: map['number'],
        title: map['title'],
        articleCount: map['article_count'],
        hasParts: map['has_parts'] == 1,
      )).toList();
      return _chaptersCache;
    }

    return null; // Cache miss - need network fetch
  }

  /// Save chapters to cache
  Future<void> saveChapters(List<ConstitutionChapter> chapters) async {
    final db = await database;
    final batch = db.batch();

    for (final chapter in chapters) {
      batch.insert(
        'chapters',
        {
          'id': chapter.id.toString(),
          'raw_id': chapter.rawId,
          'number': chapter.chapterNumber,
          'number_text': '', // Not critical, can be omitted
          'title': chapter.title,
          'article_count': chapter.articleCount,
          'has_parts': chapter.hasParts ? 1 : 0,
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _chaptersCache = chapters; // Update memory cache
  }

  /// Get single article with caching
  Future<ConstitutionArticle?> getArticle(String articleId) async {
    // Level 1: Memory cache
    if (_articlesCache.containsKey(articleId)) {
      return _articlesCache[articleId];
    }

    // Level 2: Disk cache
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'articles',
      where: 'raw_id = ?',
      whereArgs: [articleId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final article = _mapToArticle(maps[0]);
      _articlesCache[articleId] = article; // Update memory cache
      return article;
    }

    return null; // Cache miss
  }

  /// Get all articles for a chapter
  Future<List<ConstitutionArticle>?> getChapterArticles(String chapterId) async {
    // Level 1: Memory cache
    if (_chapterArticlesCache.containsKey(chapterId)) {
      return _chapterArticlesCache[chapterId];
    }

    // Level 2: Disk cache
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'articles',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );

    if (maps.isNotEmpty) {
      final articles = maps.map((map) => _mapToArticle(map)).toList();
      _chapterArticlesCache[chapterId] = articles; // Update memory cache
      return articles;
    }

    return null; // Cache miss
  }

  /// Save article to cache
  Future<void> saveArticle(ConstitutionArticle article, String chapterId) async {
    final db = await database;

    await db.insert(
      'articles',
      {
        'id': article.id.toString(),
        'raw_id': article.rawId,
        'chapter_id': chapterId,
        'article_number': article.articleNumber,
        'title': article.title,
        'content': article.content,
        'chapter_title': article.chapterTitle,
        'part_title': article.partTitle,
        'clauses_json': _clausesToJson(article.clauses),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _articlesCache[article.rawId] = article; // Update memory cache
  }

  /// Save chapter articles in batch
  Future<void> saveChapterArticles(String chapterId, List<ConstitutionArticle> articles) async {
    final db = await database;
    final batch = db.batch();

    for (final article in articles) {
      batch.insert(
        'articles',
        {
          'id': article.id.toString(),
          'raw_id': article.rawId,
          'chapter_id': chapterId,
          'article_number': article.articleNumber,
          'title': article.title,
          'content': article.content,
          'chapter_title': article.chapterTitle,
          'part_title': article.partTitle,
          'clauses_json': _clausesToJson(article.clauses),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _chapterArticlesCache[chapterId] = articles; // Update memory cache

    // Also update individual article cache
    for (final article in articles) {
      _articlesCache[article.rawId] = article;
    }
  }

  /// Convert article map to object
  ConstitutionArticle _mapToArticle(Map<String, dynamic> map) {
    return ConstitutionArticle(
      id: int.parse(map['id']),
      rawId: map['raw_id'],
      chapterId: 0, // Not needed from cache
      articleNumber: map['article_number'],
      title: map['title'],
      content: map['content'],
      chapterTitle: map['chapter_title'],
      partTitle: map['part_title'],
      clauses: _jsonToClauses(map['clauses_json']),
    );
  }

  /// Serialize clauses to JSON string
  String _clausesToJson(List<dynamic> clauses) {
    if (clauses.isEmpty) return '[]';

    // Convert clauses to JSON - clauses are ArticleClause objects
    // We need to serialize them properly
    try {
      final clausesJson = clauses.map((clause) {
        if (clause is ArticleClause) {
          return _clauseToMap(clause);
        }
        return clause;
      }).toList();

      // Use dart:convert to serialize
      return jsonEncode(clausesJson);
    } catch (e) {
      return '[]';
    }
  }

  Map<String, dynamic> _clauseToMap(ArticleClause clause) {
    return {
      if (clause.clauseNumber != null) 'clause_number': clause.clauseNumber,
      if (clause.identifier != null) 'identifier': clause.identifier,
      'content': clause.content,
      if (clause.children.isNotEmpty) 'children': clause.children.map(_clauseToMap).toList(),
    };
  }

  /// Deserialize clauses from JSON string
  List<ArticleClause> _jsonToClauses(String? json) {
    if (json == null || json == '[]') return [];

    try {
      final List<dynamic> clausesData = jsonDecode(json);
      return clausesData.map((data) => ArticleClause.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
