import 'package:flutter/material.dart';
import 'formatted_text.dart';
import '../models/post.dart';

class PostContent extends StatelessWidget {
  final String? content;
  final String type;
  final String? priority;
  final Post? post; // For navigation to detail page

  const PostContent({
    super.key,
    this.content,
    required this.type,
    this.priority,
    this.post,
  });

  @override
  Widget build(BuildContext context) {
    if (content == null || content!.isEmpty) return const SizedBox.shrink();

    // Content text with enhanced formatting
    return FormattedText(
      text: content!,
      post: post,
    );
  }
}