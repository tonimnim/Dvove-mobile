import 'package:flutter/material.dart';
import '../../../../core/utils/constants.dart';

class SearchEmptyStatesWidget extends StatelessWidget {
  final String searchText;
  final bool isSearching;
  final bool hasSearched;
  final String searchQuery;

  const SearchEmptyStatesWidget({
    super.key,
    required this.searchText,
    required this.isSearching,
    required this.hasSearched,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    // Searching state
    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Searching...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty search field or less than 3 characters
    if (searchText.isEmpty || searchText.length < 3) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Icon(
            Icons.search,
            size: 48,
            color: Colors.grey.shade300,
          ),
        ),
      );
    }

    // No results found
    if (hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'No results for "$searchQuery"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Try different keywords',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
