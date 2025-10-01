import 'package:flutter/material.dart';
import '../../features/auth/models/user.dart';
import '../../core/config/app_config.dart';

/// Reusable user avatar component that shows profile photo or initials
/// Used across the app for consistent avatar display
class UserAvatar extends StatelessWidget {
  final dynamic user; // Can be User object or null
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = _buildAvatar();

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildAvatar() {
    Widget avatar;

    // Show profile photo if available
    if (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: ClipOval(
          child: Image.network(
            AppConfig.fixMediaUrl(user!.profilePhoto!),
            width: radius * 2,
            height: radius * 2,
            cacheWidth: (radius * 2 * 3.5).round(),
            cacheHeight: (radius * 2 * 3.5).round(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsText();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildInitialsText();
            },
          ),
        ),
      );
    } else {
      // Fallback to initials
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: _buildInitialsText(),
      );
    }

    // Add border if requested
    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: 2,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildInitialsText() {
    return Text(
      user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
      style: TextStyle(
        fontSize: radius * 0.8, // Scale text based on avatar size
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}