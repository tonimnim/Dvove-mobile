class AppConfig {
  AppConfig._();

  // Environment detection
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;

  // API Configuration
  static const String apiBaseUrl = 'https://dvove.com';
  static String get apiUrl => '$apiBaseUrl/api/v1';

  // Media/Storage URL Configuration
  static String get storageBaseUrl => '$apiBaseUrl/storage';

  // Error Messages Configuration
  static const Map<String, String> errorMessages = {
    'network': 'No internet connection',
    'server': 'Server unavailable',
    'timeout': 'Request timed out',
    'upload_failed': 'Failed to upload. Tap to retry.',
    'validation': 'Please check your input',
    'general': 'Something went wrong',
  };

  // Fix URLs to ensure they use the correct domain
  static String fixMediaUrl(String url) {
    // Handle relative storage paths
    if (url.startsWith('/storage/')) {
      return '$apiBaseUrl$url';
    }

    // Handle various localhost/development patterns - convert to production
    if (url.contains('localhost') || url.contains('127.0.0.1') || url.contains('192.168.0.100') || url.contains('10.0.2.2')) {
      // Extract the storage path
      final uri = Uri.parse(url);
      if (uri.path.startsWith('/storage/')) {
        return '$apiBaseUrl${uri.path}';
      }
    }

    // If already using dvove.com, return as-is
    if (url.contains('dvove.com')) {
      return url;
    }

    return url;
  }

  // Pusher Configuration (for realtime features)
  static const String pusherAppKey = 'bf17d63d36a366545d77';
  static const String pusherCluster = 'us2';
  static String get pusherAuthUrl => '$apiUrl/broadcasting/auth';

  // Feature Flags
  static const bool enableDebugLogging = isDevelopment;
  static const bool enableCrashReporting = isProduction;

  // Timeouts - Single configuration for all requests
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);

  // Cache Settings
  static const Duration cacheMaxAge = Duration(hours: 1);
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB

  // API Headers
  static Map<String, String> get defaultHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
}