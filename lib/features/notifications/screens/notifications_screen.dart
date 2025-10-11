import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart' as models;
import '../providers/notification_provider.dart';
import '../widgets/notification_card.dart';
import '../../constitution/screens/article_detail_screen.dart';

/// Main notifications screen with filtering and pagination
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize notifications if cache is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      provider.initializeNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      if (!provider.isLoadingMore) {
        provider.loadMoreNotifications();
      }
    }
  }

  Future<void> _onRefresh() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.refreshNotifications();
  }

  Future<void> _markAllAsRead() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.markAllAsRead();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Color(0xFF01775A),
        ),
      );
    }
  }

  void _onFiltersChanged({
    bool? unreadOnly,
    String? type,
  }) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    if (unreadOnly != null) {
      provider.setUnreadFilter(unreadOnly);
    }

    if (type != null) {
      provider.setTypeFilter(type.isEmpty ? null : type);
    }
  }

  Future<void> _markNotificationAsRead(models.Notification notification) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    // Mark as read if not already
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }

    // Navigate based on notification type
    if (mounted) {
      _handleNotificationNavigation(notification);
    }
  }

  void _handleNotificationNavigation(models.Notification notification) {
    // Handle navigation based on notification type
    if (notification.isConstitutionDaily) {
      // Navigate to Article Detail screen
      final articleId = notification.articleId;
      if (articleId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(articleId: articleId),
          ),
        );
      }
    }
    // Add more navigation cases here as needed
    // else if (notification.isNewPost) { ... }
    // else if (notification.isAlert) { ... }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Unified Filter and Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    // Top row: Unread count + Mark All Read (if needed)
                    if (provider.meta != null && provider.meta!.unreadCount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${provider.meta!.unreadCount} unread',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _markAllAsRead,
                            child: const Text(
                              'Mark All Read',
                              style: TextStyle(
                                color: Color(0xFF01775A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Filter row: All/Jobs/Katiba + Unread toggle
                    Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          isSelected: provider.typeFilter == null,
                          onTap: () => _onFiltersChanged(type: ''),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Jobs',
                          isSelected: provider.typeFilter == 'new_post',
                          onTap: () => _onFiltersChanged(type: 'new_post'),
                          color: const Color(0xFF01775A),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Katiba360°',
                          isSelected: provider.typeFilter == 'constitution_daily',
                          onTap: () => _onFiltersChanged(type: 'constitution_daily'),
                          color: const Color(0xFF006600),
                        ),
                    const Spacer(),
                    // Unread Only Toggle
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: provider.unreadOnly,
                            onChanged: (value) {
                              _onFiltersChanged(unreadOnly: value);
                            },
                            activeThumbColor: const Color(0xFF01775A),
                            activeTrackColor: const Color(0xFF01775A).withOpacity(0.3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Unread only',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildBody(provider),
          ),
        ],
      ),
    );
      },
    );
  }


  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? const Color(0xFF01775A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16), // Reduced border radius
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12, // Reduced font size
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF01775A),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01775A),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF01775A),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: provider.notifications.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.notifications.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: Color(0xFF01775A),
                ),
              ),
            );
          }

          final notification = provider.notifications[index];
          return NotificationCard(
            notification: notification,
            onTap: () => _markNotificationAsRead(notification),
          );
        },
      ),
    );
  }
}