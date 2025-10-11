import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/posts_service.dart';
import '../../../core/services/echo_service.dart';

class CommentsProvider extends ChangeNotifier {
  final PostsService _postsService;
  final Map<String, List<Comment>> _commentsByPostId = {};
  final Set<String> _subscribedChannels = {};
  final Set<String> _loadedPostIds = {};
  final Map<int, bool> _votingInProgress = {}; // Lock to prevent concurrent votes

  CommentsProvider({PostsService? postsService})
      : _postsService = postsService ?? PostsService();

  List<Comment> getComments(String postId) {
    return _commentsByPostId[postId] ?? [];
  }

  Comment? getComment(String postId, int commentId) {
    final comments = _commentsByPostId[postId];
    if (comments == null) return null;

    try {
      return comments.firstWhere((c) => c.id == commentId);
    } catch (e) {
      return null;
    }
  }

  bool hasLoadedComments(String postId) {
    return _loadedPostIds.contains(postId);
  }

  Future<void> loadComments(String postId, {bool forceRefresh = false}) async {
    if (_loadedPostIds.contains(postId) && !forceRefresh) {
      return;
    }

    final result = await _postsService.getComments(postId);

    if (result['success']) {
      final comments = result['comments'] ?? [];
      _commentsByPostId[postId] = comments;
      _loadedPostIds.add(postId);
      notifyListeners();
      _subscribeToRealtime(postId);
    }
  }

  void _subscribeToRealtime(String postId) async {
    final channelName = 'post.$postId';
    if (_subscribedChannels.contains(channelName)) {
      return;
    }

    await EchoService.connect();
    await EchoService.subscribe(channelName);
    _subscribedChannels.add(channelName);

    EchoService.listen(channelName, 'comment.created', (data) {
      try {
        final Map<String, dynamic> eventData = data is String ? jsonDecode(data) : data;
        final commentData = eventData['comment'] ?? eventData['data'] ?? eventData;

        if (commentData == null) {
          return;
        }

        final newComment = Comment.fromJson(commentData);
        final comments = _commentsByPostId[postId] ?? [];
        final now = DateTime.now();

        final existsById = comments.any((c) => c.id == newComment.id);
        if (existsById) {
          return;
        }

        final isDuplicateContent = comments.any((c) {
          final timeDiff = now.difference(c.createdAt).inSeconds.abs();
          return c.user.id == newComment.user.id &&
                 c.content == newComment.content &&
                 timeDiff < 5;
        });

        if (isDuplicateContent) {
          return;
        }

        _commentsByPostId[postId] = [newComment, ...comments];
        notifyListeners();
      } catch (e) {
        // Error parsing comment event
      }
    });

    EchoService.listen(channelName, 'comment.updated', (data) {
      try {
        final Map<String, dynamic> eventData = data is String ? jsonDecode(data) : data;
        final commentData = eventData['comment'] ?? eventData['data'] ?? eventData;

        if (commentData == null) {
          return;
        }

        final updatedComment = Comment.fromJson(commentData);
        final comments = _commentsByPostId[postId];
        if (comments == null) {
          return;
        }

        final index = comments.indexWhere((c) => c.id == updatedComment.id);
        if (index != -1) {
          _commentsByPostId[postId]![index] = updatedComment;
          notifyListeners();
        }
      } catch (e) {
        // Error parsing comment event
      }
    });

    EchoService.listen(channelName, 'comment.deleted', (data) {
      try {
        final Map<String, dynamic> eventData = data is String ? jsonDecode(data) : data;
        final commentId = eventData['comment_id'] ?? eventData['id'] ?? eventData['commentId'];

        if (commentId == null) {
          return;
        }

        final comments = _commentsByPostId[postId];
        if (comments == null) {
          return;
        }

        _commentsByPostId[postId] = comments.where((c) => c.id != commentId).toList();
        notifyListeners();
      } catch (e) {
        // Error parsing comment event
      }
    });

    EchoService.listen(channelName, 'comment.voted', (data) {
      try {
        final Map<String, dynamic> eventData = data is String ? jsonDecode(data) : data;
        final commentId = eventData['comment_id'];
        final score = eventData['score'];

        if (commentId == null || score == null) {
          return;
        }

        if (_votingInProgress[commentId] == true) {
          return;
        }

        final comments = _commentsByPostId[postId];
        if (comments == null) {
          return;
        }

        final index = comments.indexWhere((c) => c.id == commentId);
        if (index != -1) {
          _commentsByPostId[postId]![index] = comments[index].copyWith(score: score);
          notifyListeners();
        }
      } catch (e) {
        // Error parsing comment event
      }
    });
  }

  void unsubscribeFromPost(String postId) async {
    final channelName = 'post.$postId';
    if (!_subscribedChannels.contains(channelName)) return;

    EchoService.stopListening(channelName, 'comment.created');
    EchoService.stopListening(channelName, 'comment.updated');
    EchoService.stopListening(channelName, 'comment.deleted');
    EchoService.stopListening(channelName, 'comment.voted');
    await EchoService.unsubscribe(channelName);
    _subscribedChannels.remove(channelName);
  }

  Future<void> toggleUpvote(String postId, int commentId) async {
    if (_votingInProgress[commentId] == true) {
      return;
    }

    final comments = _commentsByPostId[postId];
    if (comments == null) {
      return;
    }

    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) {
      return;
    }

    _votingInProgress[commentId] = true;

    final comment = comments[index];
    final currentScore = comment.score;
    final currentUserVote = comment.userVote;

    int newScore;
    String? newUserVote;

    if (currentUserVote == null) {
      newScore = currentScore + 1;
      newUserVote = 'upvote';
    } else if (currentUserVote == 'upvote') {
      newScore = currentScore - 1;
      newUserVote = null;
    } else {
      newScore = currentScore + 2;
      newUserVote = 'upvote';
    }

    _commentsByPostId[postId]![index] = comment.copyWith(
      score: newScore,
      userVote: newUserVote,
    );
    notifyListeners();

    try {
      final result = await _postsService.upvoteComment(commentId);

      if (result['success']) {
        final action = result['action'];
        final serverScore = result['score'];
        String? serverUserVote;
        if (action == 'upvoted') {
          serverUserVote = 'upvote';
        } else if (action == 'removed') {
          serverUserVote = null;
        }

        _commentsByPostId[postId]![index] = comment.copyWith(
          score: serverScore,
          userVote: serverUserVote,
        );
        notifyListeners();
      } else {
        _commentsByPostId[postId]![index] = comment;
        notifyListeners();
      }
    } catch (e) {
      _commentsByPostId[postId]![index] = comment;
      notifyListeners();
    } finally {
      _votingInProgress.remove(commentId);
    }
  }

  Future<void> toggleDownvote(String postId, int commentId) async {
    if (_votingInProgress[commentId] == true) {
      return;
    }

    final comments = _commentsByPostId[postId];
    if (comments == null) {
      return;
    }

    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) {
      return;
    }

    _votingInProgress[commentId] = true;

    final comment = comments[index];
    final currentScore = comment.score;
    final currentUserVote = comment.userVote;

    int newScore;
    String? newUserVote;

    if (currentUserVote == null) {
      newScore = currentScore - 1;
      newUserVote = 'downvote';
    } else if (currentUserVote == 'downvote') {
      newScore = currentScore + 1;
      newUserVote = null;
    } else {
      newScore = currentScore - 2;
      newUserVote = 'downvote';
    }

    _commentsByPostId[postId]![index] = comment.copyWith(
      score: newScore,
      userVote: newUserVote,
    );
    notifyListeners();

    try {
      final result = await _postsService.downvoteComment(commentId);

      if (result['success']) {
        final action = result['action'];
        final serverScore = result['score'];
        String? serverUserVote;
        if (action == 'downvoted') {
          serverUserVote = 'downvote';
        } else if (action == 'removed') {
          serverUserVote = null;
        }

        _commentsByPostId[postId]![index] = comment.copyWith(
          score: serverScore,
          userVote: serverUserVote,
        );
        notifyListeners();
      } else {
        _commentsByPostId[postId]![index] = comment;
        notifyListeners();
      }
    } catch (e) {
      _commentsByPostId[postId]![index] = comment;
      notifyListeners();
    } finally {
      _votingInProgress.remove(commentId);
    }
  }

  void addComment(String postId, Comment comment) {
    final comments = _commentsByPostId[postId] ?? [];
    _commentsByPostId[postId] = [comment, ...comments];
    notifyListeners();
  }

  void insertCommentAt(String postId, Comment comment, int index) {
    final comments = _commentsByPostId[postId];
    if (comments == null) return;

    // Ensure index is valid
    final safeIndex = index.clamp(0, comments.length);
    final updatedComments = List<Comment>.from(comments);
    updatedComments.insert(safeIndex, comment);
    _commentsByPostId[postId] = updatedComments;
    notifyListeners();
  }

  void updateComment(String postId, Comment updatedComment) {
    final comments = _commentsByPostId[postId];
    if (comments == null) return;

    final index = comments.indexWhere((c) => c.id == updatedComment.id);
    if (index != -1) {
      _commentsByPostId[postId]![index] = updatedComment;
      notifyListeners();
    }
  }

  void deleteComment(String postId, int commentId) {
    final comments = _commentsByPostId[postId];
    if (comments == null) return;

    _commentsByPostId[postId] = comments.where((c) => c.id != commentId).toList();
    notifyListeners();
  }

  void replaceOptimisticComment(String postId, int tempId, Comment realComment) {
    final comments = _commentsByPostId[postId];
    if (comments == null) {
      return;
    }

    final index = comments.indexWhere((c) => c.id == tempId);
    if (index != -1) {
      _commentsByPostId[postId]![index] = realComment;
      notifyListeners();
    }
  }
}
