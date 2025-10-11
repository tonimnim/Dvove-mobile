import 'package:flutter/foundation.dart';
import '../models/poll.dart';
import '../services/polls_service.dart';

class PollsProvider extends ChangeNotifier {
  final PollsService _pollsService = PollsService();

  // Cached polls
  List<Poll> _activePolls = [];
  List<Poll> _closedPolls = [];

  // Loading states
  bool _isLoadingActive = false;
  bool _isLoadingClosed = false;

  // Error messages
  String? _activeError;
  String? _closedError;

  // Cache timestamp
  DateTime? _lastActiveLoad;
  DateTime? _lastClosedLoad;

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Getters
  List<Poll> get activePolls => _activePolls;
  List<Poll> get closedPolls => _closedPolls;
  bool get isLoadingActive => _isLoadingActive;
  bool get isLoadingClosed => _isLoadingClosed;
  String? get activeError => _activeError;
  String? get closedError => _closedError;

  /// Initialize active polls (with cache check)
  Future<void> initializeActivePolls({bool forceRefresh = false}) async {
    // Check cache freshness
    if (!forceRefresh &&
        _activePolls.isNotEmpty &&
        _lastActiveLoad != null &&
        DateTime.now().difference(_lastActiveLoad!) < _cacheDuration) {
      return; // Use cached data
    }

    await loadActivePolls();
  }

  /// Initialize closed polls (with cache check)
  Future<void> initializeClosedPolls({bool forceRefresh = false}) async {
    // Check cache freshness
    if (!forceRefresh &&
        _closedPolls.isNotEmpty &&
        _lastClosedLoad != null &&
        DateTime.now().difference(_lastClosedLoad!) < _cacheDuration) {
      return; // Use cached data
    }

    await loadClosedPolls();
  }

  /// Load active polls from API
  Future<void> loadActivePolls() async {
    _isLoadingActive = true;
    _activeError = null;
    notifyListeners();

    final result = await _pollsService.getPolls(status: 'active');

    if (result['success']) {
      _activePolls = result['polls'];
      _lastActiveLoad = DateTime.now();
      _activeError = null;
    } else {
      _activeError = result['message'];
    }

    _isLoadingActive = false;
    notifyListeners();
  }

  /// Load closed polls from API
  Future<void> loadClosedPolls() async {
    _isLoadingClosed = true;
    _closedError = null;
    notifyListeners();

    final result = await _pollsService.getPolls(status: 'closed');

    if (result['success']) {
      _closedPolls = result['polls'];
      _lastClosedLoad = DateTime.now();
      _closedError = null;
    } else {
      _closedError = result['message'];
    }

    _isLoadingClosed = false;
    notifyListeners();
  }

  /// Update a poll after voting
  void updatePoll(Poll updatedPoll) {
    // Update in active polls
    final activeIndex = _activePolls.indexWhere((p) => p.id == updatedPoll.id);
    if (activeIndex != -1) {
      _activePolls[activeIndex] = updatedPoll;
    }

    // Update in closed polls
    final closedIndex = _closedPolls.indexWhere((p) => p.id == updatedPoll.id);
    if (closedIndex != -1) {
      _closedPolls[closedIndex] = updatedPoll;
    }

    notifyListeners();
  }

  /// Refresh both active and closed polls
  Future<void> refreshAll() async {
    await Future.wait([
      loadActivePolls(),
      loadClosedPolls(),
    ]);
  }

  /// Clear cache
  void clearCache() {
    _activePolls = [];
    _closedPolls = [];
    _lastActiveLoad = null;
    _lastClosedLoad = null;
    _activeError = null;
    _closedError = null;
    notifyListeners();
  }
}
