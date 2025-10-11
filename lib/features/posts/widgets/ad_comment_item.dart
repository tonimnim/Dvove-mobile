import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment.dart';
import '../../../core/config/app_config.dart';

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
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: Colors.amber.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.advertiserName ?? 'Sponsored',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (comment.content.isNotEmpty) ...[
                        Text(
                          comment.content,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (comment.hasMedia)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: AppConfig.fixMediaUrl(comment.mediaUrls.first),
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
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade400,
                                  size: 32,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening ad...'),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

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