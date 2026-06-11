/// An inbox notification from GET /notifications.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.pendingRead = false,
  });

  final int id;
  final String body;
  final DateTime createdAt;

  /// Null means unread from server's perspective.
  final DateTime? readAt;

  /// True while a POST /notifications/:id/read is in-flight.
  final bool pendingRead;

  bool get isRead => readAt != null || pendingRead;

  /// Build from server JSON.
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      body: (json['body'] ?? json['message'] ?? '') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  /// Build from SQLite row.
  factory NotificationItem.fromSqlite(Map<String, dynamic> row) {
    return NotificationItem(
      id: row['notif_id'] as int,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      readAt: row['read_at'] != null
          ? DateTime.parse(row['read_at'] as String)
          : null,
      pendingRead: (row['pending_read'] as int? ?? 0) == 1,
    );
  }

  /// Map for SQLite upsert.
  Map<String, dynamic> toSqliteRow() {
    return {
      'notif_id': id,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'pending_read': pendingRead ? 1 : 0,
    };
  }

  NotificationItem copyWith({
    DateTime? readAt,
    bool? pendingRead,
  }) {
    return NotificationItem(
      id: id,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      pendingRead: pendingRead ?? this.pendingRead,
    );
  }
}
