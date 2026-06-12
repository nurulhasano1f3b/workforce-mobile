class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.reason,
    this.fullName,
  });

  final int id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String? reason;
  final String status;
  final String createdAt;
  final String? fullName;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['id'] as int,
        leaveType: (json['leave_type'] as String?) ?? 'annual',
        startDate: (json['start_date'] as String?) ?? '',
        endDate: (json['end_date'] as String?) ?? '',
        reason: json['reason'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        createdAt: (json['created_at'] as String?) ?? '',
        fullName: json['full_name'] as String?,
      );

  Map<String, dynamic> toSqliteRow() => {
        'leave_id': id,
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        'status': status,
        'created_at': createdAt,
      };

  factory LeaveRequest.fromSqlite(Map<String, dynamic> row) => LeaveRequest(
        id: row['leave_id'] as int,
        leaveType: row['leave_type'] as String,
        startDate: row['start_date'] as String,
        endDate: row['end_date'] as String,
        reason: row['reason'] as String?,
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
      );
}
