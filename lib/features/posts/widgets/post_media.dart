import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'memory_optimized_image.dart';

class PostMedia extends StatelessWidget {
  final List<String> mediaUrls;

  const PostMedia({
    super.key,
    required this.mediaUrls,
  });

  @override
  Widget build(BuildContext context) {
    print('PostMedia: mediaUrls = $mediaUrls');
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    final count = mediaUrls.length;

    if (count == 1) {
      return _buildSingleImage(context, mediaUrls[0]);
    }

    // Instagram-style carousel for multiple images
    return _buildImageCarousel(context);
  }

  Widget _buildSingleImage(BuildContext context, String url) {
    // Check if it's a local file path or network URL
    final isLocalFile = !url.startsWith('http://') && !url.startsWith('https://');

    // For local files, check if file exists before trying to display
    if (isLocalFile) {
      final file = File(url);
      if (!file.existsSync()) {
        return Container(
          height: 200,
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Image file no longer exists', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }
    }

    return GestureDetector(
      onTap: () => _openFullscreen(context, 0),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isLocalFile
            ? Image.file(
                File(url),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading local image $url: $error');
                  return Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
              )
            : MemoryOptimizedImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                maxWidth: 600, // Reduced from 800 for memory efficiency
                maxHeight: 600,
                placeholder: Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                ),
                errorWidget: Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    final PageController pageController = PageController();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.35,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                // Prevent parent scroll when interacting with PageView
                return true;
              },
              child: PageView.builder(
                controller: pageController,
                itemCount: mediaUrls.length,
                itemBuilder: (context, index) {
                final url = mediaUrls[index];
                final isLocalFile = !url.startsWith('http://') && !url.startsWith('https://');

                // For local files, check if file exists
                if (isLocalFile && !File(url).existsSync()) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Image file no longer exists', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => _openFullscreen(context, index),
                  child: isLocalFile
                    ? Image.file(
                        File(url),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      )
                    : MemoryOptimizedImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        maxWidth: 500, // Carousel images can be smaller
                        maxHeight: 400,
                        placeholder: Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: Colors.grey.shade200,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                );
              },
              ),
            ),
          ),
          // Page indicators (dots)
          if (mediaUrls.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _buildPageIndicator(pageController),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(PageController pageController) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            mediaUrls.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    // TODO: Implement fullscreen gallery
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenGallery(
          mediaUrls: mediaUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// Simple fullscreen gallery
class _FullscreenGallery extends StatelessWidget {
  final List<String> mediaUrls;
  final int initialIndex;

  const _FullscreenGallery({
    required this.mediaUrls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: mediaUrls.length,
            itemBuilder: (context, index) {
              final url = mediaUrls[index];
              final isLocalFile = !url.startsWith('http://') && !url.startsWith('https://');

              return InteractiveViewer(
                child: Center(
                  child: isLocalFile
                    ? Image.file(
                        File(url),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                          ),
                        ),
                      ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}