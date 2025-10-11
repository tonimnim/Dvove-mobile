import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/polls_service.dart';
import '../models/poll.dart';
import '../providers/polls_provider.dart';
import '../widgets/vote_widget.dart';

class PollDetailScreen extends StatefulWidget {
  final int pollId;

  const PollDetailScreen({
    super.key,
    required this.pollId,
  });

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  final PollsService _pollsService = PollsService();
  Poll? _poll;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPoll();
  }

  Future<void> _loadPoll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _pollsService.getPoll(widget.pollId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _poll = result['poll'];
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  Future<void> _submitVote(Map<String, dynamic> voteData) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final result = await _pollsService.vote(widget.pollId, voteData);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (result['success']) {
        setState(() {
          _poll = result['poll'];
        });

        // Update the poll in the provider cache
        context.read<PollsProvider>().updatePoll(result['poll']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, _poll?.userHasVoted ?? false),
        ),
        title: const Text(
          'Poll',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade300,
            height: 1,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPoll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_poll == null) {
      return const Center(
        child: Text('Poll not found'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _poll!.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_poll!.county != null) ...[
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _poll!.county!.name,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.people, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${_poll!.totalVotes} ${_poll!.totalVotes == 1 ? 'vote' : 'votes'}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ends: ${_formatDate(_poll!.endsAt)}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          VoteWidget(
            poll: _poll!,
            onVote: _submitVote,
            isSubmitting: _isSubmitting,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
