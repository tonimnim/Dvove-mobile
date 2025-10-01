import 'package:flutter/material.dart';
import '../models/notification.dart' as models;

/// Card widget for displaying individual notifications
class NotificationCard extends StatelessWidget {
  final models.Notification notification;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.white : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notification.isRead
                    ? Colors.grey.shade200
                    : Colors.blue.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type badge and time
                Row(
                  children: [
                    _buildTypeBadge(),
                    const Spacer(),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      notification.humanTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 4),

                // Body
                Text(
                  notification.body,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                // Emergency indicator
                if (notification.isEmergency) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EMERGENCY',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (notification.type) {
      case 'alert':
        badgeColor = notification.isHighPriority ? Colors.red : Colors.orange;
        badgeText = notification.isHighPriority ? 'ALERT' : 'Alert';
        badgeIcon = notification.isHighPriority ? Icons.warning : Icons.info;
        break;
      case 'new_post':
        badgeColor = const Color(0xFF01775A);
        badgeText = 'Job';
        badgeIcon = Icons.work;
        break;
      case 'subscription':
        badgeColor = Colors.purple;
        badgeText = 'Subscription';
        badgeIcon = Icons.star;
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'Update';
        badgeIcon = Icons.notifications;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            color: badgeColor,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}