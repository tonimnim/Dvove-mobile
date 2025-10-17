import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/posts_service.dart';
import '../services/official_posts_service.dart';
import '../services/featured_ad_service.dart';
import '../database/posts_database.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/echo_service.dart';

class PostsProvider extends ChangeNotifier {
  final PostsService _postsService;
  final OfficialPostsService _officialPostsService;
  final FeaturedAdService _featuredAdService;
  final PostsDatabase _database = PostsDatabase.instance;
  final AuthService _authService = AuthService();
  Timer? _syncTimer;

  PostsProvider({PostsService? postsService, OfficialPostsService? officialPostsService, FeaturedAdService? featuredAdService})
      : _postsService = postsService ?? PostsService(),
        _officialPostsService = officialPostsService ?? OfficialPostsService(),
        _featuredAdService = featuredAdService ?? FeaturedAdService() {
    _startBackgroundSync();
    _initializeFeaturedAds();
  }
  final Map<String, List<Post>> _postsByType = {};
  final Map<String, int> _pageByType = {};
  final Map<String, bool> _hasMoreByType = {};
  final Map<String, bool> _isLoadingByType = {};

  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _currentType;

  final Map<int, double> _uploadProgress = {};
  bool _isProcessingPost = false;
  Function(bool success, String message)? onSyncComplete;

  final Set<String> _subscribedChannels = {};
  int? _currentCountyId;
  String? _currentScope;
  List<Post> get posts => _getPostsForType(_currentType);
  List<Post> get postsWithFeaturedAd {
    final featuredAd = _featuredAdService.featuredAd;
    final currentPosts = _getPostsForType(_currentType);
    if (featuredAd != null) {
      return [featuredAd, ...currentPosts];
    }
    return currentPosts;
  }

  // Get posts for a specific feed type (used by PostsFeed widgets)
  List<Post> getPostsForFeed(String? type, {String? excludeType}) {
    final featuredAd = _featuredAdService.featuredAd;
    var feedPosts = _getPostsForType(type);

    // Apply excludeType filter if provided
    if (excludeType != null) {
      feedPosts = feedPosts.where((post) => post.type != excludeType).toList();
    }

    // Only add featured ad to home feed (type == null), not to Jobs tab
    if (featuredAd != null && type == null) {
      return [featuredAd, ...feedPosts];
    }
    return feedPosts;
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasMoreData => _hasMoreByType[_getFeedKey(_currentType)] ?? true;
  String? get errorMessage => _errorMessage;
  Post? get featuredAd => _featuredAdService.featuredAd;

  String _getFeedKey(String? type) => type ?? 'all';

  List<Post> _getPostsForType(String? type) {
    final key = _getFeedKey(type);
    return _postsByType[key] ?? [];
  }

  void _setPostsForType(String? type, List<Post> posts) {
    final key = _getFeedKey(type);
    _postsByType[key] = posts;
  }

  int _getCurrentPage(String? type) {
    final key = _getFeedKey(type);
    return _pageByType[key] ?? 1;
  }

  void _setCurrentPage(String? type, int page) {
    final key = _getFeedKey(type);
    _pageByType[key] = page;
  }

  double getUploadProgress(int localId) => _uploadProgress[localId] ?? 0.0;

  void _startBackgroundSync() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(Duration(minutes: 10), (_) {
      if (_isProcessingPost) {
        return;
      }
      // Background sync should maintain the current feed's filters
      // Don't sync in background - let each feed handle its own refresh
      // This prevents mixing job posts into home feed
    });
  }

  void _initializeFeaturedAds() {
    _featuredAdService.checkFeaturedAdOnStartup().then((_) {
      if (_featuredAdService.featuredAd != null) {
        notifyListeners();
      }
    });
  }

  Future<void> subscribeToPostDeletions({int? countyId, String? scope}) async {
    // Unsubscribe from previous channels if county/scope changed
    if (countyId != _currentCountyId || scope != _currentScope) {
      await _unsubscribeFromAllChannels();
    }

    _currentCountyId = countyId;
    _currentScope = scope;

    await EchoService.connect();

    // Subscribe to appropriate channel based on scope
    String channelName;
    if (scope == 'county' && countyId != null) {
      channelName = 'county.$countyId.posts';
    } else {
      channelName = 'national.posts';
    }

    if (_subscribedChannels.contains(channelName)) {
      return;
    }

    await EchoService.subscribe(channelName);
    _subscribedChannels.add(channelName);

    EchoService.listen(channelName, 'post.deleted', (data) {
      try {
        final Map<String, dynamic> eventData = data is String ? jsonDecode(data) : data;
        final postId = eventData['post_id'];

        if (postId != null) {
          removePostById(postId.toString());
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing post.deleted event: $e');
        }
      }
    });
  }

  Future<void> _unsubscribeFromAllChannels() async {
    for (String channelName in _subscribedChannels) {
      EchoService.stopListening(channelName, 'post.deleted');
      await EchoService.unsubscribe(channelName);
    }
    _subscribedChannels.clear();
  }

  void removePostById(String postId) {
    bool postRemoved = false;

    for (var key in _postsByType.keys) {
      final posts = _postsByType[key]!;
      final initialLength = posts.length;

      _postsByType[key] = posts.where((post) =>
        post.id != postId && post.serverId.toString() != postId
      ).toList();

      if (_postsByType[key]!.length < initialLength) {
        postRemoved = true;
      }
    }

    if (postRemoved) {
      // Also remove from database
      _database.deletePostByServerId(int.tryParse(postId) ?? 0);
      notifyListeners();
    }
  }

  Future<void> initializeFeed({int? countyId, String? type, String? excludeType}) async {
    final key = _getFeedKey(type);

    // Check if THIS feed is already loading (allows multiple feeds to load concurrently)
    if (_isLoadingByType[key] == true) {
      return;
    }

    _isLoadingByType[key] = true;
    _errorMessage = null;
    _setCurrentPage(type, 1);
    _currentType = type;
    notifyListeners();

    try {
      await _loadFromDatabase(type: type, excludeType: excludeType);
      await _syncWithServer(type: type, countyId: countyId, excludeType: excludeType);
    } catch (e) {
      _errorMessage = 'An error occurred while loading posts';
    } finally {
      _isLoadingByType[key] = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromDatabase({String? type, String? excludeType}) async {
    final dbPosts = await _database.getPosts(type: type, excludeType: excludeType);
    var posts = dbPosts.map((row) => Post.fromDatabase(row)).toList();

    final localPosts = await _database.getLocalPosts();
    final pendingPosts = localPosts
        .where((p) {
          final postType = p['type'];
          // Apply type filter
          if (type != null && postType != type) return false;
          // Apply excludeType filter (CRITICAL for home feed to exclude jobs)
          if (excludeType != null && postType == excludeType) return false;
          return true;
        })
        .map((row) => Post.fromDatabase(row))
        .toList();

    posts = [...pendingPosts, ...posts];
    _setPostsForType(type, posts);
    notifyListeners();
  }

  Future<void> _syncWithServer({
    int? countyId,
    String? type,
    String? excludeType,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    try {
      final headers = forceRefresh ? {'Cache-Control': 'no-cache'} : null;

      final result = await _postsService.getPosts(
        page: 1,
        countyId: countyId,
        type: type,
        excludeType: excludeType,
        headers: headers,
      );

      if (result['success']) {
        final serverPosts = result['posts'] as List<Post>;

        // DON'T clear all posts - this would affect other feeds
        // Instead, just update the in-memory state for THIS feed
        // The database will naturally update via upserts

        final postsOnly = serverPosts.where((p) => p.itemType == 'post').toList();

        final dbMaps = postsOnly.map((p) {
          final numericId = int.tryParse(p.id);
          return {
            ...p.toDatabaseMap(),
            'server_id': numericId,
            'is_local': 0,
          };
        }).where((map) => map['server_id'] != null).toList();

        // Upsert posts without clearing (preserves posts from other feeds)
        await _database.upsertPosts(dbMaps);

        final localPosts = await _database.getLocalPosts();

        // Filter pending posts for this feed based on type AND excludeType
        final pendingPosts = localPosts
            .where((p) {
              final postType = p['type'];
              // Apply type filter
              if (type != null && postType != type) return false;
              // Apply excludeType filter
              if (excludeType != null && postType == excludeType) return false;
              return true;
            })
            .map((row) => Post.fromDatabase(row))
            .toList();

        final combinedPosts = [...pendingPosts, ...serverPosts];
        _setPostsForType(type, combinedPosts);
        notifyListeners();

        final key = _getFeedKey(type);
        _hasMoreByType[key] = result['meta']['current_page'] < result['meta']['last_page'];
        _errorMessage = null;
      }
    } catch (e) {
      if (!silent) {
        _errorMessage = 'Failed to sync with server';
      }
    }
  }

  Future<void> refreshPosts({int? countyId, String? type, String? excludeType}) async {
    if (_isProcessingPost) {
      return;
    }

    _isRefreshing = true;
    _setCurrentPage(type, 1);
    notifyListeners();

    await _syncWithServer(
      countyId: countyId,
      type: type,
      excludeType: excludeType,
      forceRefresh: true,
    );

    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> loadMorePosts({int? countyId, String? type, String? excludeType}) async {
    final key = _getFeedKey(type);
    final hasMore = _hasMoreByType[key] ?? true;

    if (_isLoading || !hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final currentPage = _getCurrentPage(type);
      final result = await _postsService.getPosts(
        page: currentPage + 1,
        countyId: countyId,
        type: type,
        excludeType: excludeType,
      );

      if (result['success']) {
        final newPosts = result['posts'] as List<Post>;

        final dbMaps = newPosts.map((p) => {
          ...p.toDatabaseMap(),
          'server_id': p.id,
          'is_local': 0,
        }).toList();
        await _database.upsertPosts(dbMaps);

        final currentPosts = _getPostsForType(type);
        _setPostsForType(type, [...currentPosts, ...newPosts]);
        _setCurrentPage(type, currentPage + 1);
        _hasMoreByType[key] = result['meta']['current_page'] < result['meta']['last_page'];
        _errorMessage = null;

        await _database.deleteOldPosts(100);
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> createPostOptimistic({
    required String content,
    required String type,
    String? scope,
    List<String>? imagePaths,
    DateTime? expiresAt,
    String? priority,
    bool commentsEnabled = true,
  }) async {
    if (_isProcessingPost) {
      return null;
    }

    _isProcessingPost = true;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _isProcessingPost = false;
        return null;
      }

      final now = DateTime.now();
      final currentPosts = _getPostsForType(type);
      final hasDuplicateRecentPost = currentPosts.any((post) {
        final timeDiff = now.difference(post.createdAt).inSeconds;
        return (post.isLocal || post.syncStatus == 'pending') &&
               post.author.id == user.id &&
               post.content == content &&
               timeDiff < 30;
      });

      if (hasDuplicateRecentPost) {
        _isProcessingPost = false;
        return null;
      }

      List<String> localMediaPaths = [];
      if (imagePaths != null) localMediaPaths.addAll(imagePaths);

      final localPost = Post(
        id: 'local_${now.millisecondsSinceEpoch}',
        content: content,
        type: type,
        mediaUrls: localMediaPaths,
        county: user.county!,
        author: PostAuthor(
          id: user.id,
          name: user.name,
          profilePhoto: user.profilePhoto,
          isOfficial: user.isOfficial,
        ),
        likesCount: 0,
        commentsCount: 0,
        viewsCount: 0,
        createdAt: now,
        humanTime: 'now',
        commentsEnabled: commentsEnabled,
        expiresAt: expiresAt,
        priority: priority,
        isLocal: true,
        syncStatus: 'pending',
      );

      final dbMap = localPost.toDatabaseMap();
      final localId = await _database.insertPost(dbMap);

      final postWithLocalId = localPost.copyWith(localId: localId);

      // Add to ALL relevant feeds
      // 1. Add to the specific type feed (e.g., 'job' feed)
      final existingPosts = _getPostsForType(type);
      _setPostsForType(type, [postWithLocalId, ...existingPosts]);

      // 2. If it's NOT a job post, also add to the home feed (type=null/'all')
      if (type != 'job') {
        final homeFeedKey = _getFeedKey(null);
        final homePosts = _postsByType[homeFeedKey] ?? [];
        _postsByType[homeFeedKey] = [postWithLocalId, ...homePosts];
      }

      notifyListeners();

      _syncPostToServer(localId, {
        'content': content,
        'type': type,
        'scope': scope,
        'image_paths': imagePaths,
        'expires_at': expiresAt?.toIso8601String(),
        'priority': priority,
        'comments_enabled': commentsEnabled,
      });

      Timer(Duration(seconds: 30), () {
        if (_isProcessingPost) {
          _isProcessingPost = false;
        }
      });

      return postWithLocalId;
    } catch (e) {
      _isProcessingPost = false;
      return null;
    }
  }

  Future<void> _syncPostToServer(int localId, Map<String, dynamic> postData) async {
    await _syncWithRetry(localId, postData, 0);
  }

  Future<void> _syncWithRetry(int localId, Map<String, dynamic> postData, int attempt) async {
    try {
      List<File>? imageFiles;
      if (postData['image_paths'] != null) {
        imageFiles = (postData['image_paths'] as List<String>)
          .map((path) => File(path))
          .toList();
      }

      final result = await _officialPostsService.createPost(
        content: postData['content'],
        type: postData['type'],
        scope: postData['scope'],
        priority: postData['priority'],
        expiresAt: postData['expires_at'] != null
          ? DateTime.parse(postData['expires_at'])
          : null,
        images: imageFiles,
        commentsEnabled: postData['comments_enabled'] ?? true,
        onProgress: (progress) {
          _uploadProgress[localId] = progress;
          notifyListeners();
        },
      ).timeout(
        Duration(seconds: 20),
        onTimeout: () {
          return {'success': false, 'message': AppConfig.errorMessages['timeout']!};
        },
      );

      if (result['success'] && result['post'] != null) {
        final serverPost = result['post'] as Post;

        await _database.updatePost(localId, {
          'server_id': serverPost.id,
          'sync_status': 'synced',
          'media_data': jsonEncode({
            'images': serverPost.mediaUrls.where((url) {
              final lowerUrl = url.toLowerCase();
              return lowerUrl.contains('.jpg') ||
                     lowerUrl.contains('.png') ||
                     lowerUrl.contains('.jpeg') ||
                     lowerUrl.contains('.gif') ||
                     lowerUrl.contains('.webp');
            }).toList(),
            'videos': serverPost.mediaUrls.where((url) {
              final lowerUrl = url.toLowerCase();
              return lowerUrl.contains('.mp4') ||
                     lowerUrl.contains('.mov') ||
                     lowerUrl.contains('.avi') ||
                     lowerUrl.contains('.webm') ||
                     lowerUrl.contains('/stream/video/') ||
                     lowerUrl.contains('/api/v1/stream/video/');
            }).toList(),
          }),
        });

        for (var entry in _postsByType.entries) {
          final index = entry.value.indexWhere((p) => p.localId == localId);
          if (index != -1) {
            _postsByType[entry.key]![index] = serverPost.copyWith(
              localId: localId,
              isLocal: false,
              syncStatus: 'synced',
            );
          }
        }
        notifyListeners();

        _uploadProgress.remove(localId);
        _isProcessingPost = false;

        if (onSyncComplete != null) {
          onSyncComplete!(true, 'Posted successfully!');
        }
      } else {
        await _deleteFailedPost(localId);
        _uploadProgress.remove(localId);
        _isProcessingPost = false;

        if (onSyncComplete != null) {
          onSyncComplete!(false, 'Failed to post. Try again.');
        }
      }
    } catch (e) {
      await _deleteFailedPost(localId);
      _uploadProgress.remove(localId);
      _isProcessingPost = false;

      if (onSyncComplete != null) {
        onSyncComplete!(false, 'Failed to post. Try again.');
      }
    }
  }

  Future<void> _deleteFailedPost(int localId) async {
    await _database.deletePost(localId);

    for (var key in _postsByType.keys) {
      _postsByType[key]?.removeWhere((p) => p.localId == localId);
    }
    notifyListeners();
  }

  void removePost(String postId) {
    for (var key in _postsByType.keys) {
      _postsByType[key]?.removeWhere((post) => post.id == postId || post.serverId.toString() == postId);
    }
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    Post? foundPost;
    String? foundKey;
    int? foundIndex;

    for (var entry in _postsByType.entries) {
      final index = entry.value.indexWhere((post) => post.id == postId || post.serverId.toString() == postId);
      if (index != -1) {
        foundPost = entry.value[index];
        foundKey = entry.key;
        foundIndex = index;
        break;
      }
    }

    if (foundPost == null || foundKey == null || foundIndex == null) return;

    final wasLiked = foundPost.isLiked ?? false;
    final currentLikes = foundPost.likesCount;

    _postsByType[foundKey]![foundIndex] = foundPost.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? currentLikes - 1 : currentLikes + 1,
    );
    notifyListeners();

    try {
      final result = wasLiked
        ? await _postsService.unlikePost(postId)
        : await _postsService.likePost(postId);

      if (result['success']) {
        _postsByType[foundKey]![foundIndex] = _postsByType[foundKey]![foundIndex].copyWith(
          isLiked: result['is_liked'],
          likesCount: result['likes_count'],
        );
        notifyListeners();
      } else {
        _postsByType[foundKey]![foundIndex] = foundPost;
        notifyListeners();
      }
    } catch (e) {
      _postsByType[foundKey]![foundIndex] = foundPost;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> addComment(String postId, String content) async {
    try {
      final result = await _postsService.addComment(postId, content);
      return result['success'] ? result : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> reportPost(int postId, String reason, String? description) async{
    try {
      final result = await _postsService.reportPost(postId, reason, description);
      return result['success'];
    } catch (e) {
      return false;
    }
  }

  void insertAlert(Post alertPost) {
    for (var key in _postsByType.keys) {
      final posts = _postsByType[key]!;
      if (alertPost.isAlert && alertPost.isHighPriority) {
        posts.insert(0, alertPost);
      } else if (alertPost.isAlert) {
        int insertIndex = 0;
        for (int i = 0; i < posts.length; i++) {
          if (!posts[i].isAlert || !posts[i].isHighPriority) {
            insertIndex = i;
            break;
          }
        }
        posts.insert(insertIndex, alertPost);
      }
    }
    notifyListeners();
  }

  void clearPosts() {
    _postsByType.clear();
    _pageByType.clear();
    _hasMoreByType.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> clearCache() async {
    _postsByType.clear();
    _pageByType.clear();
    _hasMoreByType.clear();
    _isLoading = false;
    _isRefreshing = false;
    _errorMessage = null;
    _currentType = null;
    _uploadProgress.clear();
    _isProcessingPost = false;

    await _database.clearAllPosts();

    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _unsubscribeFromAllChannels();
    super.dispose();
  }
}