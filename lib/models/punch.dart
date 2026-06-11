import 'dart:convert';

/// The four punch types the server accepts.
/// Values map exactly to what POST /m/timecard/punch expects in the `type` field.
enum PunchType {
  clockIn('in'),
  clockOut('out'),
  breakStart('unpaid_in'),
  breakEnd('unpaid_out');

  const PunchType(this.serverValue);

  /// The raw string sent to / received from the server.
  final String serverValue;

  static PunchType fromServerValue(String v) {
    return PunchType.values.firstWhere(
      (e) => e.serverValue == v,
      orElse: () => throw ArgumentError('Unknown punch type: $v'),
    );
  }

  /// Human-readable label shown in the punch history list.
  String get label => switch (this) {
        PunchType.clockIn => 'Clocked in',
        PunchType.clockOut => 'Clocked out',
        PunchType.breakStart => 'Break started',
        PunchType.breakEnd => 'Break ended',
      };
}

/// State machine: given the last punch type, which types are valid next?
/// Mirrors VALID_NEXT in timecard/index.js exactly.
///
///   none        → [in]
///   in          → [unpaid_in, out]
///   unpaid_in   → [unpaid_out]
///   unpaid_out  → [unpaid_in, out]
///   out         → [in]
const Map<String, List<String>> kValidNext = {
  'none': ['in'],
  'in': ['unpaid_in', 'out'],
  'unpaid_in': ['unpaid_out'],
  'unpaid_out': ['unpaid_in', 'out'],
  'out': ['in'],
};

/// Returns the primary action button the UI should show given [lastType].
/// When the user is clocked in they see "Clock Out" (and a secondary "Start Break").
/// This function returns the *primary* next action only.
PunchType primaryNextPunch(String lastType) {
  final valid = kValidNext[lastType] ?? ['in'];
  return PunchType.fromServerValue(valid.last);
}

/// Label for the primary action button.
String primaryActionLabel(String lastType) {
  return switch (lastType) {
    'none' => 'Clock In',
    'in' => 'Clock Out',
    'unpaid_in' => 'End Break',
    'unpaid_out' => 'Clock Out',
    'out' => 'Clock In',
    _ => 'Clock In',
  };
}

/// True when there is a secondary "Start Break" action available.
/// Only valid when last type is 'in' (clocked in, not on break).
bool hasSecondaryAction(String lastType) => lastType == 'in';

/// A single punch record. May be local-only (pendingSync true) or
/// confirmed by the server (serverId non-null).
class Punch {
  const Punch({
    required this.localId,
    required this.type,
    required this.deviceTs,
    this.serverId,
    this.serverTs,
    this.effectiveTs,
    this.flags = const {},
    this.pendingSync = false,
    this.isOffline = false,
  });

  /// SQLite auto-increment id — always present after insertion.
  final int localId;

  final PunchType type;

  /// Moment the user tapped the button. Sent as deviceTs in the API body.
  final DateTime deviceTs;

  /// Null until the server 201 response is received.
  final int? serverId;
  final DateTime? serverTs;
  final DateTime? effectiveTs;

  /// Server flags, e.g. {"irregular": "unexpected after 'in'", "device clock drift": true}.
  final Map<String, dynamic> flags;

  /// True while awaiting a confirmed server response.
  final bool pendingSync;

  /// True if the punch was created while the device was offline.
  final bool isOffline;

  bool get isIrregular => flags.containsKey('irregular');

  /// The timestamp to display in the UI. Uses effectiveTs once confirmed,
  /// deviceTs while pending — so the row never looks blank.
  DateTime get displayTs => effectiveTs ?? deviceTs;

  Punch copyWith({
    int? serverId,
    DateTime? serverTs,
    DateTime? effectiveTs,
    Map<String, dynamic>? flags,
    bool? pendingSync,
    bool? isOffline,
  }) {
    return Punch(
      localId: localId,
      type: type,
      deviceTs: deviceTs,
      serverId: serverId ?? this.serverId,
      serverTs: serverTs ?? this.serverTs,
      effectiveTs: effectiveTs ?? this.effectiveTs,
      flags: flags ?? this.flags,
      pendingSync: pendingSync ?? this.pendingSync,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  /// Build from an SQLite row (column names defined in local_db.dart).
  factory Punch.fromSqlite(Map<String, dynamic> row) {
    return Punch(
      localId: row['id'] as int,
      type: PunchType.fromServerValue(row['type'] as String),
      deviceTs: DateTime.parse(row['device_ts'] as String),
      serverId: row['server_id'] as int?,
      serverTs:
          row['server_ts'] != null ? DateTime.parse(row['server_ts'] as String) : null,
      effectiveTs: row['effective_ts'] != null
          ? DateTime.parse(row['effective_ts'] as String)
          : null,
      flags: row['flags'] != null
          ? Map<String, dynamic>.from(
              jsonDecode(row['flags'] as String) as Map,
            )
          : {},
      pendingSync: (row['pending_sync'] as int) == 1,
      isOffline: (row['is_offline'] as int) == 1,
    );
  }

  /// Map for SQLite INSERT (omits 'id' — let the DB assign it).
  Map<String, dynamic> toSqliteInsert() {
    return {
      'type': type.serverValue,
      'device_ts': deviceTs.toIso8601String(),
      'server_id': serverId,
      'server_ts': serverTs?.toIso8601String(),
      'effective_ts': effectiveTs?.toIso8601String(),
      'flags': flags.isEmpty ? '{}' : jsonEncode(flags),
      'pending_sync': pendingSync ? 1 : 0,
      'is_offline': isOffline ? 1 : 0,
    };
  }

  /// Build a confirmed Punch from a server 201 response.
  /// [localId] and [deviceTs] are taken from the already-stored local row so
  /// they are never lost.
  factory Punch.fromServerResponse({
    required int localId,
    required PunchType type,
    required DateTime deviceTs,
    required Map<String, dynamic> json,
    required bool isOffline,
  }) {
    return Punch(
      localId: localId,
      type: type,
      deviceTs: deviceTs,
      serverId: json['id'] as int?,
      serverTs: json['server_ts'] != null
          ? DateTime.parse(json['server_ts'] as String)
          : null,
      effectiveTs: json['effective_ts'] != null
          ? DateTime.parse(json['effective_ts'] as String)
          : null,
      flags: (json['flags'] as Map<String, dynamic>?) ?? {},
      pendingSync: false,
      isOffline: isOffline,
    );
  }
}
