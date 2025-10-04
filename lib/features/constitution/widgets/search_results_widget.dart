import 'package:flutter/material.dart';
import '../models/constitution_search_result.dart';
import 'search_result_card.dart';

class SearchResultsWidget extends StatelessWidget {
  final List<ConstitutionSearchResult> results;
  final String query;
  final Function(String) onResultTap;

  const SearchResultsWidget({
    super.key,
    required this.results,
    required this.query,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${results.length} result${results.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),

        // Search results list
        ...results.map((result) => SearchResultCard(
          result: result,
          query: query,
          onTap: () => onResultTap(result.rawId),
        )),
      ],
    );
  }
}
