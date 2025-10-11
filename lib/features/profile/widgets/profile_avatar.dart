import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../posts/widgets/memory_optimized_image.dart';
import '../services/profile_service.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/intelligent_cache_service.dart';

/// Avatar component with photo picker and upload functionality
class ProfileAvatar extends StatefulWidget {
  final User user;
  final double radius;
  final Function(User updatedUser)? onUserUpdated;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 60,
    this.onUserUpdated,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ImagePicker _imagePicker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  File? _selectedImage;
  bool _isUploadingPhoto = false;

  void _showPhotoPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Profile Photo'),
          content: const Text('Choose how you want to update your profile photo'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  const Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  const Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      final imageBytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      await _showCropperDialog(imageBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCropperDialog(Uint8List imageBytes) async {
    final cropController = CropController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF01775A),
          title: const Text('Adjust Photo', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: Crop(
                image: imageBytes,
                controller: cropController,
                onCropped: (result) {
                  Navigator.pop(context);
                  switch (result) {
                    case CropSuccess(croppedImage: final croppedImage):
                      _processCroppedImage(croppedImage);
                    case CropFailure():
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to crop image'),
                          backgroundColor: Colors.red,
                        ),
                      );
                  }
                },
                aspectRatio: 1,
                withCircleUi: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withOpacity(0.8),
                radius: 0,
              ),
            ),
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white54, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => cropController.crop(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF01775A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCroppedImage(Uint8List croppedData) async {
    try {
      final image = img.decodeImage(croppedData);
      if (image == null) return;

      final resized = img.copyResize(image, width: 400, height: 400);
      final compressedBytes = img.encodeJpg(resized, quality: 85);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      setState(() {
        _selectedImage = tempFile;
      });

      await _uploadProfilePhoto();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      // Upload profile photo using ProfileService
      final updatedUser = await _profileService.uploadProfilePhoto(_selectedImage!.path);

      // Clear cache to show new photo
      IntelligentCacheService.instance.clearCache();

      setState(() {
        _isUploadingPhoto = false;
        _selectedImage = null;
      });

      // Notify parent about user update
      widget.onUserUpdated?.call(updatedUser);

      // Update AuthProvider to refresh user data across the app
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.updateUser(updatedUser);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            backgroundColor: Color(0xFF01775A),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAvatarContent() {
    // Show selected image if available
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
        ),
      );
    }

    // Use MemoryOptimizedAvatar for display
    return MemoryOptimizedAvatar(
      imageUrl: widget.user.profilePhoto,
      fallbackText: widget.user.displayName,
      size: widget.radius * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isUploadingPhoto ? null : _showPhotoPickerDialog,
      child: Stack(
        children: [
          _buildAvatarContent(),

          // Upload loading indicator
          if (_isUploadingPhoto)
            Positioned.fill(
              child: CircleAvatar(
                radius: widget.radius,
                backgroundColor: Colors.black54,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),

          // Camera icon overlay
          if (!_isUploadingPhoto)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF01775A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}