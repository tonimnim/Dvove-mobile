import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Dvove';
}

class ApiEndpoints {
  ApiEndpoints._();

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String user = '/auth/user';
  static const String verifyEmailCode = '/auth/verify-email-code';
  static const String resendEmailCode = '/auth/resend-email-verification';

  // Posts endpoints
  static const String posts = '/posts';
  static String likePost(int id) => '/posts/$id/like';
  static String unlikePost(int id) => '/posts/$id/unlike';
  static String postDetails(int id) => '/posts/$id';
  static String postComments(int id) => '/posts/$id/comments';


  // Counties endpoints
  static const String counties = '/counties';
  static String countyPosts(int id) => '/counties/$id/posts';
  static const String followCounty = '/counties/follow';
  static const String unfollowCounty = '/counties/unfollow';

  // Officials endpoints
  static const String createPost = '/official/posts';
  static const String myPosts = '/official/my-posts';
  static String updatePost(int id) => '/official/posts/$id';
  static String deletePost(int id) => '/official/posts/$id';
  static String postAnalytics(int id) => '/official/posts/$id/analytics';

  // Notifications endpoints
  static const String notifications = '/notifications';
  static String markAsRead(int id) => '/notifications/$id/read';
  static const String markAllAsRead = '/notifications/mark-all-read';

  // User endpoints
  static const String updateProfile = '/user/profile';
  static const String changePassword = '/user/change-password';
  static const String updateCounties = '/user/counties';

  // Search endpoints
  static const String search = '/search';

  // Ad tracking endpoints
  static String adImpression(int adId) => '/ads/$adId/impression';
  static String adClick(int adId) => '/ads/$adId/click';
}

class AppColors {
  AppColors._();

  // Main theme color
  static const Color primary = Color(0xFF01775A); // Dvove brand color (teal/green)

  static const Color primaryGreen = Color(0xFF006600); // Kenya flag green (for constitution)
  static const Color secondaryRed = Color(0xFFBB0000); // Kenya flag red
  static const Color accentBlack = Color(0xFF000000);
  static const Color backgroundGray = Color(0xFFF5F5F5);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF757575);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
}

class AppStrings {
  AppStrings._();

  // Auth
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String phoneNumber = 'Phone Number';
  static const String email = 'Email';
  static const String username = 'Username';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String loginPrompt = 'Login to your account';
  static const String registerPrompt = 'Create a new account';
  static const String forgotPassword = 'Forgot Password?';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";

  // Navigation
  static const String home = 'Home';
  static const String posts = 'Posts';
  static const String counties = 'Counties';
  static const String notifications = 'Alerts';
  static const String profile = 'Profile';
  static const String officials = 'Dashboard';

  // Post Types
  static const String announcement = 'Announcement';
  static const String job = 'Job';
  static const String event = 'Event';
  static const String alert = 'Alert';
  static const String all = 'All';

  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String submit = 'Submit';
  static const String noDataFound = 'No data found';
  static const String somethingWentWrong = 'Something went wrong';
  static const String noInternetConnection = 'No internet connection';
}