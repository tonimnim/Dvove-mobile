import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/post_header.dart';
import '../widgets/post_media.dart';
import '../widgets/post_actions.dart';
import '../widgets/formatted_text.dart';
import '../services/posts_service.dart';
import '../../../shared/widgets/user_avatar.dart';
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
  final PostsService _postsService = PostsService();
  List<Comment> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;

  // Local state for like
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked ?? false;
    _likesCount = widget.post.likesCount;
    _loadComments();
  }

  @override
  void didUpdateWidget(PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked ?? false;
      _likesCount = widget.post.likesCount;
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    final result = await _postsService.getComments(widget.post.id);

    setState(() {
      if (result['success']) {
        _comments = result['comments'] ?? [];
      }
      _isLoadingComments = false;
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Create optimistic comment
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final optimisticComment = Comment(
      id: tempId,
      content: content,
      user: CommentUser(
        id: authProvider.user!.id,
        username: authProvider.user!.username,
        profilePhoto: authProvider.user!.profilePhoto,
        isOfficial: authProvider.user!.isOfficial,
        officialName: authProvider.user!.officialName,
      ),
      createdAt: DateTime.now(),
      humanTime: 'Just now', // Still needed for backend compatibility
      isMine: true,
    );

    // Add optimistic comment to UI immediately
    setState(() {
      _comments.insert(0, optimisticComment);
      _isPostingComment = true;
    });

    // Clear input immediately
    _commentController.clear();

    // Send to server in background
    final result = await _postsService.addComment(widget.post.id, content);

    if (mounted) {
      if (result['success'] && result['comment'] != null) {
        // Replace optimistic comment with real server data
        final realComment = result['comment'] as Comment;
        setState(() {
          final index = _comments.indexWhere((c) => c.id == tempId);
          if (index != -1) {
            _comments[index] = realComment;
          }
        });
      } else {
        // Remove optimistic comment if failed
        setState(() {
          _comments.removeWhere((c) => c.id == tempId);
        });

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

  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    final currentLikes = _likesCount;

    // Optimistic update
    setState(() {
      _isLiked = !wasLiked;
      _likesCount = wasLiked ? currentLikes - 1 : currentLikes + 1;
    });

    try {
      final result = wasLiked
        ? await _postsService.unlikePost(widget.post.id)
        : await _postsService.likePost(widget.post.id);

      if (result['success']) {
        // Update with server response
        setState(() {
          _isLiked = result['is_liked'];
          _likesCount = result['likes_count'];
        });
      } else {
        // Revert on failure
        setState(() {
          _isLiked = wasLiked;
          _likesCount = currentLikes;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = wasLiked;
        _likesCount = currentLikes;
      });
    }
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
                  // Post content
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
                        // Full content with hashtags, mentions, and URLs highlighted
                        if (widget.post.content != null)
                          FormattedText(
                            text: widget.post.content!,
                            showFullContent: true, // Show full content without truncation
                          ),
                        if (widget.post.hasMedia) ...[
                          const SizedBox(height: 12),
                          PostMedia(mediaUrls: widget.post.mediaUrls),
                        ],
                        const SizedBox(height: 12),
                        PostActions(
                          likesCount: _likesCount,
                          commentsCount: _comments.length,
                          isLiked: _isLiked,
                          onLike: _toggleLike,
                          onComment: () {
                            // Focus on comment input
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
                          onShare: () {
                            // Share functionality
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Comments section
                  if (_isLoadingComments)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: UserAvatar(
                                user: comment.user,
                                radius: 16,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    comment.user.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '• ${comment.whatsappTime}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                comment.content,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (index < _comments.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Colors.grey.shade300,
                                indent: 60,
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // Comment input
          if (widget.post.commentsEnabled)
            Container(
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}