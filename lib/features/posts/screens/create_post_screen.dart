import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../models/post.dart';
import '../providers/posts_provider.dart';
import '../services/posts_service.dart';
import '../widgets/create_post/post_type_selector.dart';
import '../widgets/create_post/post_content_composer.dart';
import '../../../core/utils/image_compression.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? postToEdit;

  const CreatePostScreen({super.key, this.postToEdit});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final PostsService _postsService = PostsService();
  String _selectedType = 'announcement';
  String? _priority;
  DateTime? _expiresAt;
  final List<File> _selectedImages = [];
  bool _isPosting = false;
  bool get isEditing => widget.postToEdit != null;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // If editing, pre-fill the fields
    if (isEditing) {
      _contentController.text = widget.postToEdit!.content ?? '';
      _selectedType = widget.postToEdit!.type;
      _priority = widget.postToEdit!.priority;
      _expiresAt = widget.postToEdit!.expiresAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final hasContent = _contentController.text.trim().isNotEmpty ||
        _selectedImages.isNotEmpty;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        leadingWidth: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            child: TextButton(
              onPressed: hasContent && !_isPosting ? (isEditing ? _updatePost : _createPost) : null,
              style: TextButton.styleFrom(
                backgroundColor: hasContent ? Colors.black : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? 'Update' : 'Post'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade300,
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // Post type selector with priority
          PostTypeSelector(
            selectedType: _selectedType,
            selectedPriority: _priority,
            onTypeChanged: (type) {
              setState(() {
                _selectedType = type;
                if (type == 'alert') {
                  // Default to 'low' priority for alerts
                  _priority = _priority ?? 'low';
                } else {
                  _priority = null;
                }
              });
            },
            onPriorityChanged: (priority) {
              setState(() {
                _priority = priority;
              });
            },
          ),

          // Content composer
          Expanded(
            child: PostContentComposer(
              user: user,
              contentController: _contentController,
              selectedImages: _selectedImages,
              onContentChanged: () => setState(() {}),
              onImageRemoved: (index) {
                setState(() {
                  _selectedImages.removeAt(index);
                });
              },
              expiresAt: _expiresAt,
              selectedType: _selectedType,
              onSelectExpiryDate: _selectExpiryDate,
            ),
          ),

          // Bottom toolbar
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.black),
                  onPressed: _pickImages,
                ),
                // Calendar icon for Job posts only
                if (_selectedType == 'job')
                  IconButton(
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: _expiresAt != null ? Colors.green : Colors.black,
                    ),
                    onPressed: _selectExpiryDate,
                  ),
                const Spacer(),
                // Character count
                Text(
                  '${_contentController.text.length}/5000',
                  style: TextStyle(
                    color: _contentController.text.length > 4500
                        ? Colors.orange
                        : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 images allowed'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final List<XFile> images = await _imagePicker.pickMultiImage();

    if (images.isNotEmpty) {
      // Convert XFile to File
      final List<File> imageFiles = images
          .take(4 - _selectedImages.length)
          .map((xFile) => File(xFile.path))
          .toList();

      // Compress images in parallel (efficient, no rebuilds)
      final List<File> compressedImages = await ImageCompression.compressImages(imageFiles);

      // Single setState call to avoid multiple rebuilds
      setState(() {
        _selectedImages.addAll(compressedImages);
      });
    }
  }


  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _expiresAt = picked;
      });
    }
  }


  Future<void> _updatePost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final result = await _postsService.updatePost(
        postId: widget.postToEdit!.id,
        content: content,
        type: _selectedType,
        priority: _priority,
        expiresAt: _expiresAt,
      );

      if (mounted) {
        setState(() {
          _isPosting = false;
        });

        if (result['success']) {
          Navigator.pop(context, result['post']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update post'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating post'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _createPost() async {
    // Prevent double-tap by checking flag immediately
    if (_isPosting) {
      return;
    }

    final content = _contentController.text.trim();

    // Validate content or media
    if (content.isEmpty && _selectedImages.isEmpty) {
      return;
    }

    setState(() {
      _isPosting = true;
    });

    // Get image paths
    final List<String>? imagePaths = _selectedImages.isNotEmpty
        ? _selectedImages.map((file) => file.path).toList()
        : null;

    // Get the global provider
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Use optimistic update with media (images only)
    final post = await postsProvider.createPostOptimistic(
      content: content,
      type: _selectedType,
      imagePaths: imagePaths,
      expiresAt: _selectedType == 'job' ? _expiresAt : null,
      priority: _priority,
    );

    if (mounted) {
      if (post != null) {
        // Navigate back to home screen immediately with the new post
        Navigator.pop(context, post); // Return the post object

        // Reset posting flag AFTER navigation
        setState(() {
          _isPosting = false;
        });

        // Show success message on the home screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Post created successfully! Publishing...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        // Only reset flag if post creation failed
        setState(() {
          _isPosting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait for your previous post to finish publishing'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}