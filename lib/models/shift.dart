/// A roster shift as returned by GET /m/roster/my.
class Shift {
  const Shift({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    this.department,
    this.status = 'published',
  });

  final int id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? department;
  final String status;

  /// Build from the server JSON (GET /m/roster/my response item).
  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      department: json['department'] as String?,
      status: (json['status'] as String?) ?? 'published',
    );
  }

  /// Build from a SQLite row.
  factory Shift.fromSqlite(Map<String, dynamic> row) {
    return Shift(
      id: row['shift_id'] as int,
      startsAt: DateTime.parse(row['starts_at'] as String),
      endsAt: DateTime.parse(row['ends_at'] as String),
      department: row['department'] as String?,
      status: (row['status'] as String?) ?? 'published',
    );
  }

  /// Map for SQLite upsert.
  Map<String, dynamic> toSqliteRow(DateTime cachedAt) {
    return {
      'shift_id': id,
      'department': department,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'status': status,
      'cached_at': cachedAt.toIso8601String(),
    };
  }

  Duration get duration => endsAt.difference(startsAt);

  bool get isUpcoming => startsAt.isAfter(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return startsAt.year == now.year &&
        startsAt.month == now.month &&
        startsAt.day == now.day;
  }
}
