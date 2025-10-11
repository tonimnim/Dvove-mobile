import 'package:flutter/material.dart';
import '../models/poll.dart';

class VoteWidget extends StatefulWidget {
  final Poll poll;
  final Function(Map<String, dynamic>) onVote;
  final bool isSubmitting;

  const VoteWidget({
    super.key,
    required this.poll,
    required this.onVote,
    required this.isSubmitting,
  });

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  int? _selectedOptionId;
  bool? _selectedAnswer;
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.poll.userHasVoted) {
      return _buildResults();
    }

    if (!widget.poll.canVote || widget.poll.isClosed) {
      return _buildCannotVote();
    }

    return _buildVoteForm();
  }

  Widget _buildVoteForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.poll.isSingleChoice)
          _buildSingleChoice()
        else if (widget.poll.isYesNo)
          _buildYesNo()
        else if (widget.poll.isRating)
          _buildRating(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canSubmit() && !widget.isSubmitting ? _handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: widget.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Vote'),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleChoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.poll.options.map((option) {
        final isSelected = _selectedOptionId == option.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedOptionId = option.id;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.optionText,
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected ? Colors.black : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYesNo() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedAnswer = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedAnswer == true ? Colors.green.shade50 : Colors.white,
                border: Border.all(
                  color: _selectedAnswer == true ? Colors.green : Colors.grey.shade300,
                  width: _selectedAnswer == true ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.thumb_up,
                    color: _selectedAnswer == true ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedAnswer == true ? FontWeight.w600 : FontWeight.normal,
                      color: _selectedAnswer == true ? Colors.green : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedAnswer = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedAnswer == false ? Colors.red.shade50 : Colors.white,
                border: Border.all(
                  color: _selectedAnswer == false ? Colors.red : Colors.grey.shade300,
                  width: _selectedAnswer == false ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.thumb_down,
                    color: _selectedAnswer == false ? Colors.red : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedAnswer == false ? FontWeight.w600 : FontWeight.normal,
                      color: _selectedAnswer == false ? Colors.red : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRating() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return IconButton(
              onPressed: () {
                setState(() {
                  _selectedRating = index;
                });
              },
              icon: Icon(
                index <= _selectedRating ? Icons.star : Icons.star_border,
                color: index <= _selectedRating ? Colors.amber : Colors.grey,
                size: 40,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRating == 0 ? 'Tap to rate' : '$_selectedRating/5',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (!widget.poll.canShowResults) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Results will be available ${_getResultsAvailability()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'You have voted',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Results',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.poll.isSingleChoice)
          ...widget.poll.options.map((option) {
            final percentage = widget.poll.totalVotes > 0
                ? (option.voteCount / widget.poll.totalVotes) * 100
                : 0.0;
            return _buildResultBar(option.optionText, option.voteCount, percentage);
          }).toList()
        else if (widget.poll.isRating)
          _buildRatingResults()
        else if (widget.poll.isYesNo)
          _buildYesNoResults(),
      ],
    );
  }

  Widget _buildRatingResults() {
    final averageRating = widget.poll.averageRating ?? 0.0;
    final fullStars = averageRating.floor();
    final hasHalfStar = (averageRating - fullStars) >= 0.5;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Text(
                'Average Rating',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                averageRating > 0 ? '${averageRating.toStringAsFixed(1)}/5' : 'No ratings yet',
                style: TextStyle(
                  fontSize: averageRating > 0 ? 48 : 24,
                  fontWeight: FontWeight.bold,
                  color: averageRating > 0 ? Colors.black : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  IconData iconData;
                  if (index < fullStars) {
                    iconData = Icons.star;
                  } else if (index == fullStars && hasHalfStar) {
                    iconData = Icons.star_half;
                  } else {
                    iconData = Icons.star_border;
                  }
                  return Icon(
                    iconData,
                    color: Colors.amber,
                    size: 36,
                  );
                }),
              ),
              if (widget.poll.userVote != null && widget.poll.userVote!['rating'] != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Your rating: ${widget.poll.userVote!['rating']}/5',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYesNoResults() {
    // For yes/no polls, show results if available
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.thumb_up, color: Colors.green, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Yes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.poll.totalVotes} votes',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.thumb_down, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'No',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '0 votes',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBar(String label, int votes, double percentage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$votes ${votes == 1 ? 'vote' : 'votes'} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCannotVote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.block, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            widget.poll.isClosed ? 'This poll has ended' : 'You cannot vote on this poll',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    if (widget.poll.isSingleChoice) {
      return _selectedOptionId != null;
    } else if (widget.poll.isYesNo) {
      return _selectedAnswer != null;
    } else if (widget.poll.isRating) {
      return _selectedRating > 0;
    }
    return false;
  }

  void _handleSubmit() {
    Map<String, dynamic> voteData;

    if (widget.poll.isSingleChoice) {
      voteData = {'option_id': _selectedOptionId};
    } else if (widget.poll.isYesNo) {
      voteData = {'answer': _selectedAnswer};
    } else {
      voteData = {'rating': _selectedRating};
    }

    widget.onVote(voteData);
  }

  String _getResultsAvailability() {
    if (widget.poll.showResults == 'after_vote') {
      return 'after you vote';
    } else if (widget.poll.showResults == 'after_close') {
      return 'when the poll closes';
    }
    return 'soon';
  }
}
