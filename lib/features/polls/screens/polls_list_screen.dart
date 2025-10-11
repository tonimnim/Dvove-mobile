import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poll.dart';
import '../widgets/poll_card.dart';
import '../providers/polls_provider.dart';
import 'poll_detail_screen.dart';

class PollsListScreen extends StatefulWidget {
  const PollsListScreen({super.key});

  @override
  State<PollsListScreen> createState() => _PollsListScreenState();
}

class _PollsListScreenState extends State<PollsListScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize only active polls (current tab) - load closed polls when user switches tabs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pollsProvider = context.read<PollsProvider>();
      pollsProvider.initializeActivePolls();
    });

    // Listen to tab changes to lazy-load closed polls
    _tabController?.addListener(() {
      if (_tabController!.index == 1) {
        context.read<PollsProvider>().initializeClosedPolls();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Polls',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(
                color: Colors.grey.shade300,
                height: 1,
              ),
              TabBar(
                controller: _tabController!,
                indicatorColor: Colors.black,
                indicatorWeight: 1.5,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Closed'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Consumer<PollsProvider>(
        builder: (context, pollsProvider, child) {
          return TabBarView(
            controller: _tabController!,
            children: [
              _buildPollsList(
                pollsProvider.activePolls,
                pollsProvider.isLoadingActive,
                pollsProvider.activeError,
                () => pollsProvider.loadActivePolls(),
              ),
              _buildPollsList(
                pollsProvider.closedPolls,
                pollsProvider.isLoadingClosed,
                pollsProvider.closedError,
                () => pollsProvider.loadClosedPolls(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPollsList(List<Poll> polls, bool isLoading, String? errorMessage, Future<void> Function() onRefresh) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (errorMessage != null) {
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
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (polls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.poll_outlined,
                size: 80,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                'No polls found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for new polls',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.black,
      child: ListView.builder(
        itemCount: polls.length,
        itemBuilder: (context, index) {
          final poll = polls[index];
          return PollCard(
            poll: poll,
            onTap: () => _openPollDetail(poll),
          );
        },
      ),
    );
  }

  void _openPollDetail(Poll poll) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PollDetailScreen(pollId: poll.id),
      ),
    );

    if (result == true && mounted) {
      context.read<PollsProvider>().refreshAll();
    }
  }
}
