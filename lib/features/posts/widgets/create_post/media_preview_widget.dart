import 'package:flutter/material.dart';
import 'dart:io';

class MediaPreviewWidget extends StatelessWidget {
  final List<File> selectedImages;
  final File? selectedVideo;
  final Function(int) onImageRemoved;
  final VoidCallback? onVideoRemoved;

  const MediaPreviewWidget({
    super.key,
    required this.selectedImages,
    this.selectedVideo,
    required this.onImageRemoved,
    this.onVideoRemoved,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImages.isEmpty && selectedVideo == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          selectedImages[index],
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => onImageRemoved(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        if (selectedVideo != null) ...[
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onVideoRemoved,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}