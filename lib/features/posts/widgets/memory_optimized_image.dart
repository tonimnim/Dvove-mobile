import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/services/intelligent_cache_service.dart';
import '../../../core/services/memory_manager.dart';
import '../../../core/config/app_config.dart';

/// Memory-optimized image widget with intelligent caching
/// Replacement for CachedNetworkImage with strict memory management
class MemoryOptimizedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? maxWidth;
  final int? maxHeight;
  final CacheType cacheType;

  const MemoryOptimizedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.maxWidth = 400,
    this.maxHeight = 400,
    this.cacheType = CacheType.image,
  });

  @override
  State<MemoryOptimizedImage> createState() => _MemoryOptimizedImageState();
}

class _MemoryOptimizedImageState extends State<MemoryOptimizedImage>
    with AutomaticKeepAliveClientMixin {

  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => _imageData != null; // Keep alive if image loaded

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(MemoryOptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageData = null;
      _isLoading = true;
      _hasError = false;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    try {
      final data = await IntelligentCacheService.instance.getImage(
        widget.imageUrl,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        type: widget.cacheType,
      );

      if (mounted) {
        setState(() {
          _imageData = data;
          _isLoading = false;
          _hasError = data == null;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return _buildPlaceholder();
    }

    if (_hasError || _imageData == null) {
      return _buildErrorWidget();
    }

    return Image.memory(
      _imageData!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true, // Smooth transitions
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 32, color: Colors.grey),
          SizedBox(height: 4),
          Text(
            'Failed to load',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Image data is managed by MemoryManager, no manual cleanup needed
    super.dispose();
  }
}

/// Specialized avatar widget with aggressive memory optimization
class MemoryOptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double size;

  const MemoryOptimizedAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade300,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? MemoryOptimizedImage(
                imageUrl: AppConfig.fixMediaUrl(imageUrl!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                maxWidth: (size * 2).toInt(), // 2x for retina displays
                maxHeight: (size * 2).toInt(),
                cacheType: CacheType.avatar,
                errorWidget: _buildFallback(),
                placeholder: _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Preloading image container for feed optimization
class PreloadingImageContainer extends StatefulWidget {
  final List<String> imageUrls;
  final Widget child;
  final int preloadDistance;

  const PreloadingImageContainer({
    super.key,
    required this.imageUrls,
    required this.child,
    this.preloadDistance = 3,
  });

  @override
  State<PreloadingImageContainer> createState() => _PreloadingImageContainerState();
}

class _PreloadingImageContainerState extends State<PreloadingImageContainer> {
  bool _hasPreloaded = false;

  @override
  void initState() {
    super.initState();
    // Delay preloading to not interfere with initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImages();
    });
  }

  Future<void> _preloadImages() async {
    if (_hasPreloaded || !mounted) return;

    _hasPreloaded = true;

    // Check memory usage before preloading
    final stats = IntelligentCacheService.instance.getCacheStats();
    if (stats.usagePercentage > 80) {
      return; // Skip preloading if memory usage is high
    }

    await IntelligentCacheService.instance.preloadImages(
      widget.imageUrls,
      maxPreload: widget.preloadDistance,
      type: CacheType.image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}