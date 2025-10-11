import 'package:flutter/material.dart';
import 'dart:io';
import '../../../auth/models/user.dart';
import 'media_preview_widget.dart';

class PostContentComposer extends StatelessWidget {
  final User? user;
  final TextEditingController contentController;
  final List<File> selectedImages;
  final List<String> existingImageUrls;
  final File? selectedVideo;
  final VoidCallback onContentChanged;
  final Function(int) onImageRemoved;
  final Function(int)? onExistingImageRemoved;
  final VoidCallback? onVideoRemoved;
  final DateTime? expiresAt;
  final String selectedType;
  final VoidCallback? onSelectExpiryDate;

  const PostContentComposer({
    super.key,
    required this.user,
    required this.contentController,
    required this.selectedImages,
    this.existingImageUrls = const [],
    this.selectedVideo,
    required this.onContentChanged,
    required this.onImageRemoved,
    this.onExistingImageRemoved,
    this.onVideoRemoved,
    this.expiresAt,
    required this.selectedType,
    this.onSelectExpiryDate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content input without profile
          Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content input
                    TextField(
                      controller: contentController,
                      maxLines: null,
                      maxLength: 5000,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "What's happening?",
                        hintStyle: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: Colors.black,
                      ),
                      onChanged: (_) => onContentChanged(),
                    ),

                    // Media preview
                    MediaPreviewWidget(
                      selectedImages: selectedImages,
                      existingImageUrls: existingImageUrls,
                      selectedVideo: selectedVideo,
                      onImageRemoved: onImageRemoved,
                      onExistingImageRemoved: onExistingImageRemoved,
                      onVideoRemoved: onVideoRemoved,
                    ),
                  ],
                ),

          const SizedBox(height: 20),

          // Add extra space at bottom for scrolling
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
