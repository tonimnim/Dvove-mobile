class ArticleClause {
  final String? clauseNumber;
  final String? identifier;
  final String content;
  final List<ArticleClause> children;

  ArticleClause({
    this.clauseNumber,
    this.identifier,
    required this.content,
    this.children = const [],
  });

  factory ArticleClause.fromJson(Map<String, dynamic> json) {
    return ArticleClause(
      clauseNumber: json['clause_number'] as String?,
      identifier: json['identifier'] as String?,
      content: json['content'] as String,
      children: (json['children'] as List?)
          ?.map((child) => ArticleClause.fromJson(child))
          .toList() ?? [],
    );
  }
}

class ConstitutionArticle {
  final int id;
  final String rawId;  // Original API ID like "art_126" or "ch_1_art_1"
  final int chapterId;
  final String articleNumber;
  final String title;
  final String content;
  final String? chapterTitle;
  final String? partTitle;
  final List<ArticleClause> clauses;

  ConstitutionArticle({
    required this.id,
    required this.rawId,
    required this.chapterId,
    required this.articleNumber,
    required this.title,
    required this.content,
    this.chapterTitle,
    this.partTitle,
    this.clauses = const [],
  });

  factory ConstitutionArticle.fromJson(Map<String, dynamic> json) {
    // Handle both API formats: direct article and nested in chapter
    final articleData = json.containsKey('article') ? json['article'] : json;
    final articleNumber = articleData['number'].toString();

    // Extract ID - handle "art_126" or "ch_1_art_1" format
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) {
        // Remove "art_" or "ch_X_art_" prefix if present
        final cleanValue = value.replaceFirst(RegExp(r'^(ch_\d+_)?art_'), '');
        return int.parse(cleanValue);
      }
      throw FormatException('Invalid ID format: $value');
    }

    // Extract chapter_id
    int parseChapterId(Map<String, dynamic> json) {
      if (json.containsKey('chapter')) {
        final chapter = json['chapter'];
        if (chapter is Map) {
          final chapterNum = chapter['number'];
          return chapterNum is String ? int.parse(chapterNum) : chapterNum as int;
        }
      }
      if (json.containsKey('chapter_id')) {
        final value = json['chapter_id'];
        return value is String ? int.parse(value) : value as int;
      }
      return 0;
    }

    final rawId = articleData['id'].toString();

    // Parse clauses
    final clausesList = articleData['clauses'] as List?;
    final clauses = clausesList?.map((c) => ArticleClause.fromJson(c)).toList() ?? [];

    // Extract part title
    String? partTitle;
    if (json.containsKey('part') && json['part'] != null) {
      final part = json['part'] as Map<String, dynamic>;
      partTitle = part['title'] as String?;
    }

    // Extract chapter title
    String? chapterTitle;
    if (json.containsKey('chapter')) {
      final chapter = json['chapter'] as Map<String, dynamic>;
      chapterTitle = chapter['title'] as String?;
    } else if (articleData.containsKey('chapter_title')) {
      chapterTitle = articleData['chapter_title'] as String?;
    }

    return ConstitutionArticle(
      id: parseId(articleData['id']),
      rawId: rawId,
      chapterId: parseChapterId(json),
      articleNumber: articleNumber,
      title: articleData['title'] as String,
      content: articleData['content'] as String,
      chapterTitle: chapterTitle,
      partTitle: partTitle,
      clauses: clauses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': rawId,  // Use rawId for API calls
      'chapter_id': chapterId,
      'article_number': articleNumber,
      'title': title,
      'content': content,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
    };
  }
}
