import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../screens/post_detail_screen.dart';

class FormattedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final Post? post; // For navigation
  final bool showFullContent; // Show full content without truncation

  const FormattedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 10,
    this.overflow = TextOverflow.ellipsis,
    this.post,
    this.showFullContent = false,
  });

  @override
  State<FormattedText> createState() => _FormattedTextState();
}

class _FormattedTextState extends State<FormattedText> {
  bool _isExpanded = false;
  static const int _collapsedMaxLines = 4;
  static const int _maxCollapsedLength = 280;

  @override
  Widget build(BuildContext context) {
    final needsExpansion = widget.text.length > _maxCollapsedLength && !widget.showFullContent;
    final displayText = !_isExpanded && needsExpansion
        ? widget.text.substring(0, _maxCollapsedLength)
        : widget.text;

    // Adjust text size based on content length
    double fontSize = 15;
    if (widget.text.length < 50) {
      fontSize = 18;
    } else if (widget.text.length < 150) {
      fontSize = 16;
    }

    final baseStyle = widget.style ?? TextStyle(
      fontSize: fontSize,
      height: 1.3,
      color: Colors.black87,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: baseStyle,
            children: _buildTextSpans(displayText, baseStyle),
          ),
          maxLines: widget.showFullContent || _isExpanded ? null : _collapsedMaxLines,
          overflow: widget.showFullContent || _isExpanded ? TextOverflow.visible : widget.overflow,
        ),
        if (needsExpansion)
          GestureDetector(
            onTap: () {
              if (!_isExpanded && widget.post != null) {
                // Navigate to post detail page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: widget.post!),
                  ),
                );
              } else {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'Show less' : '... Read more',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<TextSpan> _buildTextSpans(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];

    // Regular expressions for different patterns
    final patterns = {
      'mention': RegExp(r'@\w+'),
      'hashtag': RegExp(r'#\w+'),
      'url': RegExp(r'https?://[^\s]+'),
      'phone': RegExp(r'\+254\d{9}'),
    };

    int currentIndex = 0;
    final matches = <_Match>[];

    // Find all matches
    patterns.forEach((type, pattern) {
      for (final match in pattern.allMatches(text)) {
        matches.add(_Match(
          type: type,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
        ));
      }
    });

    // Sort matches by position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Build spans
    for (final match in matches) {
      // Add normal text before match
      if (currentIndex < match.start) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }

      // Add formatted match
      TextStyle matchStyle;
      Function()? onTap;

      switch (match.type) {
        case 'mention':
        case 'hashtag':
          matchStyle = baseStyle.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          );
          onTap = () {
            // TODO: Handle mention/hashtag tap
          };
          break;
        case 'url':
          matchStyle = baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          );
          onTap = () async {
            final uri = Uri.parse(match.text);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          };
          break;
        case 'phone':
          matchStyle = baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          );
          onTap = () async {
            final phoneNumber = match.text.replaceAll(RegExp(r'[^\d+]'), '');
            final Uri phoneUri = Uri.parse('tel:$phoneNumber');
            if (await canLaunchUrl(phoneUri)) {
              await launchUrl(phoneUri);
            }
          };
          break;
        default:
          matchStyle = baseStyle;
      }

      spans.add(TextSpan(
        text: match.text,
        style: matchStyle,
        recognizer: onTap != null ? (TapGestureRecognizer()..onTap = onTap) : null,
      ));

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return spans.isEmpty
        ? [TextSpan(text: text, style: baseStyle)]
        : spans;
  }
}

class _Match {
  final String type;
  final int start;
  final int end;
  final String text;

  _Match({
    required this.type,
    required this.start,
    required this.end,
    required this.text,
  });
}