import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Provider for managing notification state across the app
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  int _unreadCount = 0;
  bool _isLoading = false;

  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  // Getters
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Load unread notification count for badges
  Future<void> loadUnreadCount() async {
    _isLoading = true;
    notifyListeners();

    try {
      _unreadCount = await _notificationService.getUnreadCount();
    } catch (e) {
      print('[NotificationProvider] Error loading unread count: $e');
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

  /// Refresh notification data
  Future<void> refresh() async {
    await loadUnreadCount();
  }
}