class ConstitutionChapter {
  final int id;
  final String rawId;  // Keep the original ID like "ch_1"
  final String chapterNumber;
  final String title;
  final int articleCount;
  final bool hasParts;

  ConstitutionChapter({
    required this.id,
    required this.rawId,
    required this.chapterNumber,
    required this.title,
    required this.articleCount,
    this.hasParts = false,
  });

  factory ConstitutionChapter.fromJson(Map<String, dynamic> json) {
    // Handle ID with "ch_" prefix
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) {
        // Remove "ch_" prefix if present
        final cleanValue = value.replaceFirst('ch_', '');
        // Try to parse as int, if it fails, hash the string to get a number
        try {
          return int.parse(cleanValue);
        } catch (e) {
          // For chapter IDs like "ch_ONE", use hashCode
          return cleanValue.hashCode.abs() % 1000000;
        }
      }
      throw FormatException('Invalid ID format: $value');
    }

    // Handle chapter_number or number field - convert to string if needed
    String chapterNumber;
    if (json.containsKey('chapter_number')) {
      chapterNumber = json['chapter_number'].toString();
    } else {
      chapterNumber = json['number'].toString();
    }

    final rawId = json['id'].toString();

    return ConstitutionChapter(
      id: parseId(json['id']),
      rawId: rawId,
      chapterNumber: chapterNumber,
      title: json['title'] as String,
      articleCount: json['article_count'] is String ? int.parse(json['article_count']) : json['article_count'] as int,
      hasParts: json['has_parts'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_number': chapterNumber,
      'title': title,
      'article_count': articleCount,
    };
  }
}
