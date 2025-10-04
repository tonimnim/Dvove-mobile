import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';

/// Avatar component with photo picker and upload functionality
class ProfileAvatar extends StatefulWidget {
  final User user;
  final double radius;
  final Function(User updatedUser)? onUserUpdated;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 50,
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
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Compress image
        final File? compressedFile = await _compressImage(imageFile);

        if (compressedFile != null) {
          setState(() {
            _selectedImage = compressedFile;
          });

          // Auto-upload the photo
          await _uploadProfilePhoto();
        }
      }
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

  Future<File?> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize image to max 300x300 while maintaining aspect ratio
      final resized = img.copyResize(image, width: 300, height: 300);

      // Compress and save
      final compressedBytes = img.encodeJpg(resized, quality: 85);

      final compressedFile = File('${file.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      return file; // Return original if compression fails
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

      setState(() {
        _isUploadingPhoto = false;
        _selectedImage = null; // Clear selected image after successful upload
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
        _selectedImage = null; // Reset on error
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
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: FileImage(_selectedImage!),
      );
    }

    // Show profile photo if available
    if (widget.user.profilePhoto != null && widget.user.profilePhoto!.isNotEmpty) {
      return ClipOval(
        child: Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          color: Colors.grey.shade300,
          child: Image.network(
            AppConfig.fixMediaUrl(widget.user.profilePhoto!),
            width: widget.radius * 2,
            height: widget.radius * 2,
            cacheWidth: (widget.radius * 2 * 3.5).round(), // Cache at display resolution
            cacheHeight: (widget.radius * 2 * 3.5).round(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  widget.user.displayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: widget.radius * 0.6,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Text(
                  widget.user.displayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: widget.radius * 0.6,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback to initials
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        widget.user.displayName.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: widget.radius * 0.6,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
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