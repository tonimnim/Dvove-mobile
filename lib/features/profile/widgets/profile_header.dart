import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import 'profile_avatar.dart';

/// Header section of the profile screen containing avatar, name, and role badge
class ProfileHeader extends StatelessWidget {
  final User user;
  final Function(User updatedUser)? onUserUpdated;

  const ProfileHeader({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  Widget _buildRoleBadge() {
    final isOfficial = user.isOfficial;

    if (!isOfficial) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'User',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    // Professional official badge with premium indicator
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF01775A), Color(0xFF02A876)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF01775A).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'OFFICIAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (user.hasActiveSubscription) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (user.county != null) ...[
          const SizedBox(height: 4),
          Text(
            user.county!.name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Profile Avatar with photo picker
          ProfileAvatar(
            user: user,
            radius: 50,
            onUserUpdated: onUserUpdated,
          ),

          const SizedBox(height: 16),

          // Display Name
          Text(
            user.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          // Role Badge
          _buildRoleBadge(),
        ],
      ),
    );
  }
}