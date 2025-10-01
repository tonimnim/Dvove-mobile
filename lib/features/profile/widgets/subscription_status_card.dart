import 'package:flutter/material.dart';
import '../../auth/models/user.dart';

/// Widget to display subscription status for official users
/// Shows subscription status, premium badge, and expiry information
class SubscriptionStatusCard extends StatelessWidget {
  final User user;

  const SubscriptionStatusCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (!user.isOfficial) return const SizedBox.shrink();

    final status = user.subscriptionStatus;
    final hasActive = user.hasActiveSubscription;
    final expiresAt = user.subscriptionExpiresAt;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? expiryText;

    switch (status) {
      case 'active':
        statusColor = const Color(0xFF01775A);
        statusIcon = Icons.verified;
        statusText = 'Active Premium';
        if (expiresAt != null) {
          expiryText = 'Expires ${_formatDate(expiresAt)}';
        }
        break;
      case 'grace_period':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = 'Grace Period';
        if (expiresAt != null) {
          expiryText = 'Expires ${_formatDate(expiresAt)}';
        }
        break;
      case 'expired':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Expired';
        expiryText = 'Subscription has expired';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = 'No Subscription';
        expiryText = 'Subscribe for premium features';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Subscription Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expiryText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    expiryText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}