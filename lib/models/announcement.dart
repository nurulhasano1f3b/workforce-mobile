class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.createdAt,
    this.body,
    this.author,
  });

  final int id;
  final String title;
  final String? body;
  final String createdAt;
  final String? author;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String?,
        createdAt: (json['created_at'] as String?) ?? '',
        author: json['author'] as String?,
      );

  Map<String, dynamic> toSqliteRow() => {
        'notif_id': id,
        'title': title,
        'body': body,
        'created_at': createdAt,
      };

  factory Announcement.fromSqlite(Map<String, dynamic> row) => Announcement(
        id: row['notif_id'] as int,
        title: row['title'] as String,
        body: row['body'] as String?,
        createdAt: row['created_at'] as String,
      );
}
