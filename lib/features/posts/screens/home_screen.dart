import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../models/post.dart';
import 'posts_feed.dart';
import 'create_post_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/services/chat_service.dart';
import '../../search/widgets/search_tab.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/memory_optimized_image.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../constitution/screens/constitution_screen.dart';
import '../../../core/utils/constants.dart';
import '../../profile/widgets/subscription_list_tile.dart';
import '../providers/posts_provider.dart';
import '../../polls/screens/polls_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ChatService _chatService = ChatService();

  late List<Widget> _pages;

  // Static decorations to avoid rebuilding on every setState
  static final _bottomNavBorderColor = Colors.grey.shade300;
  static final _bottomNavShadowColor = Colors.grey.withOpacity(0.1);
  static final _unselectedItemColor = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();

    // Load notification count for badge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.loadUnreadCount();
    });

    _pages = [
      PostsFeed(key: ValueKey('home_feed'), excludeType: 'job'), // Home (no jobs)
      const SearchTab(), // Search
      PostsFeed(key: ValueKey('jobs_feed'), postType: 'job'), // Jobs
      const ConstitutionScreen(), // Constitution
      const ChatScreen(), // Dvove AI
    ];
  }

  Future<void> _createNewConversation() async {
    setState(() {
      _pages[4] = ChatScreen(
        key: ValueKey('new_${DateTime.now().millisecondsSinceEpoch}'),
      );
    });
  }

  Future<void> _loadConversation(String sessionId) async {
    setState(() {
      _pages[4] = ChatScreen(
        key: ValueKey('session_$sessionId'),
        sessionId: sessionId,
      );
    });
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    // Don't listen to auth changes for entire screen rebuild
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Simple static header - no animations
          if (_selectedIndex != 1) // Hide only on search tab
            Container(
              height: 52 + MediaQuery.of(context).padding.top,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.0,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    if (_selectedIndex != 3) // Hide avatar on Constitution tab
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Consumer<AuthProvider>(
                          builder: (context, auth, child) => GestureDetector(
                            onTap: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            child: MemoryOptimizedAvatar(
                              imageUrl: auth.user?.profilePhoto,
                              fallbackText: auth.user?.displayName ?? 'U',
                              size: 36, // radius 18 * 2 = 36
                            ),
                          ),
                        ),
                      ),
                    if (_selectedIndex == 3) const SizedBox(width: 12), // Padding when avatar hidden
                    Expanded(
                      child: Center(
                        child: _selectedIndex == 4
                          ? const Text(
                              'Dvove AI',
                              style: TextStyle(
                                fontFamily: 'Chirp',
                                fontSize: 21,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            )
                          : _selectedIndex == 3
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Katiba',
                                      style: TextStyle(
                                        fontFamily: 'Chirp',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const Text(
                                      '360',
                                      style: TextStyle(
                                        fontFamily: 'Chirp',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(0, -4),
                                      child: const Text(
                                        '°',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFFBE0027), // Kenyan flag red
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _selectedIndex == 2
                                  ? const Text(
                                      'Dvove Jobs',
                                      style: TextStyle(
                                        fontFamily: 'Chirp',
                                        fontSize: 21,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Dvove',
                                      style: TextStyle(
                                        fontFamily: 'Chirp',
                                        fontSize: 21,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black,
                                      ),
                                    ),
                      ),
                    ),
                  if (_selectedIndex == 4) // AI tab: show new chat + history icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: Colors.black,
                            size: 20,
                            weight: 700,
                          ),
                          onPressed: () async {
                            try {
                              await _createNewConversation();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error creating new conversation: $e')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            IconData(0xf102, fontFamily: 'MaterialIcons'),
                            color: Colors.black,
                            size: 20,
                            weight: 700,
                          ),
                          onPressed: () async {
                            final selectedConversation = await Navigator.pushNamed(context, '/conversations');
                            if (selectedConversation != null && selectedConversation is Map<String, String>) {
                              await _loadConversation(selectedConversation['id']!);
                            }
                          },
                        ),
                      ],
                    ),
                  if (_selectedIndex == 0) // Home feed: show notification bell
                    Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, child) {
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.black,
                                size: 24,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Scaffold(
                                      appBar: AppBar(
                                        title: const Text('Notifications'),
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                      ),
                                      body: const NotificationsScreen(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (notificationProvider.unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    notificationProvider.unreadCount > 9
                                        ? '9+'
                                        : notificationProvider.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  if (_selectedIndex == 0) // Home feed: show poll icon after notifications
                    IconButton(
                      icon: const Icon(
                        Icons.poll_outlined,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PollsListScreen(),
                          ),
                        );
                      },
                    ),
                  if (_selectedIndex != 4 && _selectedIndex != 0) const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final user = auth.user;
              return Column(
                children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MemoryOptimizedAvatar(
                                imageUrl: user?.profilePhoto,
                                fallbackText: user?.displayName ?? 'U',
                                size: 60, // radius 30 * 2 = 60
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user?.displayName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${user?.username ?? 'username'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.person_outline, color: Colors.black),
                          title: const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                        if (user?.role == 'official' && user?.phoneNumber != null) ...[
                          SubscriptionListTile(
                            phoneNumber: user!.phoneNumber!,
                            hasActiveSubscription: user.hasActiveSubscription,
                          ),
                        ],
                    ListTile(
                      leading: const Icon(Icons.share_outlined, color: Colors.black),
                      title: const Text('Share App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        Share.share('Check out Dvove - Your County Connection! Download now: https://play.google.com/store/apps/details?id=com.dvove.app');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.star_border, color: Colors.black),
                      title: const Text('Rate App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        Navigator.pop(context);
                        final InAppReview inAppReview = InAppReview.instance;
                        if (await inAppReview.isAvailable()) {
                          inAppReview.requestReview();
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined, color: Colors.black),
                      title: const Text('Terms of Use', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        Navigator.pop(context);
                        final uri = Uri.parse('https://dvove.com/terms-of-use');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: Colors.black),
                      title: const Text('Privacy Policy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        Navigator.pop(context);
                        final uri = Uri.parse('https://dvove.com/privacy-policy');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Delete Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red)),
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text('This will permanently delete your account and all data. This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          final success = await authProvider.deleteAccount();
                          if (success && mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Account deleted successfully')),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProvider.errorMessage ?? 'Failed to delete account'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    Expanded(child: Container()),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.black),
                      title: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      trailing: FutureBuilder<String>(
                        future: _getAppVersion(),
                        builder: (context, snapshot) {
                          return Text(
                            'v${snapshot.data ?? '...'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                      onTap: () async {
                        // Clear all provider caches
                        final postsProvider = Provider.of<PostsProvider>(context, listen: false);
                        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

                        await postsProvider.clearCache();
                        notificationProvider.clearCache();
                        await _chatService.clearCache();

                        // Logout
                        await authProvider.logout();

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        }
                      },
                    ),
                      const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final canCreatePosts = auth.canCreatePosts;
          return (canCreatePosts && _selectedIndex != 1 && _selectedIndex != 3 && _selectedIndex != 4)
            ? SizedBox(
                height: 48,
                width: 48,
                child: FloatingActionButton(
                  onPressed: () async {
                    await Navigator.push<Post?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreatePostScreen(),
                      ),
                    );
                    // Post is automatically added to the feed via PostsProvider
                  },
                  backgroundColor: const Color(0xFF01775A),
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              )
            : const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: _bottomNavBorderColor,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _bottomNavShadowColor,
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: _unselectedItemColor,
          elevation: 0,
          enableFeedback: false,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

}
