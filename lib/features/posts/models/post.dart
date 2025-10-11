import 'dart:convert';
import '../../auth/models/user.dart';
import '../../../core/config/app_config.dart';

class Post {
  final String id; // Changed to String to handle both "ad_1" and "1"
  final String? content;
  final String type; // announcement, job, event, alert
  final List<String> mediaUrls;
  final County? county; // Nullable for national posts
  final PostAuthor author;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final bool? isLiked;
  final DateTime createdAt;
  final String humanTime;
  final bool commentsEnabled;

  // Additional fields for specific types
  final String? priority; // for alerts: high, medium, low
  final DateTime? expiresAt; // for jobs/events
  final bool? isPinned;

  // Local database fields
  final int? localId;
  final int? serverId;
  final bool isLocal;
  final String syncStatus; // pending, synced, failed

  // Ad-specific fields
  final String? itemType; // "ad" if this is an ad, null for regular posts
  final String? adType; // "featured", "county", "national"
  final String? clickUrl; // URL to open when ad is clicked
  final String? advertiserName;

  Post({
    required this.id,
    this.content,
    required this.type,
    required this.mediaUrls,
    required this.county,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    this.isLiked,
    required this.createdAt,
    required this.humanTime,
    required this.commentsEnabled,
    this.priority,
    this.expiresAt,
    this.isPinned,
    this.localId,
    this.serverId,
    this.isLocal = false,
    this.syncStatus = 'synced',
    this.itemType,
    this.adType,
    this.clickUrl,
    this.advertiserName,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final itemType = json['item_type'];
    final isAd = itemType == 'ad';

    // Extract media URLs from the new API structure
    List<String> mediaUrls = [];

    if (isAd) {
      // Ads have a 'media' array with direct image objects
      if (json['image_url'] != null) {
        mediaUrls.add(AppConfig.fixMediaUrl(json['image_url']));
      }
    } else {
      // Posts have a 'media' object with images array
      if (json['media'] != null) {
        final media = json['media'];
        // Handle images only (videos removed for MVP)
        if (media['images'] != null) {
          final images = List<String>.from(media['images'])
              .map((url) => AppConfig.fixMediaUrl(url))
              .toList();
          mediaUrls.addAll(images);
        }
      }
    }

    // Extract stats (posts have stats, ads don't)
    final stats = json['stats'] ?? {};

    // Handle author differently for ads vs posts
    final PostAuthor author;
    if (isAd && json['user'] != null) {
      // Ads have a 'user' field instead of 'author'
      final user = json['user'];
      author = PostAuthor(
        id: user['id'] ?? 0,
        name: user['official_name'] ?? user['username'] ?? 'Advertiser',
        profilePhoto: user['profile_photo'],
        isOfficial: user['role'] == 'official',
      );
    } else if (json['author'] != null) {
      // Regular posts have 'author'
      author = PostAuthor.fromJson(json['author']);
    } else {
      // Fallback
      author = PostAuthor(id: 0, name: 'Unknown', isOfficial: false);
    }

    return Post(
      id: (json['id'] ?? json['local_id'] ?? 0).toString(), // Convert to string
      content: json['content'],
      type: json['type'] ?? (isAd ? 'image' : 'announcement'),
      mediaUrls: mediaUrls,
      county: json['county'] != null ? County.fromJson(json['county']) : null,
      author: author,
      likesCount: stats['likes'] ?? 0,
      commentsCount: stats['comments'] ?? 0,
      viewsCount: stats['views'] ?? 0,
      isLiked: json['is_liked'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      humanTime: json['human_time'] ?? _calculateHumanTime(DateTime.parse(json['created_at']).toLocal()),
      priority: json['priority'],
      expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'])
        : null,
      isPinned: json['is_pinned'] ?? false,
      commentsEnabled: json['comments_enabled'] ?? true,
      localId: json['local_id'],
      serverId: json['server_id'],
      isLocal: json['is_local'] == 1 || json['is_local'] == true,
      syncStatus: json['sync_status'] ?? 'synced',
      itemType: itemType,
      adType: json['ad_type'],
      clickUrl: json['click_url'],
      advertiserName: json['advertiser_name'],
    );
  }

  factory Post.fromDatabase(Map<String, dynamic> row) {
    final authorData = jsonDecode(row['author_data'] ?? '{}');
    final mediaData = jsonDecode(row['media_data'] ?? '{}');
    final statsData = jsonDecode(row['stats_data'] ?? '{}');

    List<String> mediaUrls = [];
    if (mediaData['images'] != null) {
      mediaUrls.addAll(List<String>.from(mediaData['images']));
    }
    // Videos removed for MVP - images only

    return Post(
      id: (row['server_id'] ?? row['id']).toString(), // Convert to string
      content: row['content'],
      type: row['type'],
      mediaUrls: mediaUrls,
      county: County(
        id: authorData['county_id'] ?? 0,
        name: authorData['county_name'] ?? '',
        slug: authorData['county_slug'] ?? '',
      ),
      author: PostAuthor(
        id: authorData['id'] ?? 0,
        name: authorData['name'] ?? '',
        profilePhoto: authorData['profile_photo'],
        isOfficial: authorData['is_official'] ?? false,
      ),
      likesCount: statsData['likes'] ?? 0,
      commentsCount: statsData['comments'] ?? 0,
      viewsCount: statsData['views'] ?? 0,
      isLiked: statsData['is_liked'],
      createdAt: DateTime.parse(row['created_at']).toLocal(),
      humanTime: _calculateHumanTime(DateTime.parse(row['created_at']).toLocal()),
      commentsEnabled: statsData['comments_enabled'] ?? true,
      priority: authorData['priority'],
      expiresAt: row['expires_at'] != null
        ? DateTime.parse(row['expires_at'])
        : null,
      isPinned: statsData['is_pinned'] ?? false,
      localId: row['id'],
      serverId: row['server_id'],
      isLocal: row['is_local'] == 1,
      syncStatus: row['sync_status'] ?? 'synced',
    );
  }

  static String _calculateHumanTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 5) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'media_urls': mediaUrls,
      'county': county?.toJson(),
      'author': author.toJson(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'views_count': viewsCount,
      'is_liked': isLiked,
      'created_at': createdAt.toIso8601String(),
      'human_time': humanTime,
      'priority': priority,
      'expires_at': expiresAt?.toIso8601String(),
      'is_pinned': isPinned,
      'comments_enabled': commentsEnabled,
      'local_id': localId,
      'server_id': serverId,
      'is_local': isLocal,
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'server_id': serverId,
      'type': type,
      'content': content,
      'author_data': jsonEncode({
        'id': author.id,
        'name': author.name,
        'profile_photo': author.profilePhoto,
        'is_official': author.isOfficial,
        'county_id': county?.id,
        'county_name': county?.name,
        'priority': priority,
      }),
      'media_data': jsonEncode({
        'images': mediaUrls.where((url) {
          // For local files, don't filter - they're already validated when selected
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            return true; // Keep all local file paths
          }

          // For remote URLs, check for image extensions
          final lowerUrl = url.toLowerCase();
          return lowerUrl.contains('.jpg') ||
                 lowerUrl.contains('.png') ||
                 lowerUrl.contains('.jpeg') ||
                 lowerUrl.contains('.gif') ||
                 lowerUrl.contains('.webp');
        }).toList(),
        // Videos removed for MVP
      }),
      'stats_data': jsonEncode({
        'likes': likesCount,
        'comments': commentsCount,
        'views': viewsCount,
        'is_liked': isLiked,
        'is_pinned': isPinned,
        'comments_enabled': commentsEnabled,
      }),
      'is_local': isLocal ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Post copyWith({
    String? id,
    String? content,
    String? type,
    List<String>? mediaUrls,
    County? county,
    PostAuthor? author,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    bool? isLiked,
    DateTime? createdAt,
    String? humanTime,
    String? priority,
    DateTime? expiresAt,
    bool? isPinned,
    bool? commentsEnabled,
    int? localId,
    int? serverId,
    bool? isLocal,
    String? syncStatus,
    String? itemType,
    String? adType,
    String? clickUrl,
    String? advertiserName,
  }) {
    return Post(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      county: county ?? this.county,
      author: author ?? this.author,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      humanTime: humanTime ?? this.humanTime,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      isPinned: isPinned ?? this.isPinned,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      isLocal: isLocal ?? this.isLocal,
      syncStatus: syncStatus ?? this.syncStatus,
      itemType: itemType ?? this.itemType,
      adType: adType ?? this.adType,
      clickUrl: clickUrl ?? this.clickUrl,
      advertiserName: advertiserName ?? this.advertiserName,
    );
  }

  // Convenience getters
  bool get isAlert => type == 'alert';
  bool get isHighPriority => priority == 'high';
  bool get hasMedia => mediaUrls.isNotEmpty;
  bool get hasExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isPending => syncStatus == 'pending';
  bool get isSynced => syncStatus == 'synced';
  bool get isFailed => syncStatus == 'failed';

  // Ad-specific getters
  bool get isAd => itemType == 'ad';
  bool get isFeaturedAd => isAd && adType == 'featured';
  bool get isCountyAd => isAd && adType == 'county';
  bool get isNationalAd => isAd && adType == 'national';
  bool get hasClickUrl => clickUrl != null && clickUrl!.isNotEmpty;

  // Get numeric ID (strip "ad_" prefix if present)
  int? get numericId {
    try {
      if (id.startsWith('ad_')) {
        return int.parse(id.substring(3)); // Remove "ad_" prefix
      }
      return int.parse(id);
    } catch (e) {
      return null;
    }
  }

  // Always calculate fresh human time from createdAt
  String get freshHumanTime => _calculateHumanTime(createdAt);
}

class PostAuthor {
  final int id;
  final String name;
  final String? profilePhoto;
  final bool isOfficial;
  final bool isVerified; // Has active subscription (for blue checkmark)

  PostAuthor({
    required this.id,
    required this.name,
    this.profilePhoto,
    required this.isOfficial,
    this.isVerified = false,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'],
      name: json['name'] ?? '',
      profilePhoto: json['profile_photo'],
      isOfficial: json['is_official'] ?? false,
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile_photo': profilePhoto,
      'is_official': isOfficial,
      'is_verified': isVerified,
    };
  }
}