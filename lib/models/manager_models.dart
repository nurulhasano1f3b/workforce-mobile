class StaffMember {
  const StaffMember({required this.id, required this.fullName, this.email});
  final int id;
  final String fullName;
  final String? email;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        email: json['email'] as String?,
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

/// One staff member's availability + scheduled shifts for a given day.
class StaffDayView {
  const StaffDayView({
    required this.userId,
    required this.fullName,
    required this.available,
    this.startMin,
    this.endMin,
    this.isException = false,
    this.shifts = const [],
  });

  final int userId;
  final String fullName;

  /// null = availability module not active / no data.
  final bool? available;
  final int? startMin;
  final int? endMin;
  final bool isException;
  final List<TeamShift> shifts;

  factory StaffDayView.fromJson(Map<String, dynamic> json) {
    final shiftList = (json['shifts'] as List<dynamic>? ?? [])
        .map((e) => TeamShift.fromJson(e as Map<String, dynamic>))
        .toList();
    return StaffDayView(
      userId: json['userId'] as int,
      fullName: json['fullName'] as String,
      available: json['available'] as bool?,
      startMin: json['startMin'] as int?,
      endMin: json['endMin'] as int?,
      isException: (json['isException'] as bool?) ?? false,
      shifts: shiftList,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class LeaveQueueItem {
  const LeaveQueueItem({
    required this.id,
    required this.fullName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final int id;
  final String fullName;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String? reason;

  factory LeaveQueueItem.fromJson(Map<String, dynamic> json) =>
      LeaveQueueItem(
        id: json['id'] as int,
        fullName: (json['full_name'] as String?) ?? '',
        leaveType: (json['leave_type'] as String?) ?? 'annual',
        startDate: (json['start_date'] as String?) ?? '',
        endDate: (json['end_date'] as String?) ?? '',
        reason: json['reason'] as String?,
      );
}

class FixRequestQueueItem {
  const FixRequestQueueItem({
    required this.id,
    required this.fullName,
    required this.proposedTs,
    required this.reason,
    required this.createdAt,
    this.punchType,
    this.originalType,
    this.originalTs,
  });

  final int id;
  final String fullName;
  final String proposedTs;
  final String reason;
  final String createdAt;
  final String? punchType;
  final String? originalType;
  final String? originalTs;

  factory FixRequestQueueItem.fromJson(Map<String, dynamic> json) =>
      FixRequestQueueItem(
        id: json['id'] as int,
        fullName: (json['full_name'] as String?) ?? '',
        proposedTs: (json['proposed_ts'] as String?) ?? '',
        reason: (json['reason'] as String?) ?? '',
        createdAt: (json['created_at'] as String?) ?? '',
        punchType: json['punch_type'] as String?,
        originalType: json['original_type'] as String?,
        originalTs: json['original_ts'] as String?,
      );
}

/// A shift on the team view (manager perspective).
class TeamShift {
  const TeamShift({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    this.department,
    required this.status,
  });

  final int id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? department;
  final String status;

  factory TeamShift.fromJson(Map<String, dynamic> json) => TeamShift(
        id: json['id'] as int,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        department: json['department'] as String?,
        status: json['status'] as String,
      );

  Duration get duration => endsAt.difference(startsAt);
}
