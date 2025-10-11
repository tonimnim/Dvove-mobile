import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/posts_provider.dart';
import '../widgets/post_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ad_trackable_widget.dart';
import '../../../core/services/ad_tracking_service.dart';

class PostsFeed extends StatefulWidget {
  final String? postType;
  final String? excludeType;

  const PostsFeed({super.key, this.postType, this.excludeType});

  @override
  State<PostsFeed> createState() => _PostsFeedState();
}

class _PostsFeedState extends State<PostsFeed> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Schedule initialization after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the global provider and set up callback
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // Set up success callback for post sync
      postsProvider.onSyncComplete = (success, message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: success ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: success ? 2 : 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      };

      _initializeFeed();
    });
  }

  @override
  void didUpdateWidget(PostsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize feed when postType changes
    if (oldWidget.postType != widget.postType) {
      _initializeFeed();
    }
  }


  Future<void> _initializeFeed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Load posts for user's county
    await postsProvider.initializeFeed(
      countyId: authProvider.user?.countyId,
      type: widget.postType,
      excludeType: widget.excludeType,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      if (!postsProvider.isLoading) {
        postsProvider.loadMorePosts(
          countyId: authProvider.user?.countyId,
          type: widget.postType,
          excludeType: widget.excludeType,
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    await postsProvider.refreshPosts(
      countyId: authProvider.user?.countyId,
      type: widget.postType,
      excludeType: widget.excludeType,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Use the global provider
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, child) {
        // Get posts for THIS feed's type with excludeType filter
        var allPosts = postsProvider.getPostsForFeed(
          widget.postType,
          excludeType: widget.excludeType,
        );

        final displayPosts = allPosts;

        // Initial loading state (no cached posts)
        if (postsProvider.isLoading && displayPosts.isEmpty) {
          return _buildShimmerLoading();
        }

        // Error state (only if no cached posts)
        if (postsProvider.errorMessage != null && displayPosts.isEmpty) {
          return _buildErrorState(postsProvider.errorMessage!);
        }

        // Empty state (no posts and not loading)
        if (!postsProvider.isLoading && displayPosts.isEmpty) {
          return _buildEmptyState();
        }

        // Refreshing state (has cached posts but loading new ones)
        if (postsProvider.isLoading && displayPosts.isNotEmpty) {
          return Stack(
            children: [
              // Show cached posts in background
              Container(
                color: Colors.grey.shade100,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: displayPosts.length,
                  itemBuilder: (context, index) {
                    final post = displayPosts[index];
                    if (post.isAd) {
                      final trackingContext = widget.postType == 'job' ? 'job' : 'home';
                      return AdTrackableWidget(
                        adId: post.id,
                        context: trackingContext,
                        clickUrl: post.clickUrl,
                        child: PostCard(post: post),
                      );
                    }
                    return PostCard(key: ValueKey(post.id), post: post);
                  },
                ),
              ),
              // Show shimmer overlay
              Container(
                color: Colors.grey.shade100.withOpacity(0.8),
                child: _buildShimmerLoading(),
              ),
            ],
          );
        }

        // Posts list with pull to refresh
        return Container(
          color: Colors.grey.shade100,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.black,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: displayPosts.length +
                  (postsProvider.isLoading && postsProvider.posts.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                // Show loading indicator at the bottom
                if (index == displayPosts.length) {
                  return _buildLoadingIndicator();
                }

                final post = displayPosts[index];

                // Wrap with tracking for ads
                if (post.isAd) {
                  // Determine context based on feed type
                  final trackingContext = widget.postType == 'job' ? 'job' : 'home';

                  return AdTrackableWidget(
                    adId: post.id,
                    context: trackingContext,
                    clickUrl: post.clickUrl,
                    child: PostCard(post: post),
                  );
                }

                return PostCard(key: ValueKey(post.id), post: post);
              },
            ),
          ),
        );
      },
    );
  }

  // Static colors to avoid rebuilding
  static final _shimmerBaseColor = Colors.grey.shade300;
  static final _shimmerHighlightColor = Colors.grey.shade100;

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header shimmer
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Content shimmer
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                // Actions shimmer
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Static colors for states
  static final _errorIconColor = Colors.grey.shade400;
  static final _errorTitleColor = Colors.grey.shade700;
  static final _errorMessageColor = Colors.grey.shade600;
  static final _emptyIconColor = Colors.grey.shade300;

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: _errorIconColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _errorTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _errorMessageColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 80,
              color: _emptyIconColor,
            ),
            const SizedBox(height: 24),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _errorTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts from your county officials will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _errorMessageColor,
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Reset ad tracking when leaving the feed
    AdTrackingService.resetTracking();
    super.dispose();
  }
}