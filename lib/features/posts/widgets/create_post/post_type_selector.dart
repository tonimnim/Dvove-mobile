import 'package:flutter/material.dart';

class PostTypeSelector extends StatelessWidget {
  final String selectedType;
  final String? selectedPriority;
  final Function(String) onTypeChanged;
  final Function(String?) onPriorityChanged;

  const PostTypeSelector({
    super.key,
    required this.selectedType,
    this.selectedPriority,
    required this.onTypeChanged,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post type selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _TypeTab(
                type: 'Announcement',
                icon: Icons.campaign_outlined,
                isSelected: selectedType == 'announcement',
                onSelected: () => onTypeChanged('announcement'),
              ),
              const SizedBox(width: 24),
              _TypeTab(
                type: 'Job',
                icon: Icons.work_outline,
                isSelected: selectedType == 'job',
                onSelected: () => onTypeChanged('job'),
              ),
              const SizedBox(width: 24),
              _TypeTab(
                type: 'Event',
                icon: Icons.event_outlined,
                isSelected: selectedType == 'event',
                onSelected: () => onTypeChanged('event'),
              ),
              const SizedBox(width: 24),
              _TypeTab(
                type: 'Alert',
                icon: Icons.warning_amber_rounded,
                isSelected: selectedType == 'alert',
                onSelected: () => onTypeChanged('alert'),
              ),
            ],
          ),
        ),

        // Alert priority (only for alerts)
        if (selectedType == 'alert')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priority Level',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _PriorityChip(
                      priority: 'high',
                      color: Colors.red,
                      isSelected: selectedPriority == 'high',
                      onSelected: (selected) =>
                          onPriorityChanged(selected ? 'high' : null),
                    ),
                    _PriorityChip(
                      priority: 'medium',
                      color: Colors.orange,
                      isSelected: selectedPriority == 'medium',
                      onSelected: (selected) =>
                          onPriorityChanged(selected ? 'medium' : null),
                    ),
                    _PriorityChip(
                      priority: 'low',
                      color: Colors.yellow.shade700,
                      isSelected: selectedPriority == 'low',
                      onSelected: (selected) =>
                          onPriorityChanged(selected ? 'low' : null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String type;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  const _TypeTab({
    required this.type,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  final Color color;
  final bool isSelected;
  final Function(bool) onSelected;

  const _PriorityChip({
    required this.priority,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      showCheckmark: false,
    );
  }
}