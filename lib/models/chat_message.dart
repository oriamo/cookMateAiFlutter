enum MessageRole {
  user,
  assistant,
  system
}

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  // Getter for checking if message is from user
  bool get isUser => role == MessageRole.user;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.byName(json['role']),
      timestamp: DateTime.parse(json['timestamp']),
      isError: json['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }
}