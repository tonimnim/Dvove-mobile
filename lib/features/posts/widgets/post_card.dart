import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../providers/posts_provider.dart';
import '../screens/post_detail_screen.dart';
import '../screens/create_post_screen.dart';
import '../services/posts_service.dart';
import 'post_header.dart';
import 'post_content.dart';
import 'post_media.dart';
import 'post_actions.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final PostsService _postsService = PostsService();

  PostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show sync status for pending posts only
          if (post.isLocal && post.syncStatus == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Consumer<PostsProvider>(
                    builder: (context, postsProvider, child) {
                      final progress = post.localId != null
                        ? postsProvider.getUploadProgress(post.localId!)
                        : 0.0;

                      return SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Posting...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Icon(Icons.upload, size: 16, color: Colors.blue),
                ],
              ),
            ),

          // Ad banner for ad posts
          if (post.isAd)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  if (post.advertiserName != null)
                    Expanded(
                      child: Text(
                        'Sponsored by ${post.advertiserName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

          // Make the entire post content area clickable (only if not an ad without URL)
          GestureDetector(
            onTap: (post.isAd && !post.hasClickUrl) ? null : () {
              if (post.isAd) {
                _handleAdClick(context);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  PostHeader(
                    author: post.author,
                    humanTime: post.freshHumanTime,
                    type: post.type,
                    postId: post.id,
                    priority: post.priority,
                    expiresAt: post.expiresAt,
                    onEdit: () => _handleEditPost(context),
                    onDelete: () => _handleDeletePost(context),
                    isLocalPost: post.isLocal, // Pass local status
                  ),

                  const SizedBox(height: 8),

                  // Content
                  PostContent(
                    content: post.content,
                    type: post.type,
                    priority: post.priority,
                    post: post,
                  ),

                  // Media
                  if (post.hasMedia) ...[
                    const SizedBox(height: 12),
                    PostMedia(mediaUrls: post.mediaUrls),
                  ],

                ],
              ),
            ),
          ),

          // Hide actions (like, comment, share) for ads
          if (!post.isAd)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 12),
              child: Consumer<PostsProvider>(
                builder: (context, postsProvider, child) {
                  // Get the updated post from provider for real-time updates
                  final updatedPost = postsProvider.posts.firstWhere(
                    (p) => p.id == post.id || p.serverId == post.id,
                    orElse: () => post,
                  );

                  return PostActions(
                    likesCount: updatedPost.likesCount,
                    commentsCount: updatedPost.commentsCount,
                    isLiked: updatedPost.isLiked ?? false,
                    onLike: () {
                      postsProvider.toggleLike(post.id);
                    },
                    onComment: () {
                      // Navigate to post detail screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailScreen(post: post),
                        ),
                      );
                    },
                    onShare: () {
                      _showShareOptions(context);
                    },
                  );
                },
              ),
            ),

          // Bottom divider
          Container(
            height: 8,
            color: Colors.grey.shade100,
          ),
        ],
      ),
    );
  }

  void _handleEditPost(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(postToEdit: post),
      ),
    );

    if (result != null && result is Post) {
      // Post was updated, refresh the feed
      try {
        final postsProvider = context.read<PostsProvider>();
        postsProvider.initializeFeed();
      } catch (e) {
        // Provider not available
      }
    }
  }

  void _handleDeletePost(BuildContext context) async {
    // Delete immediately without confirmation
    final result = await _postsService.deletePost(post.id);

    if (result['success']) {
      // Remove from feed if provider is available
      try {
        final postsProvider = context.read<PostsProvider>();
        postsProvider.removePost(post.id);
      } catch (e) {
        // Provider not available - show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to delete post'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Share via WhatsApp
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('Share via WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _shareViaWhatsApp();
              },
            ),

            // Copy link
            ListTile(
              leading: Icon(Icons.link, color: Colors.grey.shade700),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                _copyLink(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareViaWhatsApp() async {
    final content = post.content ?? '';
    final message = '${post.author.name}: $content\n\nShared from Kaunti+';

    // Create WhatsApp URL
    final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      // Fallback to general share if WhatsApp not installed
      Share.share(message);
    }
  }

  void _copyLink(BuildContext context) {
    // Create a shareable link (using the post ID)
    final link = 'https://kauntiplus.ke/posts/${post.id}';

    Clipboard.setData(ClipboardData(text: link));

    // Show snackbar confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied to clipboard'),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handleAdClick(BuildContext context) async {
    // This method is only called for ads with click URLs
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
      final Uri url = Uri.parse(post.clickUrl!);
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