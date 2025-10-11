import 'package:flutter/material.dart';
import '../../auth/models/user.dart';

/// Editable field component for username (regular users) or official name (official users)
/// Handles both view and edit modes with proper styling
class EditableNameField extends StatelessWidget {
  final User user;
  final bool isEditMode;
  final TextEditingController controller;

  const EditableNameField({
    super.key,
    required this.user,
    required this.isEditMode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOfficial = user.isOfficial;
    final label = isOfficial ? 'Official Name' : 'Username';
    final icon = isOfficial ? Icons.badge_outlined : Icons.person_outline;
    final currentValue = isOfficial ? (user.officialName ?? '') : (user.username ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isEditMode ? Colors.blue.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEditMode ? Colors.blue.shade600 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEditMode ? Colors.blue.shade600 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditMode)
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    currentValue,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}