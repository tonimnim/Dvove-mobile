import 'package:flutter/material.dart';
import '../models/notification.dart' as models;
import '../services/notification_service.dart';
import '../widgets/notification_card.dart';

/// Main notifications screen with filtering and pagination
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();

  List<models.Notification> _notifications = [];
  models.NotificationMeta? _meta;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Simple filter state
  bool _unreadOnly = false;
  String? _typeFilter; // null = 'All', 'new_post' = 'Jobs'

  int _currentPage = 1;
  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _notifications = [];
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (_isLoadingMore) {
      return; // Prevent multiple simultaneous loads
    }

    setState(() {
      if (!refresh) _isLoading = true;
    });

    try {
      final response = await _notificationService.getNotifications(
        unreadOnly: _unreadOnly,
        type: _typeFilter,
        perPage: _perPage,
        page: _currentPage,
      );

      setState(() {
        if (refresh) {
          _notifications = response.notifications;
        } else {
          _notifications.addAll(response.notifications);
        }
        _meta = response.meta;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || _meta == null || _currentPage >= _meta!.lastPage) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadNotifications();

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // Update local state
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        if (_meta != null) {
          _meta = models.NotificationMeta(
            currentPage: _meta!.currentPage,
            from: _meta!.from,
            lastPage: _meta!.lastPage,
            perPage: _meta!.perPage,
            to: _meta!.to,
            total: _meta!.total,
            unreadCount: 0,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Color(0xFF01775A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onFiltersChanged({
    bool? unreadOnly,
    String? type,
  }) {
    setState(() {
      _unreadOnly = unreadOnly ?? false;
      _typeFilter = type;
    });
    _loadNotifications(refresh: true);
  }

  Future<void> _markNotificationAsRead(models.Notification notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(isRead: true);
        }

        // Update unread count
        if (_meta != null) {
          _meta = models.NotificationMeta(
            currentPage: _meta!.currentPage,
            from: _meta!.from,
            lastPage: _meta!.lastPage,
            perPage: _meta!.perPage,
            to: _meta!.to,
            total: _meta!.total,
            unreadCount: _meta!.unreadCount - 1,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking as read: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_meta != null && _meta!.unreadCount > 0) ...[
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
                          '${_meta!.unreadCount} unread',
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

                // Filter row: All/Jobs + Unread toggle
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: _typeFilter == null,
                      onTap: () => _onFiltersChanged(type: null),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Jobs',
                      isSelected: _typeFilter == 'new_post',
                      onTap: () => _onFiltersChanged(type: 'new_post'),
                      color: const Color(0xFF01775A),
                    ),
                    const Spacer(),
                    // Unread Only Toggle
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _unreadOnly,
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
            child: _buildBody(),
          ),
        ],
      ),
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

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF01775A),
        ),
      );
    }

    if (_errorMessage != null) {
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
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadNotifications(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01775A),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
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
      onRefresh: () => _loadNotifications(refresh: true),
      color: const Color(0xFF01775A),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: Color(0xFF01775A),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return NotificationCard(
            notification: notification,
            onTap: () => _markNotificationAsRead(notification),
          );
        },
      ),
    );
  }
}