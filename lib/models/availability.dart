import 'package:flutter/material.dart';

const List<String> kWeekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
}

TimeOfDay minutesToTimeOfDay(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

int timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

class AvailPattern {
  final int weekday; // 0=Sun … 6=Sat
  final int startMin;
  final int endMin;

  const AvailPattern({
    required this.weekday,
    required this.startMin,
    required this.endMin,
  });

  factory AvailPattern.fromJson(Map<String, dynamic> json) => AvailPattern(
        weekday: json['weekday'] as int,
        startMin: json['start_min'] as int,
        endMin: json['end_min'] as int,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'startMin': startMin,
        'endMin': endMin,
      };

  Map<String, dynamic> toSqliteRow() => {
        'weekday': weekday,
        'start_min': startMin,
        'end_min': endMin,
      };

  factory AvailPattern.fromSqlite(Map<String, dynamic> row) => AvailPattern(
        weekday: row['weekday'] as int,
        startMin: row['start_min'] as int,
        endMin: row['end_min'] as int,
      );

  AvailPattern copyWith({int? weekday, int? startMin, int? endMin}) =>
      AvailPattern(
        weekday: weekday ?? this.weekday,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
      );
}

class AvailException {
  final String day; // YYYY-MM-DD
  final bool available;
  final int? startMin;
  final int? endMin;

  const AvailException({
    required this.day,
    required this.available,
    this.startMin,
    this.endMin,
  });

  factory AvailException.fromJson(Map<String, dynamic> json) => AvailException(
        day: json['day'] as String,
        available: json['available'] as bool,
        startMin: json['start_min'] as int?,
        endMin: json['end_min'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'available': available,
        if (startMin != null) 'startMin': startMin,
        if (endMin != null) 'endMin': endMin,
      };

  Map<String, dynamic> toSqliteRow() => {
        'day': day,
        'available': available ? 1 : 0,
        'start_min': startMin,
        'end_min': endMin,
      };

  factory AvailException.fromSqlite(Map<String, dynamic> row) => AvailException(
        day: row['day'] as String,
        available: (row['available'] as int) == 1,
        startMin: row['start_min'] as int?,
        endMin: row['end_min'] as int?,
      );
}

class AvailabilityData {
  final List<AvailPattern> pattern;
  final List<AvailException> exceptions;

  const AvailabilityData({required this.pattern, required this.exceptions});

  static const empty = AvailabilityData(pattern: [], exceptions: []);
}
