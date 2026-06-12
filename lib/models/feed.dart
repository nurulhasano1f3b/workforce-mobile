class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.body,
    required this.commentCount,
    required this.createdAt,
  });

  final int id;
  final String author;
  final String body;
  final int commentCount;
  final String createdAt;

  factory FeedPost.fromJson(Map<String, dynamic> json) => FeedPost(
        id: json['id'] as int,
        author: (json['author'] as String?) ?? '',
        body: json['body'] as String,
        commentCount: (json['comments'] as int?) ?? 0,
        createdAt: (json['created_at'] as String?) ?? '',
      );
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String author;
  final String body;
  final String createdAt;

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
        id: json['id'] as int,
        author: (json['author'] as String?) ?? '',
        body: json['body'] as String,
        createdAt: (json['created_at'] as String?) ?? '',
      );
}
