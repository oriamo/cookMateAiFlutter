enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.byName(json['role']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}