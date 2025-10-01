import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import 'profile_info_card.dart';
import 'editable_name_field.dart';
import 'editable_office_field.dart';
import 'subscription_status_card.dart';

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

        const SizedBox(height: 16),

        // Phone Number Field (only show if phone number exists)
        if (user.phoneNumber != null) ...[
          ProfileInfoCard(
            label: 'Phone Number',
            value: user.phoneNumber!,
            icon: Icons.phone_outlined,
          ),
          const SizedBox(height: 16),
        ],

        // County Field (if available)
        if (user.county != null) ...[
          const SizedBox(height: 16),
          ProfileInfoCard(
            label: 'County',
            value: user.county!.name,
            icon: Icons.location_on_outlined,
          ),
        ],

        // Official-specific fields
        if (user.isOfficial) ...[
          const SizedBox(height: 16),

          // Office Address (editable)
          EditableOfficeField(
            user: user,
            isEditMode: isEditMode,
            controller: officeAddressController,
          ),

          if (user.email != null) ...[
            const SizedBox(height: 16),
            ProfileInfoCard(
              label: 'Email',
              value: user.email!,
              icon: Icons.email_outlined,
            ),
          ],

          const SizedBox(height: 16),

          // Subscription Status
          SubscriptionStatusCard(user: user),
        ],
      ],
    );
  }
}