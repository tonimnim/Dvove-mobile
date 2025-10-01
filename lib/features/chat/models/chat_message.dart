class ChatMessage {
  final int? id;
  final String conversationId;
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? error;

  ChatMessage({
    this.id,
    String? conversationId,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.error,
  }) : conversationId = conversationId ?? generateConversationId(timestamp);

  static String generateConversationId(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  static String generateNewConversationId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'message': message,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'error': error,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toInt(),
      conversationId: map['conversation_id'] ?? '',
      message: map['message'] ?? '',
      isUser: (map['is_user'] ?? 0) == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      error: map['error'],
    );
  }
}