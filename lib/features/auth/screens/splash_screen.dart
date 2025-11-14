import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../firebase_options.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/intelligent_cache_service.dart';
import '../../../main.dart';
import 'login_screen.dart';
import '../../posts/screens/home_screen.dart';

/// SIMPLE splash screen - just check token and navigate
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Step 1: Initialize Firebase (required, ~500ms)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Step 2: Start background services (don't wait)
    FcmService.instance.initialize(navigatorKey: navigatorKey);
    IntelligentCacheService.instance.initialize();

    // Step 3: Check if we have a token (one simple check)
    final storage = SecureStorage();
    final hasToken = await storage.hasToken();

    if (!mounted) return;

    // Step 4: Navigate based on token existence
    if (hasToken) {
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