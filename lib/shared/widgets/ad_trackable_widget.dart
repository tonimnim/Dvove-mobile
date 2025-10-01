import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/ad_tracking_service.dart';

class AdTrackableWidget extends StatelessWidget {
  final Widget child;
  final int adId;
  final String context;
  final String? clickUrl;

  const AdTrackableWidget({
    super.key,
    required this.child,
    required this.adId,
    required this.context,
    this.clickUrl,
  });

  static final _trackingService = AdTrackingService();

  void _handleTap() async {
    // Track click
    final urlToOpen = await _trackingService.trackClick(
      adId: adId,
      context: context,
    );

    // Open URL (use response URL or fallback to stored URL)
    final finalUrl = urlToOpen ?? clickUrl;
    if (finalUrl != null && finalUrl.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(finalUrl), mode: LaunchMode.externalApplication);
      } catch (e) {
        print('[AdTracking] Could not launch URL: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ad_$adId'),
      onVisibilityChanged: (info) {
        // Track impression when >50% visible
        if (info.visibleFraction > 0.5) {
          _trackingService.trackImpression(
            adId: adId,
            context: this.context,
          );
        }
      },
      child: GestureDetector(
        onTap: clickUrl != null ? _handleTap : null,
        child: child,
      ),
    );
  }
}