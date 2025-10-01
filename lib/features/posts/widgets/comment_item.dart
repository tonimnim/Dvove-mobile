import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/posts_service.dart';
import '../../../shared/widgets/user_avatar.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final VoidCallback onDeleted;
  final Function(Comment) onEdited;

  const CommentItem({
    super.key,
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
  bool _isDeleting = false;

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
    setState(() {
      _isDeleting = true;
    });

    final result = await _postsService.deleteComment(widget.comment.id);

    if (result['success'] && mounted) {
      widget.onDeleted();
    }

    if (mounted) {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _saveEdit() async {
    if (_editController.text.trim().isEmpty) return;

    final result = await _postsService.editComment(
      widget.comment.id,
      _editController.text.trim(),
    );

    if (result['success'] && mounted) {
      widget.onEdited(result['comment']);
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            user: widget.comment.user,
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
                      widget.comment.user.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.comment.user.isOfficial) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ],
                    const SizedBox(width: 4),
                    Text(
                      '· ${widget.comment.humanTime}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (widget.comment.isMine ?? false)
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
                ] else
                  Text(
                    widget.comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                    ),
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
    _editController.dispose();
    super.dispose();
  }
}