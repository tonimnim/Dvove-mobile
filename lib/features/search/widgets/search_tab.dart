import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/search_service.dart';
import '../services/search_storage.dart';
import '../../posts/models/post.dart';
import '../../posts/widgets/post_card.dart';
import '../../posts/providers/posts_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/user_avatar.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final SearchStorage _searchStorage = SearchStorage();
  late PostsProvider _postsProvider;

  List<Post> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _postsProvider = PostsProvider();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _postsProvider.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _searchStorage.getRecentSearchQueries();
    setState(() {
      _recentSearches = searches;
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a search term'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final result = await _searchService.search(query: query);

      // Save to recent searches
      await _searchStorage.addRecentSearch(query);
      await _loadRecentSearches(); // Refresh recent searches

      setState(() {
        _searchResults = result['posts'] as List<Post>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _searchResults = [];
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _errorMessage = null;
      _hasSearched = false;
    });
  }

  void _selectRecentSearch(String query) {
    _searchController.text = query;
    _performSearch();
  }

  Future<void> _clearRecentSearches() async {
    await _searchStorage.clearRecentSearches();
    await _loadRecentSearches();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recent searches cleared'),
          backgroundColor: Color(0xFF01775A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Unified white background
      appBar: null, // No app bar to match other tabs
      body: SafeArea(
        child: Column(
          children: [
            // Search input section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final user = authProvider.user;
                  return Row(
                    children: [
                      // Profile avatar
                      UserAvatar(
                        user: user,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      // Search input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                          onChanged: (value) {
                            setState(() {}); // Update clear button visibility
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
          ),

          // Results section
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
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
              'Search failed',
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
              onPressed: _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01775A),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildRecentSearchesSection();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check spelling',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show search results using existing PostCard widgets
    return ChangeNotifierProvider<PostsProvider>.value(
      value: _postsProvider,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final post = _searchResults[index];
          return PostCard(post: post);
        },
      ),
    );
  }

  Widget _buildRecentSearchesSection() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Dvove',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent searches header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Recent searches list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return ListTile(
                leading: Icon(
                  Icons.history,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                title: Text(
                  query,
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: Icon(
                  Icons.north_west,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
                onTap: () => _selectRecentSearch(query),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}