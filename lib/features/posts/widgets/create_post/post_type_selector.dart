import 'package:flutter/material.dart';

class PostTypeSelector extends StatelessWidget {
  final String selectedType;
  final String? selectedPriority;
  final String selectedScope;
  final Function(String) onTypeChanged;
  final Function(String?) onPriorityChanged;
  final Function(String) onScopeChanged;

  const PostTypeSelector({
    super.key,
    required this.selectedType,
    this.selectedPriority,
    required this.selectedScope,
    required this.onTypeChanged,
    required this.onPriorityChanged,
    required this.onScopeChanged,
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

        // Job scope selector (only for jobs)
        if (selectedType == 'job')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Visibility',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScopeOption(
                        scope: 'county',
                        label: 'County Only',
                        description: 'Your county only',
                        isSelected: selectedScope == 'county',
                        onSelected: () => onScopeChanged('county'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScopeOption(
                        scope: 'national',
                        label: 'National',
                        description: 'All 47 counties',
                        isSelected: selectedScope == 'national',
                        onSelected: () => onScopeChanged('national'),
                      ),
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

class _ScopeOption extends StatelessWidget {
  final String scope;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ScopeOption({
    required this.scope,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}