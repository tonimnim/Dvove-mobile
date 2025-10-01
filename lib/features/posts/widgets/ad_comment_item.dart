import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment.dart';
import '../../../shared/widgets/user_avatar.dart';

class AdCommentItem extends StatelessWidget {
  final Comment comment;

  const AdCommentItem({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: comment.hasClickUrl ? () => _handleAdClick(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ad banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Ad',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (comment.advertiserName != null)
                  Expanded(
                    child: Text(
                      'Sponsored by ${comment.advertiserName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (comment.hasClickUrl) ...[
                  const Spacer(),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: Colors.amber.shade700,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Ad content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  user: comment.user,
                  radius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '· ${comment.humanTime}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (comment.content.isNotEmpty) ...[
                        Text(
                          comment.content,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        if (comment.hasMedia) const SizedBox(height: 8),
                      ],
                      // Twitter-style image card
                      if (comment.hasMedia)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: 200, // Small card height
                              maxWidth: double.infinity,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: comment.mediaUrls.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAdClick(BuildContext context) async {
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening ad...'),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    // Open click URL
    try {
      final Uri url = Uri.parse(comment.clickUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showAdError(context, 'Cannot open this link');
      }
    } catch (e) {
      _showAdError(context, 'Invalid link');
    }
  }

  void _showAdError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}