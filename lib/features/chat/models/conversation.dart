class Conversation {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int messageCount;

  Conversation({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.messageCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.millisecondsSinceEpoch,
      'message_count': messageCount,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      lastMessage: map['last_message'] ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(map['last_message_time'] ?? 0),
      messageCount: map['message_count']?.toInt() ?? 0,
    );
  }
}