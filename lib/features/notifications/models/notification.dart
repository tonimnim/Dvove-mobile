/// Notification model representing push notifications and alerts
class Notification {
  final int id;
  final String type; // 'alert', 'new_post', 'subscription'
  final String title;
  final String body;
  final Map<String, dynamic> data; // Additional context data
  final bool isRead;
  final DateTime createdAt;
  final String humanTime; // e.g., "21 minutes ago"

  Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
    required this.humanTime,
  });

  // Convenience getters for common notification properties
  bool get isEmergency => data['emergency'] == true;
  String get priority => data['priority'] ?? 'medium';
  int? get countyId => data['county_id'];
  int? get postId => data['post_id'];
  String? get articleId => data['article_id'];

  bool get isHighPriority => priority == 'high';
  bool get isAlert => type == 'alert';
  bool get isNewPost => type == 'new_post';
  bool get isSubscription => type == 'subscription';
  bool get isConstitutionDaily => type == 'constitution_daily';

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      humanTime: json['human_time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'human_time': humanTime,
    };
  }

  Notification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    String? humanTime,
  }) {
    return Notification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      humanTime: humanTime ?? this.humanTime,
    );
  }
}

/// Meta information for notification pagination and counts
class NotificationMeta {
  final int currentPage;
  final int? from; // Can be null when no results
  final int lastPage;
  final int perPage;
  final int? to; // Can be null when no results
  final int total;
  final int unreadCount; // For badge display

  NotificationMeta({
    required this.currentPage,
    this.from,
    required this.lastPage,
    required this.perPage,
    this.to,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationMeta.fromJson(Map<String, dynamic> json) {
    return NotificationMeta(
      currentPage: json['current_page'] ?? 1,
      from: json['from'], // Allow null
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 20,
      to: json['to'], // Allow null
      total: json['total'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

/// Response structure for notification API calls
class NotificationResponse {
  final bool success;
  final List<Notification> notifications;
  final NotificationMeta meta;
  final String? message;

  NotificationResponse({
    required this.success,
    required this.notifications,
    required this.meta,
    this.message,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      success: json['success'] ?? false,
      notifications: (json['data'] as List?)
          ?.map((item) => Notification.fromJson(item))
          .toList() ?? [],
      meta: NotificationMeta.fromJson(json['meta'] ?? {}),
      message: json['message'],
    );
  }
}