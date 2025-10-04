class ConstitutionSearchResult {
  final int id;
  final String rawId;
  final String articleNumber;
  final String title;
  final String snippet;
  final String chapterTitle;
  final String? partTitle;

  ConstitutionSearchResult({
    required this.id,
    required this.rawId,
    required this.articleNumber,
    required this.title,
    required this.snippet,
    required this.chapterTitle,
    this.partTitle,
  });

  factory ConstitutionSearchResult.fromJson(Map<String, dynamic> json) {
    // Handle nested article object
    Map<String, dynamic> articleData;
    String chapterTitle = '';
    String? partTitle;

    if (json.containsKey('article')) {
      articleData = json['article'] as Map<String, dynamic>;

      // Extract chapter title from nested chapter object
      if (json.containsKey('chapter')) {
        final chapter = json['chapter'] as Map<String, dynamic>;
        chapterTitle = chapter['title'] as String? ?? '';
      }

      // Extract part title if exists
      if (json.containsKey('part') && json['part'] != null) {
        final part = json['part'] as Map<String, dynamic>;
        partTitle = part['title'] as String?;
      }
    } else {
      articleData = json;
      chapterTitle = json['chapter_title'] as String? ?? '';
      partTitle = json['part_title'] as String?;
    }

    final rawId = articleData['id'].toString();

    // Parse numeric ID from string like "art_126" or "ch_1_art_1"
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) {
        final cleanValue = value.replaceFirst(RegExp(r'^(ch_\d+_)?art_'), '');
        return int.parse(cleanValue);
      }
      return 0;
    }

    return ConstitutionSearchResult(
      id: parseId(articleData['id']),
      rawId: rawId,
      articleNumber: articleData['number'].toString(),
      title: articleData['title'] as String,
      snippet: articleData['snippet'] as String,
      chapterTitle: chapterTitle,
      partTitle: partTitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'article_number': articleNumber,
      'title': title,
      'snippet': snippet,
      'chapter_title': chapterTitle,
    };
  }
}
