import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/post_header.dart';
import '../widgets/post_media.dart';
import '../widgets/post_actions.dart';
import '../widgets/formatted_text.dart';
import '../widgets/comment_item.dart';
import '../providers/posts_provider.dart';
import '../providers/comments_provider.dart';
import '../../auth/providers/auth_provider.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;
  bool _postDeleted = false;
  PostsProvider? _postsProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);
      commentsProvider.loadComments(widget.post.id);

      // Listen for post deletions
      _postsProvider = Provider.of<PostsProvider>(context, listen: false);
      _postsProvider?.addListener(_checkIfPostDeleted);
    });
  }

  void _checkIfPostDeleted() {
    if (_postDeleted || !mounted || _postsProvider == null) return;

    // Check if post exists in any feed
    final homePosts = _postsProvider!.getPostsForFeed(null);
    final jobPosts = _postsProvider!.getPostsForFeed('job');

    final existsInHome = homePosts.any((p) => p.id == widget.post.id);
    final existsInJobs = jobPosts.any((p) => p.id == widget.post.id);

    if (!existsInHome && !existsInJobs) {
      _postDeleted = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This post was deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    }
  }

  @override
  void didUpdateWidget(PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);
      commentsProvider.loadComments(widget.post.id);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);

    final tempId = DateTime.now().millisecondsSinceEpoch;
    final optimisticComment = Comment(
      id: tempId,
      content: content,
      user: CommentUser(
        id: authProvider.user!.id,
        username: authProvider.user!.username,
        profilePhoto: authProvider.user!.profilePhoto,
        isOfficial: authProvider.user!.isOfficial,
        isVerified: authProvider.user!.hasActiveSubscription,
        officialName: authProvider.user!.officialName,
      ),
      createdAt: DateTime.now(),
      humanTime: 'Just now',
      isMine: true,
    );

    commentsProvider.addComment(widget.post.id, optimisticComment);

    if (!mounted) return;

    setState(() {
      _isPostingComment = true;
    });

    _commentController.clear();

    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    final result = await postsProvider.addComment(widget.post.id, content);

    if (mounted) {
      if (result != null && result['success'] && result['comment'] != null) {
        final realComment = result['comment'] as Comment;
        commentsProvider.replaceOptimisticComment(widget.post.id, tempId, realComment);
      } else {
        commentsProvider.deleteComment(widget.post.id, tempId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send comment. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        _isPostingComment = false;
      });
    }
  }

  void _toggleLike() {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    postsProvider.toggleLike(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade300,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PostHeader(
                          author: widget.post.author,
                          humanTime: widget.post.freshHumanTime,
                          type: widget.post.type,
                          postId: widget.post.id,
                          priority: widget.post.priority,
                          expiresAt: widget.post.expiresAt,
                          isLocalPost: widget.post.isLocal,
                        ),
                        const SizedBox(height: 12),
                        if (widget.post.content != null)
                          FormattedText(
                            text: widget.post.content!,
                            showFullContent: true,
                          ),
                        if (widget.post.hasMedia) ...[
                          const SizedBox(height: 12),
                          PostMedia(mediaUrls: widget.post.mediaUrls),
                        ],
                        const SizedBox(height: 12),
                        Consumer2<PostsProvider, CommentsProvider>(
                          builder: (context, postsProvider, commentsProvider, child) {
                            // Search for the post in all feeds
                            Post updatedPost = widget.post;

                            // Check home feed
                            final homePosts = postsProvider.getPostsForFeed(null);
                            try {
                              updatedPost = homePosts.firstWhere(
                                (p) => p.id == widget.post.id,
                              );
                            } catch (e) {
                              // Not found in home feed, check jobs feed
                              final jobPosts = postsProvider.getPostsForFeed('job');
                              try {
                                updatedPost = jobPosts.firstWhere(
                                  (p) => p.id == widget.post.id,
                                );
                              } catch (e) {
                                // Not found in any feed, use original post
                                updatedPost = widget.post;
                              }
                            }

                            final commentsCount = commentsProvider.getComments(widget.post.id).length;
                            return PostActions(
                              likesCount: updatedPost.likesCount,
                              commentsCount: commentsCount,
                              isLiked: updatedPost.isLiked ?? false,
                              onLike: _toggleLike,
                              onComment: () {
                                FocusScope.of(context).requestFocus(FocusNode());
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Consumer<CommentsProvider>(
                    builder: (context, commentsProvider, child) {
                      final comments = commentsProvider.getComments(widget.post.id);

                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return CommentItem(
                              postId: widget.post.id,
                              comment: comment,
                              onDeleted: () {
                                commentsProvider.deleteComment(widget.post.id, comment.id);
                              },
                              onEdited: (editedComment) {
                                commentsProvider.updateComment(widget.post.id, editedComment);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (widget.post.commentsEnabled)
            SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Color(0xFF01775A)),
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isPostingComment ? null : _postComment,
                    icon: _isPostingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Color(0xFF01775A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _postsProvider?.removeListener(_checkIfPostDeleted);
    _commentController.dispose();
    super.dispose();
  }
}