import 'package:flutter/material.dart';
import '../../../core/utils/constants.dart';
import '../services/subscription_service.dart';

class SubscriptionListTile extends StatefulWidget {
  final String phoneNumber;
  final bool hasActiveSubscription;

  const SubscriptionListTile({
    super.key,
    required this.phoneNumber,
    required this.hasActiveSubscription,
  });

  @override
  State<SubscriptionListTile> createState() => _SubscriptionListTileState();
}

class _SubscriptionListTileState extends State<SubscriptionListTile> {
  bool _isRenewing = false;
  final SubscriptionService _subscriptionService = SubscriptionService();

  Future<void> _renewSubscription() async {
    setState(() {
      _isRenewing = true;
    });

    try {
      await _subscriptionService.renewSubscription(widget.phoneNumber);

      if (mounted) {
        setState(() {
          _isRenewing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRenewing = false;
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

  @override
  Widget build(BuildContext context) {
    final isActive = widget.hasActiveSubscription;

    return ListTile(
      leading: Icon(
        isActive ? Icons.check_circle_outline : Icons.refresh,
        color: isActive ? AppColors.primary : Colors.orange.shade700,
      ),
      title: Text(
        isActive ? 'Active' : 'Renew',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: _isRenewing
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
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
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
      onTap: _isRenewing ? null : (isActive ? null : _renewSubscription),
    );
  }
}
