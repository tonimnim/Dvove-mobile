import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/posts/providers/posts_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/conversations_list_screen.dart';
import 'core/services/intelligent_cache_service.dart';

void main() {
  // Initialize memory-safe caching system
  IntelligentCacheService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()), // Single instance for entire app
      ],
      child: MaterialApp(
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
      ),
    );
  }
}