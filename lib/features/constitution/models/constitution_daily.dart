import 'constitution_article.dart';

class ConstitutionDaily {
  final ConstitutionArticle article;
  final String insight;
  final String? chapterTitle;

  ConstitutionDaily({
    required this.article,
    required this.insight,
    this.chapterTitle,
  });

  factory ConstitutionDaily.fromJson(Map<String, dynamic> json) {
    // Pass full response to article model (includes article, chapter, part, clauses)
    final article = ConstitutionArticle.fromJson(json);

    // Extract chapter title
    String? chapterTitle;
    if (json.containsKey('chapter')) {
      final chapter = json['chapter'] as Map<String, dynamic>;
      chapterTitle = chapter['title'] as String?;
    }

    return ConstitutionDaily(
      article: article,
      insight: json['insight'] as String? ?? '',
      chapterTitle: chapterTitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'article': article.toJson(),
      'insight': insight,
    };
  }
}
