import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/posts/providers/posts_provider.dart';
import 'features/posts/providers/comments_provider.dart';
import 'features/polls/providers/polls_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/conversations_list_screen.dart';
import 'features/constitution/screens/article_detail_screen.dart';
import 'core/api/api_client.dart';

// Global navigator key for navigation from anywhere (e.g., API interceptors)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up 401 unauthorized handler
  ApiClient.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    // When app returns to foreground, websocket will auto-reconnect
    // No action needed - Pusher handles reconnection automatically
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => CommentsProvider()),
        ChangeNotifierProvider(create: (_) => PollsProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Dvove',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Chirp',
          primaryColor: Colors.black,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Chirp',
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontFamily: 'Chirp',
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'Chirp',
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: TextStyle(
              fontFamily: 'Chirp',
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Chirp',
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/chat': (context) => const ChatScreen(),
          '/conversations': (context) => const ConversationsListScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle routes with arguments
          if (settings.name == '/article-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final articleId = args?['articleId'];
            if (articleId != null) {
              return MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(articleId: articleId),
              );
            }
          } else if (settings.name == '/post-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final postId = args?['postId'];
            if (postId != null) {
              // Note: You'll need to fetch the Post object or modify PostDetailScreen
              // to accept postId and fetch the post inside the screen
              // For now, returning null - you may need to adjust PostDetailScreen
              return null;
            }
          }
          return null;
        },
      ),
    );
  }
}