import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../providers/posts_provider.dart';
import '../providers/comments_provider.dart';
import '../screens/post_detail_screen.dart';
import '../screens/create_post_screen.dart';
import '../services/posts_service.dart';
import 'post_header.dart';
import 'post_content.dart';
import 'post_media.dart';
import 'post_actions.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({
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
                  Expanded(
                    child: Text(
                      'Sponsored',
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
                  PostHeader(
                    author: post.author,
                    humanTime: post.freshHumanTime,
                    type: post.type,
                    postId: post.id,
                    priority: post.priority,
                    expiresAt: post.expiresAt,
                    onEdit: () => _handleEditPost(context),
                    onDelete: () => _handleDeletePost(context),
                    isLocalPost: post.isLocal,
                    isAd: post.isAd,
                  ),

                  const SizedBox(height: 8),

                  PostContent(
                    content: post.content,
                    type: post.type,
                    priority: post.priority,
                    post: post,
                  ),

                  if (post.hasMedia) ...[
                    const SizedBox(height: 12),
                    PostMedia(
                      mediaUrls: post.mediaUrls,
                      isAd: post.isAd,
                    ),
                  ],

                ],
              ),
            ),
          ),

          if (!post.isAd)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 12),
              child: Consumer2<PostsProvider, CommentsProvider>(
                builder: (context, postsProvider, commentsProvider, child) {
                  final updatedPost = postsProvider.posts.firstWhere(
                    (p) => p.id == post.id || p.serverId.toString() == post.id,
                    orElse: () => post,
                  );

                  final commentsCount = commentsProvider.hasLoadedComments(post.id)
                      ? commentsProvider.getComments(post.id).length
                      : updatedPost.commentsCount;

                  return PostActions(
                    likesCount: updatedPost.likesCount,
                    commentsCount: commentsCount,
                    isLiked: updatedPost.isLiked ?? false,
                    onLike: () {
                      postsProvider.toggleLike(post.id);
                    },
                    onComment: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailScreen(post: post),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

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
      try {
        final postsProvider = context.read<PostsProvider>();
        postsProvider.initializeFeed();
      } catch (e) {
      }
    }
  }

  void _handleDeletePost(BuildContext context) async {
    final postsService = PostsService();
    final result = await postsService.deletePost(post.id);

    if (result['success']) {
      try {
        final postsProvider = context.read<PostsProvider>();
        postsProvider.removePost(post.id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
          duration: const Duration(seconds: 2),
        ),
      );
    }
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