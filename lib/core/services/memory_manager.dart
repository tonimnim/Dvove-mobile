import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Memory-safe caching manager with App Store compliance
/// Maximum memory budget: 50MB total (conservative for approval)
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  static MemoryManager get instance => _instance;
  MemoryManager._internal();

  // Conservative memory limits for App Store approval
  static const int _maxTotalMemory = 50 * 1024 * 1024; // 50MB total
  static const int _maxVideoThumbnails = 20; // Max 20 video thumbnails
  static const int _maxImageCache = 30; // Max 30 images in memory
  static const int _thumbnailSize = 200 * 200 * 4; // 200x200 RGBA = ~160KB

  final Map<String, _CacheEntry> _cache = {};
  int _currentMemoryUsage = 0;

  Timer? _cleanupTimer;
  final StreamController<MemoryStats> _statsController = StreamController.broadcast();

  /// Memory statistics stream for monitoring
  Stream<MemoryStats> get memoryStats => _statsController.stream;

  void initialize() {
    // Cleanup every 30 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performCleanup();
    });

    if (kDebugMode) {
      developer.log('MemoryManager initialized with ${_maxTotalMemory ~/ (1024 * 1024)}MB limit');
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    _currentMemoryUsage = 0;
    _statsController.close();
  }

  /// Store data with automatic memory management
  bool store(String key, Uint8List data, CacheType type) {
    final int dataSize = data.length;

    // Prevent storing if single item exceeds reasonable limits
    if (dataSize > _maxTotalMemory * 0.3) {
      if (kDebugMode) {
        developer.log('MemoryManager: Rejecting oversized item $key (${dataSize ~/ 1024}KB)');
      }
      return false;
    }

    // Make space if needed
    _makeSpace(dataSize, type);

    // Store the data
    final entry = _CacheEntry(
      data: data,
      type: type,
      accessTime: DateTime.now(),
      size: dataSize,
    );

    _cache[key] = entry;
    _currentMemoryUsage += dataSize;

    _broadcastStats();

    if (kDebugMode) {
      developer.log('MemoryManager: Stored $key (${dataSize ~/ 1024}KB) - Total: ${_currentMemoryUsage ~/ 1024}KB');
    }

    return true;
  }

  /// Retrieve data and update access time
  Uint8List? retrieve(String key) {
    final entry = _cache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now(); // Update LRU
      return entry.data;
    }
    return null;
  }

  /// Check if item exists in cache
  bool contains(String key) => _cache.containsKey(key);

  /// Remove specific item
  void remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentMemoryUsage -= entry.size;
      _broadcastStats();
    }
  }

  /// Make space for new data using intelligent eviction
  void _makeSpace(int neededSize, CacheType type) {
    while (_currentMemoryUsage + neededSize > _maxTotalMemory) {
      final victims = _selectEvictionVictims(type);
      if (victims.isEmpty) break;

      for (final key in victims) {
        remove(key);
      }
    }

    // Type-specific limits
    _enforceTypeLimits(type);
  }

  /// Select items for eviction using hybrid strategy
  List<String> _selectEvictionVictims(CacheType requestingType) {
    if (_cache.isEmpty) return [];

    final entries = _cache.entries.toList();

    // Sort by access time (LRU first)
    entries.sort((a, b) => a.value.accessTime.compareTo(b.value.accessTime));

    final victims = <String>[];

    // Prioritize evicting different types first to make space
    for (final entry in entries) {
      if (entry.value.type != requestingType) {
        victims.add(entry.key);
        if (victims.length >= 5) break; // Evict in small batches
      }
    }

    // If still need space, evict same type (LRU)
    if (victims.length < 3 && entries.isNotEmpty) {
      for (final entry in entries) {
        if (!victims.contains(entry.key)) {
          victims.add(entry.key);
          if (victims.length >= 3) break;
        }
      }
    }

    return victims;
  }

  /// Enforce type-specific limits
  void _enforceTypeLimits(CacheType type) {
    final typeEntries = _cache.entries
        .where((e) => e.value.type == type)
        .toList();

    int maxForType;
    switch (type) {
      case CacheType.videoThumbnail:
        maxForType = _maxVideoThumbnails;
        break;
      case CacheType.image:
        maxForType = _maxImageCache;
        break;
      case CacheType.avatar:
        maxForType = 50; // Allow more avatars (smaller)
        break;
    }

    if (typeEntries.length > maxForType) {
      // Sort by access time and remove oldest
      typeEntries.sort((a, b) => a.value.accessTime.compareTo(b.value.accessTime));

      final toRemove = typeEntries.length - maxForType;
      for (int i = 0; i < toRemove; i++) {
        remove(typeEntries[i].key);
      }
    }
  }

  /// Periodic cleanup of stale entries
  void _performCleanup() {
    final now = DateTime.now();
    final staleThreshold = now.subtract(const Duration(minutes: 10));

    final staleKeys = _cache.entries
        .where((e) => e.value.accessTime.isBefore(staleThreshold))
        .map((e) => e.key)
        .toList();

    for (final key in staleKeys) {
      remove(key);
    }

    _broadcastStats();

    if (kDebugMode && staleKeys.isNotEmpty) {
      developer.log('MemoryManager: Cleaned up ${staleKeys.length} stale entries');
    }
  }

  void _broadcastStats() {
    final stats = MemoryStats(
      currentUsage: _currentMemoryUsage,
      maxUsage: _maxTotalMemory,
      totalItems: _cache.length,
      videoThumbnails: _cache.values.where((e) => e.type == CacheType.videoThumbnail).length,
      images: _cache.values.where((e) => e.type == CacheType.image).length,
      avatars: _cache.values.where((e) => e.type == CacheType.avatar).length,
    );

    _statsController.add(stats);
  }

  /// Get current memory statistics
  MemoryStats getStats() {
    return MemoryStats(
      currentUsage: _currentMemoryUsage,
      maxUsage: _maxTotalMemory,
      totalItems: _cache.length,
      videoThumbnails: _cache.values.where((e) => e.type == CacheType.videoThumbnail).length,
      images: _cache.values.where((e) => e.type == CacheType.image).length,
      avatars: _cache.values.where((e) => e.type == CacheType.avatar).length,
    );
  }
}

class _CacheEntry {
  final Uint8List data;
  final CacheType type;
  DateTime accessTime;
  final int size;

  _CacheEntry({
    required this.data,
    required this.type,
    required this.accessTime,
    required this.size,
  });
}

enum CacheType {
  videoThumbnail,
  image,
  avatar,
}

class MemoryStats {
  final int currentUsage;
  final int maxUsage;
  final int totalItems;
  final int videoThumbnails;
  final int images;
  final int avatars;

  MemoryStats({
    required this.currentUsage,
    required this.maxUsage,
    required this.totalItems,
    required this.videoThumbnails,
    required this.images,
    required this.avatars,
  });

  double get usagePercentage => (currentUsage / maxUsage * 100).clamp(0, 100);

  String get formattedUsage => '${(currentUsage / (1024 * 1024)).toStringAsFixed(1)}MB';
  String get formattedMax => '${(maxUsage / (1024 * 1024)).toStringAsFixed(1)}MB';

  @override
  String toString() {
    return 'MemoryStats(usage: $formattedUsage/$formattedMax, '
           'items: $totalItems, videos: $videoThumbnails, images: $images, avatars: $avatars)';
  }
}