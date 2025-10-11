import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../posts/screens/home_screen.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/intelligent_cache_service.dart';
import '../../../firebase_options.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (!mounted) return;

    // Initialize FCM with navigator key and cache service (non-blocking)
    await FcmService.instance.initialize(navigatorKey: navigatorKey);
    IntelligentCacheService.instance.initialize();

    if (!mounted) return;

    // Check authentication status
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initializeAuth();

    if (!mounted) return;

    // Register FCM token if user is already authenticated
    if (authProvider.isAuthenticated) {
      await FcmService.instance.registerToken(authProvider);
    }

    if (!mounted) return;

    // Navigate based on auth status
    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'D',
                  style: TextStyle(
                    fontFamily: 'Biski',
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'vove',
                  style: TextStyle(
                    fontFamily: 'Biski',
                    fontSize: 35,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "It's what's happening across your county.",
              style: TextStyle(
                fontFamily: 'Chirp',
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}