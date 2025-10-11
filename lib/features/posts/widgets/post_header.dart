import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/post.dart';
import 'memory_optimized_image.dart';

class PostHeader extends StatelessWidget {
  final PostAuthor author;
  final String humanTime;
  final String type;
  final String? priority;
  final DateTime? expiresAt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String postId;
  final bool isLocalPost;
  final bool isAd;

  const PostHeader({
    super.key,
    required this.author,
    required this.humanTime,
    required this.type,
    required this.postId,
    this.priority,
    this.expiresAt,
    this.onEdit,
    this.onDelete,
    this.isLocalPost = false,
    this.isAd = false,
  });

  String? _getExpiryText() {
    if (expiresAt == null) return null;

    final now = DateTime.now();
    final difference = expiresAt!.difference(now);

    if (difference.isNegative) return 'Expired';

    if (difference.inDays > 0) {
      return 'Expires in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Expires in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Expires soon';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiryText = _getExpiryText();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isCurrentUser = authProvider.user?.id == author.id;
        final displayPhoto = isCurrentUser
            ? authProvider.user?.profilePhoto
            : author.profilePhoto;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoryOptimizedAvatar(
              imageUrl: displayPhoto,
              fallbackText: author.name,
              size: 40,
            ),
            const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (author.isVerified) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ],
                  const SizedBox(width: 4),
                  Text(
                    '· $humanTime',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  // High priority badge for alerts
                  if (type == 'alert' && priority == 'high') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF01775A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HIGH PRIORITY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                  // Expiry badge for jobs/events
                  if (expiryText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: expiryText == 'Expired'
                            ? Colors.red
                            : const Color(0xFF01775A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expiryText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
            // More button - only show for post author and synced posts (NOT for ads)
            if (isAd || !isCurrentUser || isLocalPost)
              const SizedBox.shrink()
            else
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) {
                    onEdit!();
                  } else if (value == 'delete' && onDelete != null) {
                    onDelete!();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.black),
                        SizedBox(width: 12),
                        Text('Edit post'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete post', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}