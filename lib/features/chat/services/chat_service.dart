import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

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

  Future<List<ChatMessage>> getConversationMessages(String sessionId) async {
    try {
      final response = await _apiClient.get('/ai/conversations/$sessionId');
      print('Messages response for $sessionId: ${response.data}'); // Debug log

      if (response.data['success'] == true) {
        final Map<String, dynamic> conversationData = response.data['data'] ?? {};
        final List<dynamic> messagesData = conversationData['messages'] ?? [];

        return messagesData.map((data) => ChatMessage(
          message: data['message'] ?? '',
          isUser: data['type'] == 'user', // Backend uses 'type' field
          timestamp: data['timestamp'] != null
            ? DateTime.parse(data['timestamp'])
            : DateTime.now(),
          conversationId: sessionId,
        )).toList();
      } else {
        print('Messages API returned success=false: ${response.data}');
        return []; // Return empty list for new conversations
      }
    } catch (e) {
      print('Error loading conversation messages: $e');
      return []; // Return empty list instead of throwing
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
          receiveTimeout: const Duration(seconds: 60), // 60 seconds for AI processing
        ),
      );

      if (response.data['success']) {
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

  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _apiClient.get('/ai/conversations');
      print('Conversations response: ${response.data}'); // Debug log

      if (response.data['success'] == true) {
        final List<dynamic> conversationsData = response.data['data'] ?? [];
        if (conversationsData.isEmpty) {
          return []; // Return empty list if no conversations
        }

        return conversationsData.map((data) => Conversation(
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
      } else {
        print('API returned success=false: ${response.data}');
        return []; // Return empty list instead of throwing
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 500) {
        print('Backend SQL error - conversations endpoint needs fixing: ${e.response?.data}');
        // For now, return empty list until backend is fixed
        return [];
      }
      print('Error loading conversations: $e');
      return []; // Return empty list instead of crashing
    } catch (e) {
      print('Error loading conversations: $e');
      return []; // Return empty list instead of crashing
    }
  }

  Future<bool> deleteConversation(String sessionId) async {
    try {
      final response = await _apiClient.dio.delete('/ai/conversations/$sessionId');
      print('Delete response for $sessionId: ${response.data}');

      if (response.data['success'] == true) {
        return true;
      } else {
        print('Delete API returned success=false: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      return false;
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