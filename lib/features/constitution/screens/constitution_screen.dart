import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/utils/constants.dart';
import '../models/constitution_daily.dart';
import '../models/constitution_search_result.dart';
import '../services/constitution_service.dart';
import '../widgets/daily_article_card.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_results_widget.dart';
import '../widgets/search_empty_states_widget.dart';
import 'chapters_list_screen.dart';
import 'article_detail_screen.dart';

class ConstitutionScreen extends StatefulWidget {
  const ConstitutionScreen({super.key});

  @override
  State<ConstitutionScreen> createState() => _ConstitutionScreenState();
}

class _ConstitutionScreenState extends State<ConstitutionScreen> {
  final ConstitutionService _constitutionService = ConstitutionService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  ConstitutionDaily? _dailyArticle;
  bool _isLoading = true;
  String? _errorMessage;

  // Search state
  List<ConstitutionSearchResult> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadDailyArticle();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
        _hasSearched = false;
      });
      return;
    }

    if (query.length < 3) {
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _constitutionService.search(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = true;
      });

      // Show error snackbar for real errors (not validation)
      if (mounted && !e.toString().contains('at least')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search temporarily unavailable'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDailyArticle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dailyArticle = await _constitutionService.getDailyArticle();
      setState(() {
        _dailyArticle = dailyArticle;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToArticleDetail(String articleId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          articleId: articleId,
        ),
      ),
    );
  }

  void _navigateToChaptersList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChaptersListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_dailyArticle == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Fixed search bar at the top (not scrollable)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SearchBarWidget(
            controller: _searchController,
            onClear: () => _searchController.clear(),
          ),
        ),

        // Scrollable content below
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDailyArticle,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Daily Article Card
                  DailyArticleCard(
                    dailyArticle: _dailyArticle!,
                    onTap: () => _navigateToArticleDetail(_dailyArticle!.article.rawId),
                    onBrowseChapters: _navigateToChaptersList,
                  ),

                  // Search results or empty states
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        if (_searchResults.isNotEmpty)
                          SearchResultsWidget(
                            results: _searchResults,
                            query: _searchQuery,
                            onResultTap: _navigateToArticleDetail,
                          )
                        else
                          SearchEmptyStatesWidget(
                            searchText: _searchController.text,
                            isSearching: _isSearching,
                            hasSearched: _hasSearched,
                            searchQuery: _searchQuery,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Failed to load daily article',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDailyArticle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gavel,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No article available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
