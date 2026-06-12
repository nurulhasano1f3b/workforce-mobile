class Thread {
  const Thread({
    required this.id,
    required this.subject,
    required this.createdAt,
    this.lastMessage,
  });

  final int id;
  final String subject;
  final String createdAt;
  final String? lastMessage;

  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
        id: json['id'] as int,
        subject: (json['subject'] as String?) ?? '',
        createdAt: (json['created_at'] as String?) ?? '',
        lastMessage: json['last_message'] as String?,
      );
}

class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String body;
  final String createdAt;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as int,
        sender: (json['sender'] as String?) ?? '',
        body: json['body'] as String,
        createdAt: (json['created_at'] as String?) ?? '',
      );
}
