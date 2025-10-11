import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

  // Cache keys
  static const String _conversationsKey = 'cached_conversations';
  static const String _conversationsCacheTimeKey = 'conversations_cache_time';
  static const String _messagesPrefix = 'cached_messages_';
  static const Duration _cacheDuration = Duration(minutes: 10);

  Future<String> createNewConversation() async {
    try {
      final response = await _apiClient.post('/ai/conversations/new');
      if (response.data['success']) {
        return response.data['data']['session_id'];
      } else {
        throw Exception('Failed to create new conversation');
      }
    } catch (e) {
      throw Exception('Failed to create new conversation: $e');
    }
  }

  Future<List<ChatMessage>> getConversationMessages(String sessionId, {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('$_messagesPrefix$sessionId');
        if (cachedData != null) {
          final List<dynamic> messagesData = jsonDecode(cachedData);
          return messagesData.map((data) => ChatMessage(
            message: data['message'] ?? '',
            isUser: data['isUser'] ?? false,
            timestamp: DateTime.parse(data['timestamp']),
            conversationId: sessionId,
          )).toList();
        }
      }

      // Fetch from API
      final response = await _apiClient.get('/ai/conversations/$sessionId');

      if (response.data['success'] == true) {
        final Map<String, dynamic> conversationData = response.data['data'] ?? {};
        final List<dynamic> messagesData = conversationData['messages'] ?? [];

        final messages = messagesData.map((data) => ChatMessage(
          message: data['message'] ?? '',
          isUser: data['type'] == 'user',
          timestamp: data['timestamp'] != null
            ? DateTime.parse(data['timestamp'])
            : DateTime.now(),
          conversationId: sessionId,
        )).toList();

        // Cache messages
        final prefs = await SharedPreferences.getInstance();
        final cacheData = messages.map((msg) => {
          'message': msg.message,
          'isUser': msg.isUser,
          'timestamp': msg.timestamp.toIso8601String(),
        }).toList();
        await prefs.setString('$_messagesPrefix$sessionId', jsonEncode(cacheData));

        return messages;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<String> sendMessage(String message, String sessionId) async {
    try {
      final response = await _apiClient.dio.post('/ai/chat',
        data: {
          'message': message,
          'session_id': sessionId,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.data['success']) {
        // Invalidate message cache for this session
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_messagesPrefix$sessionId');

        return response.data['data']['response'];
      } else {
        throw Exception(response.data['message'] ?? 'Failed to get AI response');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('Daily AI chat limit reached. Try again tomorrow.');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('AI response took too long. Please try again.');
      }
      throw Exception('Failed to send message: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<List<Conversation>> getConversations({bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(_conversationsKey);
        final cacheTime = prefs.getString(_conversationsCacheTimeKey);

        if (cachedData != null && cacheTime != null) {
          final cacheDateTime = DateTime.parse(cacheTime);
          if (DateTime.now().difference(cacheDateTime) < _cacheDuration) {
            final List<dynamic> conversationsData = jsonDecode(cachedData);
            return conversationsData.map((data) => Conversation(
              id: data['id'] ?? '',
              title: data['title'] ?? '',
              lastMessage: data['lastMessage'] ?? '',
              lastMessageTime: DateTime.parse(data['lastMessageTime']),
              messageCount: data['messageCount'] ?? 0,
            )).toList();
          }
        }
      }

      // Fetch from API
      final response = await _apiClient.get('/ai/conversations');

      if (response.data['success'] == true) {
        final List<dynamic> conversationsData = response.data['data'] ?? [];
        if (conversationsData.isEmpty) {
          return [];
        }

        final conversations = conversationsData.map((data) => Conversation(
          id: data['session_id'] ?? '',
          title: _formatConversationTitle(
            data['last_message_at'] != null || data['last_message_time'] != null
              ? DateTime.parse(data['last_message_at'] ?? data['last_message_time'])
              : DateTime.now()
          ),
          lastMessage: data['preview'] ?? data['last_message'] ?? 'Tap to view conversation',
          lastMessageTime: data['last_message_at'] != null || data['last_message_time'] != null
            ? DateTime.parse(data['last_message_at'] ?? data['last_message_time'])
            : DateTime.now(),
          messageCount: data['message_count'] ?? 0,
        )).toList();

        // Cache conversations
        final prefs = await SharedPreferences.getInstance();
        final cacheData = conversations.map((conv) => {
          'id': conv.id,
          'title': conv.title,
          'lastMessage': conv.lastMessage,
          'lastMessageTime': conv.lastMessageTime.toIso8601String(),
          'messageCount': conv.messageCount,
        }).toList();
        await prefs.setString(_conversationsKey, jsonEncode(cacheData));
        await prefs.setString(_conversationsCacheTimeKey, DateTime.now().toIso8601String());

        return conversations;
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 500) {
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteConversation(String sessionId) async {
    try {
      final response = await _apiClient.dio.delete('/ai/conversations/$sessionId');

      if (response.data['success'] == true) {
        // Clear cache for this conversation
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_messagesPrefix$sessionId');
        await prefs.remove(_conversationsKey); // Invalidate conversations list
        await prefs.remove(_conversationsCacheTimeKey);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Clear all chat caches (for logout)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    // Remove all message caches and conversation cache
    for (final key in keys) {
      if (key.startsWith(_messagesPrefix) ||
          key == _conversationsKey ||
          key == _conversationsCacheTimeKey) {
        await prefs.remove(key);
      }
    }
  }

  String _formatConversationTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final conversationDate = DateTime(date.year, date.month, date.day);

    if (conversationDate == today) {
      return 'Today';
    } else if (conversationDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(conversationDate).inDays < 7) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}