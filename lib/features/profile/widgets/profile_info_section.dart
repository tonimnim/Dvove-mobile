import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import 'profile_info_card.dart';
import 'editable_name_field.dart';
import 'editable_office_field.dart';
import 'subscription_status_card.dart';
import 'change_password_dialog.dart';

/// Section containing all profile information fields
/// Handles both readonly and editable fields based on edit mode
class ProfileInfoSection extends StatelessWidget {
  final User user;
  final bool isEditMode;
  final TextEditingController usernameController;
  final TextEditingController officialNameController;
  final TextEditingController officeAddressController;

  const ProfileInfoSection({
    super.key,
    required this.user,
    required this.isEditMode,
    required this.usernameController,
    required this.officialNameController,
    required this.officeAddressController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Name Field (Username for regular users, Official Name for officials)
        EditableNameField(
          user: user,
          isEditMode: isEditMode,
          controller: user.isOfficial ? officialNameController : usernameController,
        ),

        // Phone Number Field (only show if phone number exists)
        if (user.phoneNumber != null)
          ProfileInfoCard(
            label: 'Phone Number',
            value: user.phoneNumber!,
            icon: Icons.phone_outlined,
          ),

        // County Field (if available)
        if (user.county != null)
          ProfileInfoCard(
            label: 'County',
            value: user.county!.name,
            icon: Icons.location_on_outlined,
          ),

        // Official-specific fields
        if (user.isOfficial) ...[
          // Office Address (editable)
          EditableOfficeField(
            user: user,
            isEditMode: isEditMode,
            controller: officeAddressController,
          ),

          if (user.email != null)
            ProfileInfoCard(
              label: 'Email',
              value: user.email!,
              icon: Icons.email_outlined,
            ),

          const SizedBox(height: 16),

          // Subscription Status
          SubscriptionStatusCard(user: user),
        ],

        const SizedBox(height: 16),

        // Change Password Button
        _buildChangePasswordButton(context),
      ],
    );
  }

  Widget _buildChangePasswordButton(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const ChangePasswordDialog(),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}