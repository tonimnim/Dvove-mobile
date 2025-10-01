import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/posts_service.dart';
import '../services/official_posts_service.dart';
import '../services/featured_ad_service.dart';
import '../database/posts_database.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/post_analytics.dart';

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

  // State
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMoreData = true;
  String? _errorMessage;
  int _currentPage = 1;
  String? _currentType;
  int? _currentCountyId;

  // Upload progress tracking
  final Map<int, double> _uploadProgress = {};

  // Simple queue to prevent multiple concurrent posts
  bool _isProcessingPost = false;

  // Callback for sync results
  Function(bool success, String message)? onSyncComplete;

  // Getters
  List<Post> get posts => _posts;
  List<Post> get postsWithFeaturedAd {
    final featuredAd = _featuredAdService.featuredAd;
    if (featuredAd != null) {
      return [featuredAd, ..._posts];
    }
    return _posts;
  }
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasMoreData => _hasMoreData;
  String? get errorMessage => _errorMessage;
  Post? get featuredAd => _featuredAdService.featuredAd;

  double getUploadProgress(int localId) => _uploadProgress[localId] ?? 0.0;

  void _startBackgroundSync() {
    // Cancel any existing timer first
    _syncTimer?.cancel();

    print('[PostsProvider] Starting background sync timer (10 min interval - optimized for backend 30min cache)');
    _syncTimer = Timer.periodic(Duration(minutes: 10), (_) {
      // Skip sync if we're processing a post
      if (_isProcessingPost) {
        print('[PostsProvider] Background sync skipped - post in progress');
        return;
      }
      print('[PostsProvider] 🔄 Background sync triggered (10 min interval)');
      _syncWithServer(silent: true);
    });
  }

  void _initializeFeaturedAds() {
    // Check for featured ads on app startup (fire and forget)
    _featuredAdService.checkFeaturedAdOnStartup().then((_) {
      // Notify listeners if a featured ad was loaded
      if (_featuredAdService.featuredAd != null) {
        notifyListeners();
      }
    });
  }

  Future<void> initializeFeed({int? countyId, String? type}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    _currentType = type;
    _currentCountyId = countyId;
    notifyListeners();

    try {
      // Load from database first
      await _loadFromDatabase(type: type);

      // Then sync with server
      await _syncWithServer(type: type, countyId: countyId);
    } catch (e) {
      _errorMessage = 'An error occurred while loading posts';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromDatabase({String? type}) async {
    // Load server posts from database
    final dbPosts = await _database.getPosts(type: type);
    _posts = dbPosts.map((row) => Post.fromDatabase(row)).toList();

    // Add local pending posts at the top
    final localPosts = await _database.getLocalPosts();
    final pendingPosts = localPosts
        .where((p) => type == null || p['type'] == type)
        .map((row) => Post.fromDatabase(row))
        .toList();

    _posts = [...pendingPosts, ..._posts];
    notifyListeners();
  }

  Future<void> _syncWithServer({
    int? countyId,
    String? type,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    try {
      final headers = forceRefresh ? {'Cache-Control': 'no-cache'} : null;

      print('[PostsProvider] 🌐 API CALL: getPosts(page: 1, countyId: $countyId, type: $type, forceRefresh: $forceRefresh)');

      final result = await _postsService.getPosts(
        page: 1,
        countyId: countyId,
        type: type,
        headers: headers,
      );

      print('[PostsProvider] ✅ API CALL SUCCESS: Received ${result['success'] ? (result['posts'] as List).length : 0} posts');

      if (result['success']) {
        final serverPosts = result['posts'] as List<Post>;

        // Save to database
        await _database.clearRemotePosts();
        final dbMaps = serverPosts.map((p) => {
          ...p.toDatabaseMap(),
          'server_id': p.id,
          'is_local': 0,
        }).toList();
        await _database.upsertPosts(dbMaps);

        // Instead of reloading from database, directly merge in memory
        final localPosts = await _database.getLocalPosts();
        final pendingPosts = localPosts
            .where((p) => type == null || p['type'] == type)
            .map((row) => Post.fromDatabase(row))
            .toList();

        // Combine: pending posts first, then server posts
        _posts = [...pendingPosts, ...serverPosts];
        notifyListeners();

        _hasMoreData = result['meta']['current_page'] < result['meta']['last_page'];
        _errorMessage = null;
      }
    } catch (e) {
      if (!silent) {
        _errorMessage = 'Failed to sync with server';
      }
    }
  }

  Future<void> refreshPosts({int? countyId, String? type}) async {
    // Don't refresh if we're currently processing a post
    if (_isProcessingPost) {
      print('[PostsProvider] Skipping refresh - post sync in progress');
      return;
    }

    _isRefreshing = true;
    _currentPage = 1;
    notifyListeners();

    await _syncWithServer(
      countyId: countyId,
      type: type,
      forceRefresh: true,
    );

    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> loadMorePosts({int? countyId, String? type}) async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _postsService.getPosts(
        page: _currentPage + 1,
        countyId: countyId,
        type: type,
      );

      if (result['success']) {
        final newPosts = result['posts'] as List<Post>;

        // Save to database
        final dbMaps = newPosts.map((p) => {
          ...p.toDatabaseMap(),
          'server_id': p.id,
          'is_local': 0,
        }).toList();
        await _database.upsertPosts(dbMaps);

        _posts.addAll(newPosts);
        _currentPage++;
        _hasMoreData = result['meta']['current_page'] < result['meta']['last_page'];
        _errorMessage = null;

        // Keep only last 100 posts in database
        await _database.deleteOldPosts(100);
      }
    } catch (e) {
      // Silent fail for pagination
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> createPostOptimistic({
    required String content,
    required String type,
    List<String>? imagePaths,
    DateTime? expiresAt,
    String? priority,
  }) async {
    // Prevent multiple concurrent posts - CRITICAL CHECK
    if (_isProcessingPost) {
      print('[PostsProvider] CRITICAL: Multiple post attempt BLOCKED! Already processing a post. Content: "${content.substring(0, min(30, content.length))}..."');
      print('[PostsProvider] Current processing post count: ${_posts.where((p) => p.syncStatus == 'pending').length}');
      return null;
    }

    // Set flag IMMEDIATELY to prevent race conditions
    _isProcessingPost = true;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _isProcessingPost = false;
        return null;
      }

      // Check for duplicate content within last 30 seconds (prevent any double-posting)
      final now = DateTime.now();
      final hasDuplicateRecentPost = _posts.any((post) {
        final timeDiff = now.difference(post.createdAt).inSeconds;
        return (post.isLocal || post.syncStatus == 'pending') &&
               post.author.id == user.id &&
               post.content == content &&
               timeDiff < 30;
      });

      if (hasDuplicateRecentPost) {
        print('[PostsProvider] DUPLICATE PREVENTED: Same content posted within 30 seconds. Content: "${content.substring(0, min(50, content.length))}..."');
        _isProcessingPost = false;
        return null;
      }

      // Create local post

      // Store local media paths temporarily (images only)
      // We'll use these for display until synced
      List<String> localMediaPaths = [];
      if (imagePaths != null) localMediaPaths.addAll(imagePaths);

      final localPost = Post(
        id: -now.millisecondsSinceEpoch, // Temporary negative ID
        content: content,
        type: type,
        mediaUrls: localMediaPaths, // Store local paths temporarily
        county: user.county!,
        author: PostAuthor(
          id: user.id!,
          name: user.name,
          profilePhoto: user.profilePhoto,
          isOfficial: user.isOfficial ?? false,
        ),
        likesCount: 0,
        commentsCount: 0,
        viewsCount: 0,
        createdAt: now,
        humanTime: 'now',
        commentsEnabled: true,
        expiresAt: expiresAt,
        priority: priority,
        isLocal: true,
        syncStatus: 'pending',
      );

      // Save to database
      final dbMap = localPost.toDatabaseMap();
      final localId = await _database.insertPost(dbMap);

      // Add to feed immediately
      final postWithLocalId = localPost.copyWith(localId: localId);
      _posts.insert(0, postWithLocalId);
      notifyListeners();

      // Track analytics
      PostAnalytics.trackPostCreated(
        type,
        localMediaPaths.isNotEmpty,
        mediaCount: localMediaPaths.length
      );

      // Send to server in background - Keep processing flag until done
      // Note: _isProcessingPost will be reset when sync completes/fails in _syncWithRetry
      _syncPostToServer(localId, {
        'content': content,
        'type': type,
        'image_paths': imagePaths,
        'expires_at': expiresAt?.toIso8601String(),
        'priority': priority,
      });

      // Return the post but keep flag until sync completes
      // Add a delayed reset as backup in case sync fails silently
      Timer(Duration(seconds: 30), () {
        if (_isProcessingPost) {
          _isProcessingPost = false;
          print('[PostsProvider] Processing flag RESET after 30s timeout');
        }
      });

      return postWithLocalId;
    } catch (e) {
      _isProcessingPost = false;
      print('[PostsProvider] Processing flag RESET after catch error in createPostOptimistic: $e');
      return null;
    }
  }

  Future<void> _syncPostToServer(int localId, Map<String, dynamic> postData) async {
    await _syncWithRetry(localId, postData, 0);
  }

  Future<void> _syncWithRetry(int localId, Map<String, dynamic> postData, int attempt) async {
    try {
      // Convert image paths to File objects for upload
      List<File>? imageFiles;
      if (postData['image_paths'] != null) {
        imageFiles = (postData['image_paths'] as List<String>)
          .map((path) => File(path))
          .toList();
      }

      print('[PostsProvider] SYNC ATTEMPT ${attempt + 1}/5: Uploading ${imageFiles?.length ?? 0} images. Type: ${postData['type']}');

      // Track retry analytics
      if (attempt > 0) {
        PostAnalytics.trackRetry(attempt + 1, 'Network or server error');
      }

      final startTime = DateTime.now();

      // Set a 20 second timeout per attempt
      final result = await _officialPostsService.createPost(
        content: postData['content'],
        type: postData['type'],
        priority: postData['priority'],
        expiresAt: postData['expires_at'] != null
          ? DateTime.parse(postData['expires_at'])
          : null,
        images: imageFiles, // Images only for MVP
        onProgress: (progress) {
          _uploadProgress[localId] = progress;
          if (progress == 1.0) {
            print('[PostsProvider] UPLOAD COMPLETE: Post $localId finished uploading to server');
          }
          notifyListeners();
        },
      ).timeout(
        Duration(seconds: 20), // 20 second timeout per attempt
        onTimeout: () {
          return {'success': false, 'message': AppConfig.errorMessages['timeout']!};
        },
      );

      if (result['success'] && result['post'] != null) {
        final serverPost = result['post'] as Post;

        // Update database - ONLY basic fields that definitely exist
        await _database.updatePost(localId, {
          'server_id': serverPost.id,
          'sync_status': 'synced',
          'media_data': jsonEncode({
            'images': serverPost.mediaUrls.where((url) {
              final lowerUrl = url.toLowerCase();
              // Check for image file extensions
              return lowerUrl.contains('.jpg') ||
                     lowerUrl.contains('.png') ||
                     lowerUrl.contains('.jpeg') ||
                     lowerUrl.contains('.gif') ||
                     lowerUrl.contains('.webp');
            }).toList(),
            'videos': serverPost.mediaUrls.where((url) {
              final lowerUrl = url.toLowerCase();
              // Check for video file extensions OR streaming endpoints
              return lowerUrl.contains('.mp4') ||
                     lowerUrl.contains('.mov') ||
                     lowerUrl.contains('.avi') ||
                     lowerUrl.contains('.webm') ||
                     lowerUrl.contains('/stream/video/') ||
                     lowerUrl.contains('/api/v1/stream/video/');
            }).toList(),
          }),
        });

        // Update in-memory list - Simple replacement
        final index = _posts.indexWhere((p) => p.localId == localId);
        if (index != -1) {
          // Replace optimistic with server post at same position
          _posts[index] = serverPost.copyWith(
            localId: localId,
            isLocal: false,
            syncStatus: 'synced',
          );
          notifyListeners();
        }

        // Track successful sync
        final syncDuration = DateTime.now().difference(startTime);
        PostAnalytics.trackPostSynced(syncDuration, type: postData['type']);

        // Clean up and release flag - ALWAYS on success
        _uploadProgress.remove(localId);
        _isProcessingPost = false;
        print('[PostsProvider] Processing flag RESET after successful sync (localId: $localId)');

        // Notify success
        if (onSyncComplete != null) {
          onSyncComplete!(true, 'Posted successfully!');
        }
      } else {
        // Upload failed - DELETE POST COMPLETELY
        await _deleteFailedPost(localId);
        _uploadProgress.remove(localId);
        _isProcessingPost = false;

        if (onSyncComplete != null) {
          onSyncComplete!(false, 'Failed to post. Try again.');
        }
      }
    } catch (e) {
      // Upload failed - DELETE POST COMPLETELY
      await _deleteFailedPost(localId);
      _uploadProgress.remove(localId);
      _isProcessingPost = false;

      if (onSyncComplete != null) {
        onSyncComplete!(false, 'Failed to post. Try again.');
      }
    }
  }

  Future<void> _deleteFailedPost(int localId) async {
    // Remove from database
    await _database.deletePost(localId);

    // Remove from UI
    _posts.removeWhere((p) => p.localId == localId);
    notifyListeners();
  }


  void removePost(int postId) {
    _posts.removeWhere((post) => post.id == postId || post.serverId == postId);
    notifyListeners();
  }

  Future<void> toggleLike(int postId) async {
    final postIndex = _posts.indexWhere((post) => post.id == postId || post.serverId == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    final wasLiked = post.isLiked ?? false;
    final currentLikes = post.likesCount;

    // Optimistic update
    _posts[postIndex] = post.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? currentLikes - 1 : currentLikes + 1,
    );
    notifyListeners();

    try {
      final result = wasLiked
        ? await _postsService.unlikePost(postId)
        : await _postsService.likePost(postId);

      if (result['success']) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          isLiked: result['is_liked'],
          likesCount: result['likes_count'],
        );
        notifyListeners();
      } else {
        _posts[postIndex] = post;
        notifyListeners();
      }
    } catch (e) {
      _posts[postIndex] = post;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> addComment(int postId, String content) async {
    try {
      final result = await _postsService.addComment(postId, content);

      if (result['success']) {
        final postIndex = _posts.indexWhere((post) => post.id == postId || post.serverId == postId);
        if (postIndex != -1) {
          _posts[postIndex] = _posts[postIndex].copyWith(
            commentsCount: _posts[postIndex].commentsCount + 1,
          );
          notifyListeners();
        }
        return result; // Return full result with comment data
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> reportPost(int postId, String reason, String? description) async {
    try {
      final result = await _postsService.reportPost(postId, reason, description);
      return result['success'];
    } catch (e) {
      return false;
    }
  }

  void insertAlert(Post alertPost) {
    if (alertPost.isAlert && alertPost.isHighPriority) {
      _posts.insert(0, alertPost);
      notifyListeners();
    } else if (alertPost.isAlert) {
      int insertIndex = 0;
      for (int i = 0; i < _posts.length; i++) {
        if (!_posts[i].isAlert || !_posts[i].isHighPriority) {
          insertIndex = i;
          break;
        }
      }
      _posts.insert(insertIndex, alertPost);
      notifyListeners();
    }
  }

  void clearPosts() {
    _posts = [];
    _currentPage = 1;
    _hasMoreData = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _cleanupOldFailedPosts() async {
    final now = DateTime.now();
    final cutoffTime = now.subtract(Duration(minutes: 1));

    // Remove old failed posts from memory
    _posts.removeWhere((post) =>
      post.syncStatus == 'failed' &&
      post.createdAt.isBefore(cutoffTime)
    );

    // Remove old failed posts from database
    final oldFailedPosts = await _database.getLocalPosts();
    for (final row in oldFailedPosts) {
      if (row['sync_status'] == 'failed') {
        final createdAt = DateTime.parse(row['created_at']);
        if (createdAt.isBefore(cutoffTime)) {
          await _database.deletePost(row['id']);
        }
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}