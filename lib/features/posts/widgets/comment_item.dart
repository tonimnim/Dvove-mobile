import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment.dart';
import '../services/posts_service.dart';
import '../providers/comments_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user.dart';
import 'memory_optimized_image.dart';

class CommentItem extends StatefulWidget {
  final String postId;
  final Comment comment;
  final VoidCallback onDeleted;
  final Function(Comment) onEdited;

  const CommentItem({
    super.key,
    required this.postId,
    required this.comment,
    required this.onDeleted,
    required this.onEdited,
  });

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final _editController = TextEditingController();
  final _postsService = PostsService();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _editController.text = widget.comment.content;
  }

  void _showOptions() {
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
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.black),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment() async {
    final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);

    // Save original state for rollback
    final deletedComment = widget.comment;
    final comments = commentsProvider.getComments(widget.postId);
    final originalIndex = comments.indexWhere((c) => c.id == widget.comment.id);

    // Optimistic update - remove from UI immediately
    commentsProvider.deleteComment(widget.postId, widget.comment.id);
    widget.onDeleted();

    // Call API and handle response
    try {
      final result = await _postsService.deleteComment(widget.comment.id);

      if (!result['success']) {
        // API returned error - rollback to original state
        if (mounted) {
          commentsProvider.insertCommentAt(widget.postId, deletedComment, originalIndex);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      // On success, comment stays deleted (already removed optimistically)
    } catch (error) {
      // Network error or exception - rollback to original state
      if (mounted) {
        commentsProvider.insertCommentAt(widget.postId, deletedComment, originalIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveEdit() async {
    if (_editController.text.trim().isEmpty) return;

    final result = await _postsService.editComment(
      widget.comment.id,
      _editController.text.trim(),
    );

    if (result['success'] && mounted) {
      final commentsProvider = Provider.of<CommentsProvider>(context, listen: false);
      commentsProvider.updateComment(widget.postId, result['comment']);
      widget.onEdited(result['comment']);
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Consumer<CommentsProvider>(
      builder: (context, commentsProvider, child) {
        final comment = commentsProvider.getComment(widget.postId, widget.comment.id);

        if (comment == null) {
          return const SizedBox.shrink();
        }

        final isCurrentUser = authProvider.user?.id == comment.user.id;

        final displayUser = isCurrentUser && authProvider.user != null
            ? authProvider.user
            : User(
                id: comment.user.id,
                username: comment.user.username ?? '',
                role: comment.user.isOfficial ? 'official' : 'user',
                isActive: true,
                createdAt: DateTime.now(),
                profilePhoto: comment.user.profilePhoto,
                officialName: comment.user.officialName,
                subscriptionStatus: comment.user.isVerified ? 'active' : null,
              );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              MemoryOptimizedAvatar(
                imageUrl: displayUser?.profilePhoto,
                fallbackText: displayUser?.displayName ?? comment.user.displayName,
                size: 32,
              ),
              const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
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
                    if (comment.user.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ],
                    const SizedBox(width: 4),
                    Text(
                      '· ${comment.whatsappTime}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (comment.isMine == true)
                      GestureDetector(
                        onTap: _showOptions,
                        child: Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_isEditing) ...[
                  TextField(
                    controller: _editController,
                    autofocus: true,
                    maxLines: null,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _editController.text = widget.comment.content;
                          });
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: _saveEdit,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          commentsProvider.toggleUpvote(widget.postId, comment.id);
                        },
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: comment.userVote == 'upvote'
                              ? Colors.green
                              : Colors.grey.shade600,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.score}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: comment.score > 0
                              ? Colors.green
                              : comment.score < 0
                                  ? Colors.red
                                  : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () {
                          commentsProvider.toggleDownvote(widget.postId, comment.id);
                        },
                        icon: Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                          color: comment.userVote == 'downvote'
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
            ),
              ),
            ),
        ],
      ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 12),
              child: Divider(height: 1, color: Colors.grey.shade200),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }
}