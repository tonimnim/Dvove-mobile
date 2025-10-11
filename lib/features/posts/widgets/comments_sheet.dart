import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment.dart';
import '../providers/posts_provider.dart';
import '../providers/comments_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'comment_item.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final bool commentsEnabled;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.commentsEnabled,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Load comments through provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);
      commentsProvider.loadComments(widget.postId);
    });
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    setState(() {
      _isSending = true;
    });

    // Clear input immediately
    _commentController.clear();

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
      humanTime: 'just now',
      isMine: true,
      score: 0,
    );

    // Add optimistic comment through provider
    commentsProvider.addComment(widget.postId, optimisticComment);

    // Send to server in background
    final result = await postsProvider.addComment(widget.postId, content);

    if (mounted) {
      if (result != null && result['success']) {
        // Replace optimistic comment with real server data through provider
        final realComment = result['comment'] as Comment;
        commentsProvider.replaceOptimisticComment(widget.postId, tempId, realComment);
      } else {
        // Remove optimistic comment if failed through provider
        commentsProvider.deleteComment(widget.postId, tempId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send comment. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAuthenticated = authProvider.isAuthenticated;

    return Consumer<CommentsProvider>(
      builder: (context, commentsProvider, child) {
        final comments = commentsProvider.getComments(widget.postId);
        final isLoading = comments.isEmpty && !commentsProvider.hasLoadedComments(widget.postId);

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
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

                  // Title
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Comments list
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : comments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Be the first to comment',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final comment = comments[index];

                                  return CommentItem(
                                    postId: widget.postId,
                                    comment: comment,
                                    onDeleted: () {
                                      // Provider handles deletion
                                    },
                                    onEdited: (editedComment) {
                                      // Provider handles update
                                    },
                                  );
                                },
                              ),
                  ),

                  // Comment input
                  if (widget.commentsEnabled && isAuthenticated) ...[
                    const Divider(height: 1),
                    Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Colors.black),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            onPressed: _isSending ? null : _sendComment,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ] else if (!isAuthenticated) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Login to comment',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}