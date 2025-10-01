import 'package:flutter/material.dart';

class PostActions extends StatefulWidget {
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onShare;

  const PostActions({
    super.key,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    this.onShare,
  });

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  void _handleLike() {
    widget.onLike();
    if (widget.isLiked) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Like button with animation
        GestureDetector(
          onTap: _handleLike,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isLiked ? _scaleAnimation.value : 1.0,
                child: Row(
                  children: [
                    Icon(
                      widget.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: widget.isLiked ? Colors.red : Colors.grey.shade600,
                    ),
                    if (widget.likesCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(widget.likesCount),
                        style: TextStyle(
                          color: widget.isLiked ? Colors.red : Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),

        // Comment button
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.grey.shade600,
          count: _formatCount(widget.commentsCount),
          onTap: widget.onComment,
        ),

        if (widget.onShare != null) ...[
          const SizedBox(width: 16),
          // Share button
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              size: 20,
              color: Colors.grey.shade600,
            ),
            onPressed: widget.onShare,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            if (count != '0') ...[
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}