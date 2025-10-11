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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon only (no badge background)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildTypeIcon(),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Time row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notification.humanTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Body
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'alert':
        icon = notification.isHighPriority ? Icons.warning : Icons.info;
        iconColor = notification.isHighPriority ? Colors.red : Colors.orange;
        break;
      case 'new_post':
        icon = Icons.work;
        iconColor = const Color(0xFF01775A);
        break;
      case 'subscription':
        icon = Icons.star;
        iconColor = Colors.purple;
        break;
      case 'constitution_daily':
        icon = Icons.gavel;
        iconColor = const Color(0xFF006600);
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey.shade600;
    }

    return Icon(
      icon,
      color: iconColor,
      size: 20,
    );
  }
}