class Comment {
  final int id;
  final String content;
  final CommentUser user;
  final DateTime createdAt;
  final String humanTime;
  final bool? isMine;
  final List<String> mediaUrls; // Added for ad images

  // Ad-specific fields
  final String? itemType; // "ad" if this is an ad, null for regular comments
  final String? adType; // "featured", "county", "national"
  final String? clickUrl; // URL to open when ad is clicked
  final String? advertiserName;

  Comment({
    required this.id,
    required this.content,
    required this.user,
    required this.createdAt,
    required this.humanTime,
    this.isMine,
    this.mediaUrls = const [],
    this.itemType,
    this.adType,
    this.clickUrl,
    this.advertiserName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Parse media URLs if present
    List<String> mediaUrls = [];
    if (json['media_urls'] != null) {
      mediaUrls = List<String>.from(json['media_urls']);
    }

    // Handle ads in comments (similar to Post model)
    if (json['item_type'] == 'ad') {
      return Comment(
        id: json['id'],
        content: json['content'] ?? '',
        user: CommentUser(
          id: 0, // Special ID for ads
          username: json['advertiser_name'] ?? 'Sponsored',
          isOfficial: true, // Ads are "official"
          profilePhoto: null,
        ),
        createdAt: DateTime.now(),
        humanTime: 'sponsored',
        isMine: false,
        mediaUrls: mediaUrls,
        itemType: json['item_type'],
        adType: json['ad_type'],
        clickUrl: json['click_url'],
        advertiserName: json['advertiser_name'],
      );
    }

    // Regular comment
    return Comment(
      id: json['id'],
      content: json['content'],
      user: CommentUser.fromJson(json['user']),
      createdAt: DateTime.parse(json['created_at']),
      humanTime: json['human_time'],
      isMine: json['is_mine'],
      mediaUrls: mediaUrls,
      itemType: json['item_type'],
      adType: json['ad_type'],
      clickUrl: json['click_url'],
      advertiserName: json['advertiser_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'user': user.toJson(),
      'created_at': createdAt.toIso8601String(),
      'human_time': humanTime,
      'is_mine': isMine,
      'media_urls': mediaUrls,
      'item_type': itemType,
      'ad_type': adType,
      'click_url': clickUrl,
      'advertiser_name': advertiserName,
    };
  }

  Comment copyWith({
    int? id,
    String? content,
    CommentUser? user,
    DateTime? createdAt,
    String? humanTime,
    bool? isMine,
    List<String>? mediaUrls,
    String? itemType,
    String? adType,
    String? clickUrl,
    String? advertiserName,
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      humanTime: humanTime ?? this.humanTime,
      isMine: isMine ?? this.isMine,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      itemType: itemType ?? this.itemType,
      adType: adType ?? this.adType,
      clickUrl: clickUrl ?? this.clickUrl,
      advertiserName: advertiserName ?? this.advertiserName,
    );
  }

  // Ad-specific getters
  bool get isAd => itemType == 'ad';
  bool get isFeaturedAd => isAd && adType == 'featured';
  bool get isCountyAd => isAd && adType == 'county';
  bool get isNationalAd => isAd && adType == 'national';
  bool get hasClickUrl => clickUrl != null && clickUrl!.isNotEmpty;
  bool get hasMedia => mediaUrls.isNotEmpty;

  // WhatsApp-style static timestamp (no real-time updates needed)
  String get whatsappTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    // Just now (< 1 minute)
    if (diff.inSeconds < 60) return 'Just now';

    // Today: show time (HH:MM)
    if (diff.inDays == 0 && now.day == createdAt.day) {
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }

    // Yesterday
    final yesterday = now.subtract(Duration(days: 1));
    if (createdAt.day == yesterday.day && createdAt.month == yesterday.month && createdAt.year == yesterday.year) {
      return 'Yesterday';
    }

    // Last 7 days: show day name
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    }

    // This year: show "Dec 25"
    if (createdAt.year == now.year) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[createdAt.month - 1]} ${createdAt.day}';
    }

    // Previous years: show "Dec 25, 2024"
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }
}

class CommentUser {
  final int id;
  final String? username;
  final String? profilePhoto;
  final bool isOfficial;
  final String? officialName;

  CommentUser({
    required this.id,
    this.username,
    this.profilePhoto,
    required this.isOfficial,
    this.officialName,
  });

  // Convenience getter for display name (same logic as User model)
  String get displayName {
    return officialName ?? username ?? 'User';
  }

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['id'],
      username: json['username'],
      profilePhoto: json['profile_photo'],
      isOfficial: json['is_official'] ?? false,
      officialName: json['official_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profile_photo': profilePhoto,
      'is_official': isOfficial,
      'official_name': officialName,
    };
  }
}