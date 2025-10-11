import 'package:flutter/material.dart';
import '../models/poll.dart';

class PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;

  const PollCard({
    super.key,
    required this.poll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPollIcon(),
                  size: 20,
                  color: poll.isClosed ? Colors.grey : Colors.black,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: poll.isClosed ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                if (poll.userHasVoted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Voted',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (poll.county != null) ...[
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    poll.county!.name,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${poll.totalVotes} ${poll.totalVotes == 1 ? 'vote' : 'votes'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (!poll.isClosed)
                  Text(
                    _getTimeRemaining(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPollIcon() {
    switch (poll.type) {
      case 'single_choice':
        return Icons.radio_button_checked;
      case 'yes_no':
        return Icons.thumbs_up_down;
      case 'rating':
        return Icons.star;
      default:
        return Icons.poll;
    }
  }

  String _getTimeRemaining() {
    final now = DateTime.now();
    final difference = poll.endsAt.difference(now);

    if (difference.isNegative) {
      return 'Ended';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inMinutes}m left';
    }
  }
}
