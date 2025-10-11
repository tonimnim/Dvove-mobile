import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notification.dart' as models;

/// Provider for managing notification state across the app
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Cache notifications
  List<models.Notification> _notifications = [];
  models.NotificationMeta? _meta;
  int _currentPage = 1;
  static const int _perPage = 20;

  // Filters
  bool _unreadOnly = false;
  String? _typeFilter;

  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  // Getters
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<models.Notification> get notifications => _notifications;
  models.NotificationMeta? get meta => _meta;
  int get currentPage => _currentPage;
  bool get unreadOnly => _unreadOnly;
  String? get typeFilter => _typeFilter;

  /// Load unread notification count for badges
  Future<void> loadUnreadCount() async {
    _isLoading = true;
    notifyListeners();

    try {
      _unreadCount = await _notificationService.getUnreadCount();
    } catch (e) {
      _unreadCount = 0; // Set to 0 on error to avoid breaking UI
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update unread count manually (useful after marking notifications as read)
  void updateUnreadCount(int newCount) {
    _unreadCount = newCount;
    notifyListeners();
  }

  /// Decrement unread count by 1 (when marking single notification as read)
  void decrementUnreadCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  /// Reset unread count to 0 (when marking all as read)
  void clearUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// Initialize notifications (load if cache is empty)
  Future<void> initializeNotifications() async {
    if (_notifications.isEmpty) {
      await loadNotifications();
    }
  }

  /// Load notifications with current filters
  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    notifyListeners();

    try {
      final response = await _notificationService.getNotifications(
        unreadOnly: _unreadOnly,
        type: _typeFilter,
        perPage: _perPage,
        page: _currentPage,
      );

      _notifications = response.notifications;
      _meta = response.meta;
      _unreadCount = response.meta.unreadCount;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _notifications = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more notifications (pagination)
  Future<void> loadMoreNotifications() async {
    if (_isLoadingMore || _meta == null || _currentPage >= _meta!.lastPage) {
      return;
    }

    _isLoadingMore = true;
    _currentPage++;
    notifyListeners();

    try {
      final response = await _notificationService.getNotifications(
        unreadOnly: _unreadOnly,
        type: _typeFilter,
        perPage: _perPage,
        page: _currentPage,
      );

      _notifications.addAll(response.notifications);
      _meta = response.meta;
    } catch (e) {
      _currentPage--; // Revert page on error
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Refresh notifications (pull-to-refresh)
  Future<void> refreshNotifications() async {
    await loadNotifications();
  }

  /// Set filter and reload
  Future<void> setUnreadFilter(bool unreadOnly) async {
    if (_unreadOnly != unreadOnly) {
      _unreadOnly = unreadOnly;
      await loadNotifications();
    }
  }

  /// Set type filter and reload
  Future<void> setTypeFilter(String? typeFilter) async {
    if (_typeFilter != typeFilter) {
      _typeFilter = typeFilter;
      await loadNotifications();
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);

      // Update local cache
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        decrementUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // Update local cache
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      clearUnreadCount();
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  /// Refresh notification data
  Future<void> refresh() async {
    await Future.wait([
      loadUnreadCount(),
      refreshNotifications(),
    ]);
  }

  /// Clear all cached data (for logout)
  void clearCache() {
    _notifications.clear();
    _meta = null;
    _unreadCount = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _errorMessage = null;
    _currentPage = 1;
    _unreadOnly = false;
    _typeFilter = null;
    notifyListeners();
  }
}