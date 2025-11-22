import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/constants.dart';
import '../services/subscription_service.dart';
import '../../auth/providers/auth_provider.dart';

class SubscriptionListTile extends StatefulWidget {
  final String phoneNumber;

  const SubscriptionListTile({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SubscriptionListTile> createState() => _SubscriptionListTileState();
}

class _SubscriptionListTileState extends State<SubscriptionListTile> {
  bool _isProcessing = false;
  String _statusMessage = '';
  int? _paymentId;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30; // 60 seconds (2s interval)

  final SubscriptionService _subscriptionService = SubscriptionService();

  Future<void> _renewSubscription() async {
    // State: Initiating payment
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Initiating payment...';
    });

    try {
      // Step 1: Initiate payment
      final result = await _subscriptionService.renewSubscription(widget.phoneNumber);

      if (!mounted) return;

      // Extract payment_id from response
      _paymentId = result['data']?['payment_id'];

      if (_paymentId == null) {
        throw Exception('Payment initiated but no payment ID received');
      }

      // State: Waiting for M-PESA prompt
      setState(() {
        _statusMessage = 'Check your phone for M-PESA prompt';
      });

      // Wait 3 seconds before starting to poll (give user time to see M-PESA prompt)
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Step 2: Start polling for payment status
      setState(() {
        _statusMessage = 'Verifying payment...';
      });

      _startPollingPaymentStatus();

    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _startPollingPaymentStatus() {
    _pollAttempts = 0;

    // Poll every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollAttempts++;

      try {
        final result = await _subscriptionService.checkPaymentStatus(_paymentId!);
        final status = result['status'];

        if (status == 'completed') {
          // Success!
          timer.cancel();
          if (mounted) {
            await _handlePaymentSuccess();
          }
        } else if (status == 'failed') {
          // Failed
          timer.cancel();
          if (mounted) {
            _handlePaymentFailed('Payment failed. Please try again.');
          }
        } else if (_pollAttempts >= _maxPollAttempts) {
          // Timeout
          timer.cancel();
          if (mounted) {
            _handlePaymentTimeout();
          }
        }
        // else: status is 'pending', continue polling
      } catch (e) {
        // Don't stop polling on single error, but count it
        if (_pollAttempts >= _maxPollAttempts) {
          timer.cancel();
          if (mounted) {
            _handlePaymentTimeout();
          }
        }
      }
    });
  }

  Future<void> _handlePaymentSuccess() async {
    setState(() {
      _isProcessing = false;
      _statusMessage = '';
    });

    // Refresh user data to get updated subscription status
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshUser();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment successful! Your subscription is active.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF01775A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _handlePaymentFailed(String message) {
    setState(() {
      _isProcessing = false;
      _statusMessage = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handlePaymentTimeout() {
    setState(() {
      _isProcessing = false;
      _statusMessage = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment verification timeout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Check your notifications or refresh the page',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up timer to prevent memory leaks
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider directly so UI updates when subscription status changes
    final authProvider = Provider.of<AuthProvider>(context);
    final isActive = authProvider.user?.hasActiveSubscription ?? false;

    return ListTile(
      leading: Icon(
        isActive ? Icons.check_circle_outline : Icons.refresh,
        color: isActive ? AppColors.primary : Colors.orange.shade700,
      ),
      title: Text(
        isActive ? 'Active' : 'Renew',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: _statusMessage.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : null,
      trailing: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Subscribe',
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppColors.primary : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      onTap: _isProcessing ? null : (isActive ? null : _renewSubscription),
    );
  }
}
