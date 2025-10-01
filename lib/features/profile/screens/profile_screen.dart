import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import '../services/profile_service.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_info_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _officialNameController = TextEditingController();
  final TextEditingController _officeAddressController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Edit mode state
  bool _isEditMode = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _officialNameController.dispose();
    _officeAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _profileService.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });

      // Initialize controllers based on user type
      if (user.isOfficial) {
        _officialNameController.text = user.officialName ?? '';
        _officeAddressController.text = user.officeAddress ?? '';
      } else {
        _usernameController.text = user.username ?? '';
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserProfile() async {
    if (_user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      User updatedUser;

      if (_user!.isOfficial) {
        // Update official name and office address for official users
        final newOfficialName = _officialNameController.text.trim();
        final newOfficeAddress = _officeAddressController.text.trim();

        if (newOfficialName.isEmpty) {
          throw Exception('Official name cannot be empty');
        }

        updatedUser = await _profileService.updateProfile(
          officialName: newOfficialName,
          officeAddress: newOfficeAddress.isNotEmpty ? newOfficeAddress : null,
        );
      } else {
        // Update username for regular users
        final newUsername = _usernameController.text.trim();
        if (newUsername.isEmpty) {
          throw Exception('Username cannot be empty');
        }

        updatedUser = await _profileService.updateProfile(
          username: newUsername,
        );
      }

      setState(() {
        _user = updatedUser;
        _isEditMode = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF01775A),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
    });

    // Reset controllers to original values
    if (_user != null) {
      if (_user!.isOfficial) {
        _officialNameController.text = _user!.officialName ?? '';
        _officeAddressController.text = _user!.officeAddress ?? '';
      } else {
        _usernameController.text = _user!.username ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_isEditMode) ...[
            // Cancel button
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            // Save button
            TextButton(
              onPressed: _isSaving ? null : _saveUserProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF01775A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ] else ...[
            // Edit button
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFF01775A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF01775A),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01775A),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(
        child: Text('No user data available'),
      );
    }

    return _buildProfileContent();
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Header with Avatar, Name, and Role Badge
          ProfileHeader(
            user: _user!,
            onUserUpdated: (updatedUser) {
              setState(() {
                _user = updatedUser;
              });
            },
          ),

          const SizedBox(height: 32),

          // Profile Information Section
          ProfileInfoSection(
            user: _user!,
            isEditMode: _isEditMode,
            usernameController: _usernameController,
            officialNameController: _officialNameController,
            officeAddressController: _officeAddressController,
          ),
        ],
      ),
    );
  }

}