import 'package:flutter/material.dart';
import '../../auth/models/user.dart';

/// Editable field component for office address (official users only)
/// Handles both view and edit modes with proper styling
class EditableOfficeField extends StatelessWidget {
  final User user;
  final bool isEditMode;
  final TextEditingController controller;

  const EditableOfficeField({
    super.key,
    required this.user,
    required this.isEditMode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!user.isOfficial) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEditMode ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditMode ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.business_outlined,
            color: isEditMode ? Colors.blue.shade600 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Office Address',
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
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Enter office address',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    user.officeAddress?.isEmpty ?? true
                      ? 'No office address'
                      : user.officeAddress!,
                    style: TextStyle(
                      fontSize: 16,
                      color: user.officeAddress?.isEmpty ?? true
                        ? Colors.grey.shade500
                        : Colors.black,
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