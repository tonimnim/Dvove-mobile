import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../posts/widgets/memory_optimized_image.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;

  const ChatScreen({
    super.key,
    this.sessionId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late String _currentSessionId;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      if (widget.sessionId != null) {
        _currentSessionId = widget.sessionId!;
        await _loadMessages();
      } else {
        _currentSessionId = await _chatService.createNewConversation();
      }
    } catch (e) {
      // Fallback to a temporary session ID
      _currentSessionId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> clearConversation() async {
    try {
      _currentSessionId = await _chatService.createNewConversation();
      setState(() {
        _messages.clear();
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadConversation(String sessionId) async {
    setState(() {
      _currentSessionId = sessionId;
    });
    await _loadMessages();
  }

  Future<void> _loadMessages({bool forceRefresh = false}) async {
    try {
      final messages = await _chatService.getConversationMessages(_currentSessionId, forceRefresh: forceRefresh);
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages = [];
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = ChatMessage(
      conversationId: _currentSessionId,
      message: _messageController.text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final aiResponse = await _chatService.sendMessage(userMessage.message, _currentSessionId);

      final aiMessage = ChatMessage(
        conversationId: _currentSessionId,
        message: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
    } catch (e) {
      final errorMessage = ChatMessage(
        conversationId: _currentSessionId,
        message: e.toString(),
        isUser: false,
        timestamp: DateTime.now(),
        error: 'error',
      );

      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: null, // Remove AppBar completely
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ask Dvove AI anything',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask Dvove AI...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF01775A),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isLoading ? Icons.hourglass_empty : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: message.error != null ? Colors.red.shade100 : const Color(0xFF01775A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.error != null ? Icons.error_outline : Icons.smart_toy,
                color: message.error != null ? Colors.red.shade600 : const Color(0xFF01775A),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.black
                    : (message.error != null ? Colors.red.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: message.error != null
                    ? Border.all(color: Colors.red.shade200)
                    : null,
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (message.error != null ? Colors.red.shade700 : Colors.black),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return MemoryOptimizedAvatar(
                  imageUrl: authProvider.user?.profilePhoto,
                  fallbackText: authProvider.user?.displayName ?? 'U',
                  size: 28, // radius 14 * 2 = 28
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF01775A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: const Color(0xFF01775A),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}