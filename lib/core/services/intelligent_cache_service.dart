import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'memory_manager.dart';
import '../config/app_config.dart';

/// Intelligent caching service with memory-safe preloading
class IntelligentCacheService {
  static final IntelligentCacheService _instance = IntelligentCacheService._internal();
  static IntelligentCacheService get instance => _instance;
  IntelligentCacheService._internal();

  final Dio _dio = Dio();
  final Map<String, Completer<Uint8List?>> _activeDownloads = {};
  final Set<String> _preloadQueue = {};

  /// Initialize the cache service
  void initialize() {
    MemoryManager.instance.initialize();

    _dio.options = BaseOptions(
      // Use longer timeouts for image downloads (especially large images)
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: AppConfig.defaultHeaders,
      // Disable redirects to avoid issues
      followRedirects: true,
      maxRedirects: 3,
    );

    if (kDebugMode) {
      debugPrint('IntelligentCacheService initialized with extended timeouts');
    }
  }

  /// Get image with intelligent caching and resizing
  Future<Uint8List?> getImage(String url, {
    int? maxWidth = 400,
    int? maxHeight = 400,
    CacheType type = CacheType.image,
  }) async {
    final cacheKey = _generateCacheKey(url, maxWidth, maxHeight);

    // Check memory cache first
    final cachedData = MemoryManager.instance.retrieve(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // Check if already downloading
    if (_activeDownloads.containsKey(cacheKey)) {
      return await _activeDownloads[cacheKey]!.future;
    }

    // Start download
    final completer = Completer<Uint8List?>();
    _activeDownloads[cacheKey] = completer;

    try {
      final processedData = await _downloadAndProcessImage(url, maxWidth, maxHeight, type);

      if (processedData != null) {
        // Store in memory cache
        MemoryManager.instance.store(cacheKey, processedData, type);
      }

      completer.complete(processedData);
      return processedData;

    } catch (e) {
      print('Error downloading image $url: $e');

      if (e is DioException) {
        print('DioException details: type=${e.type}, message=${e.message}');
        if (e.response != null) {
          print('Response status: ${e.response?.statusCode}');
        }
      }

      completer.complete(null);
      return null;
    } finally {
      _activeDownloads.remove(cacheKey);
    }
  }

  /// Generate video thumbnail with memory management
  Future<Uint8List?> getVideoThumbnail(String videoUrl) async {
    final cacheKey = 'thumb_$videoUrl';

    // Check cache first
    final cached = MemoryManager.instance.retrieve(cacheKey);
    if (cached != null) return cached;

    // For demo purposes, create a simple placeholder
    // In production, you'd extract actual video frame
    try {
      final thumbnailData = await _generateVideoThumbnailPlaceholder();
      if (thumbnailData != null) {
        MemoryManager.instance.store(cacheKey, thumbnailData, CacheType.videoThumbnail);
      }
      return thumbnailData;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating video thumbnail: $e');
      }
      return null;
    }
  }

  /// Preload next items intelligently
  Future<void> preloadImages(List<String> urls, {
    int maxPreload = 3,
    CacheType type = CacheType.image,
  }) async {
    if (urls.isEmpty) return;

    // Limit concurrent preloads based on memory usage
    final stats = MemoryManager.instance.getStats();
    final maxConcurrent = stats.usagePercentage > 70 ? 1 :
                         stats.usagePercentage > 50 ? 2 : 3;

    final preloadUrls = urls.take(maxPreload).where((url) {
      final cacheKey = _generateCacheKey(url, 400, 400);
      return !MemoryManager.instance.contains(cacheKey) &&
             !_preloadQueue.contains(cacheKey);
    }).toList();

    // Process preloads in batches
    for (int i = 0; i < preloadUrls.length; i += maxConcurrent) {
      final batch = preloadUrls.skip(i).take(maxConcurrent).toList();

      await Future.wait(
        batch.map((url) => _preloadSingleImage(url, type)),
      );

      // Small delay between batches to prevent overwhelming
      if (i + maxConcurrent < preloadUrls.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _preloadSingleImage(String url, CacheType type) async {
    final cacheKey = _generateCacheKey(url, 400, 400);

    if (_preloadQueue.contains(cacheKey)) return;
    _preloadQueue.add(cacheKey);

    try {
      await getImage(url, maxWidth: 400, maxHeight: 400, type: type);
    } finally {
      _preloadQueue.remove(cacheKey);
    }
  }

  /// Download and process image with memory-efficient resizing
  Future<Uint8List?> _downloadAndProcessImage(
    String url,
    int? maxWidth,
    int? maxHeight,
    CacheType type,
  ) async {
    try {
      final fixedUrl = AppConfig.fixMediaUrl(url);

      print('Error downloading image $fixedUrl: Attempting download...');

      final response = await _dio.get<List<int>>(
        fixedUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      print('Successfully downloaded image: $fixedUrl (${response.data?.length} bytes)');

      if (response.data == null) return null;

      final originalData = Uint8List.fromList(response.data!);

      // Skip processing for avatars (keep small)
      if (type == CacheType.avatar) {
        return originalData;
      }

      // Resize image to save memory
      return await _resizeImage(originalData, maxWidth, maxHeight);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error downloading image $url: $e');
      }
      return null;
    }
  }

  /// Memory-efficient image resizing
  Future<Uint8List?> _resizeImage(Uint8List data, int? maxWidth, int? maxHeight) async {
    try {
      // Only specify width to maintain aspect ratio
      // Flutter will automatically calculate the height
      final codec = await ui.instantiateImageCodec(
        data,
        targetWidth: maxWidth,
        // Don't specify targetHeight - let Flutter maintain aspect ratio
      );

      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return data;

      return byteData.buffer.asUint8List();

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error resizing image: $e');
      }
      return data; // Return original if resize fails
    }
  }

  /// Generate video thumbnail placeholder
  Future<Uint8List?> _generateVideoThumbnailPlaceholder() async {
    try {
      // Create a 200x200 thumbnail placeholder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(200, 200);

      // Draw gradient background
      final gradient = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [Colors.grey.shade300, Colors.grey.shade500],
      );

      final paint = Paint()..shader = gradient;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Draw play icon
      final playPaint = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.fill;

      final playPath = Path();
      final center = Offset(size.width / 2, size.height / 2);
      final playSize = 40.0;

      playPath.moveTo(center.dx - playSize / 3, center.dy - playSize / 2);
      playPath.lineTo(center.dx + playSize / 2, center.dy);
      playPath.lineTo(center.dx - playSize / 3, center.dy + playSize / 2);
      playPath.close();

      canvas.drawPath(playPath, playPaint);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating thumbnail placeholder: $e');
      }
      return null;
    }
  }

  /// Generate cache key with size parameters
  String _generateCacheKey(String url, int? width, int? height) {
    return 'img_${url.hashCode}_${width}_$height';
  }

  /// Clear all caches (useful for testing)
  void clearCache() {
    _activeDownloads.clear();
    _preloadQueue.clear();
    // Note: MemoryManager has its own cleanup
  }

  /// Get cache statistics
  MemoryStats getCacheStats() {
    return MemoryManager.instance.getStats();
  }

  void dispose() {
    _activeDownloads.clear();
    _preloadQueue.clear();
    MemoryManager.instance.dispose();
  }
}