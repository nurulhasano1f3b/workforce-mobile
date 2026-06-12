import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Hand-written SQLite schema using sqflite.
/// No code generation required — avoids drift's build_runner dependency.
///
/// Tables:
///   punches        — every punch ever recorded on this device.
///   auth_state     — stores the JWT token (single row, key/value).
///   shifts         — cached upcoming shifts from GET /m/roster/my.
///   notifications  — cached inbox from GET /notifications.
///
/// The "pending_sync" column acts as the offline queue.
/// A punch with pending_sync = 1 has not yet received a 201 from the server.

const _dbName = 'workforce.db';
const _dbVersion = 6;

/// Column names — defined as constants to catch typos at compile time.
const tPunches = 'punches';
const colId = 'id';
const colType = 'type';
const colDeviceTs = 'device_ts';
const colServerId = 'server_id';
const colServerTs = 'server_ts';
const colEffectiveTs = 'effective_ts';
const colFlags = 'flags';
const colPendingSync = 'pending_sync';
const colIsOffline = 'is_offline';

const tAuth = 'auth_state';
const colKey = 'key';
const colValue = 'value';

// Shifts table
const tShifts = 'shifts';
const colShiftId = 'shift_id';
const colDept = 'department';
const colStartsAt = 'starts_at';
const colEndsAt = 'ends_at';
const colStatus = 'status';
const colCachedAt = 'cached_at';

// Notifications table
const tNotifications = 'notifications';
const colNotifId = 'notif_id';
const colBody = 'body';
const colReadAt = 'read_at';
const colCreatedAt = 'created_at';
const colPendingRead = 'pending_read';

// Roster requests table
const tRosterRequests = 'roster_requests';
const colRequestId = 'request_id';
const colPrevStartsAt = 'prev_starts_at';
const colPrevEndsAt = 'prev_ends_at';
const colPrevDept = 'prev_dept';

// Announcements table
const tAnnouncements = 'announcements';
const colAnnouncementTitle = 'title';

// Leaves table
const tLeaves = 'leaves';
const colLeaveId = 'leave_id';
const colLeaveType = 'leave_type';
const colStartDate = 'start_date';
const colEndDate = 'end_date';
const colReason = 'reason';

// Payslips table
const tPayslips = 'payslips';
const colPayslipId = 'payslip_id';
const colPeriodStart = 'period_start';
const colPeriodEnd = 'period_end';
const colGrossCents = 'gross_cents';
const colNetCents = 'net_cents';
const colDocumentUrl = 'document_url';

// Availability tables
const tAvailPatterns = 'avail_patterns';
const tAvailExceptions = 'avail_exceptions';
const colWeekday = 'weekday';
const colStartMin = 'start_min';
const colEndMin = 'end_min';
const colDay = 'day';
const colAvailable = 'available';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // On web, getDatabasesPath() returns null; use a bare filename (IndexedDB key).
    final dbPath = kIsWeb
        ? _dbName
        : p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tPunches (
        $colId          INTEGER PRIMARY KEY AUTOINCREMENT,
        $colType        TEXT    NOT NULL,
        $colDeviceTs    TEXT    NOT NULL,
        $colServerId    INTEGER,
        $colServerTs    TEXT,
        $colEffectiveTs TEXT,
        $colFlags       TEXT    NOT NULL DEFAULT '{}',
        $colPendingSync INTEGER NOT NULL DEFAULT 1,
        $colIsOffline   INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index for the common query: today's punches, most recent first.
    await db.execute('''
      CREATE INDEX idx_punches_device_ts ON $tPunches ($colDeviceTs DESC)
    ''');

    // Index for the pending-sync queue flush.
    await db.execute('''
      CREATE INDEX idx_punches_pending ON $tPunches ($colPendingSync)
        WHERE $colPendingSync = 1
    ''');

    await db.execute('''
      CREATE TABLE $tAuth (
        $colKey   TEXT PRIMARY KEY,
        $colValue TEXT NOT NULL
      )
    ''');

    await _createShiftsTable(db);
    await _createNotificationsTable(db);
    await _createAvailTables(db);
    await _createRosterRequestsTable(db);
    await _createAnnouncementsTable(db);
    await _createLeavesTable(db);
    await _createPayslipsTable(db);
  }

  Future<void> _createShiftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tShifts (
        $colId        INTEGER PRIMARY KEY AUTOINCREMENT,
        $colShiftId   INTEGER UNIQUE,
        $colDept      TEXT,
        $colStartsAt  TEXT NOT NULL,
        $colEndsAt    TEXT NOT NULL,
        $colStatus    TEXT NOT NULL DEFAULT 'published',
        $colCachedAt  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_shifts_starts ON $tShifts ($colStartsAt ASC)
    ''');
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tNotifications (
        $colId          INTEGER PRIMARY KEY AUTOINCREMENT,
        $colNotifId     INTEGER UNIQUE,
        $colBody        TEXT NOT NULL,
        $colReadAt      TEXT,
        $colCreatedAt   TEXT NOT NULL,
        $colPendingRead INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_notif_created ON $tNotifications ($colCreatedAt DESC)
    ''');
  }

  Future<void> _createAvailTables(Database db) async {
    await db.execute('''
      CREATE TABLE $tAvailPatterns (
        $colWeekday   INTEGER NOT NULL,
        $colStartMin  INTEGER NOT NULL,
        $colEndMin    INTEGER NOT NULL,
        PRIMARY KEY ($colWeekday, $colStartMin)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tAvailExceptions (
        $colDay       TEXT    NOT NULL PRIMARY KEY,
        $colAvailable INTEGER NOT NULL,
        $colStartMin  INTEGER,
        $colEndMin    INTEGER
      )
    ''');
  }

  Future<void> _createAnnouncementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tAnnouncements (
        $colNotifId    INTEGER PRIMARY KEY,
        $colAnnouncementTitle TEXT NOT NULL,
        $colBody       TEXT,
        $colCreatedAt  TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createLeavesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tLeaves (
        $colLeaveId   INTEGER PRIMARY KEY,
        $colLeaveType TEXT NOT NULL,
        $colStartDate TEXT NOT NULL,
        $colEndDate   TEXT NOT NULL,
        $colReason    TEXT,
        $colStatus    TEXT NOT NULL,
        $colCreatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPayslipsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tPayslips (
        $colPayslipId  INTEGER PRIMARY KEY,
        $colPeriodStart TEXT NOT NULL,
        $colPeriodEnd   TEXT NOT NULL,
        $colGrossCents  INTEGER NOT NULL,
        $colNetCents    INTEGER NOT NULL,
        $colDocumentUrl TEXT
      )
    ''');
  }

  Future<void> _createRosterRequestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tRosterRequests (
        $colRequestId   INTEGER PRIMARY KEY,
        $colStatus      TEXT    NOT NULL,
        $colStartsAt    TEXT    NOT NULL,
        $colEndsAt      TEXT    NOT NULL,
        $colDept        TEXT,
        $colPrevStartsAt TEXT,
        $colPrevEndsAt   TEXT,
        $colPrevDept     TEXT
      )
    ''');
  }

  // Migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createShiftsTable(db);
      await _createNotificationsTable(db);
    }
    if (oldVersion < 3) {
      await _createAvailTables(db);
    }
    if (oldVersion < 4) {
      await _createRosterRequestsTable(db);
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE $tRosterRequests ADD COLUMN $colPrevStartsAt TEXT');
      await db.execute(
          'ALTER TABLE $tRosterRequests ADD COLUMN $colPrevEndsAt TEXT');
      await db.execute(
          'ALTER TABLE $tRosterRequests ADD COLUMN $colPrevDept TEXT');
    }
    if (oldVersion < 6) {
      await _createAnnouncementsTable(db);
      await _createLeavesTable(db);
      await _createPayslipsTable(db);
    }
  }

  // ---------------------------------------------------------------------------
  // Punch helpers (used by PunchRepository — no business logic here)
  // ---------------------------------------------------------------------------

  /// Insert a new punch row and return its autoincrement id.
  Future<int> insertPunch(Map<String, dynamic> row) async {
    final d = await db;
    return d.insert(tPunches, row);
  }

  /// Update a punch row by its local id.
  Future<void> updatePunch(int localId, Map<String, dynamic> values) async {
    final d = await db;
    await d.update(
      tPunches,
      values,
      where: '$colId = ?',
      whereArgs: [localId],
    );
  }

  /// Load punches for a date range, newest first.
  /// [since] is an ISO-8601 string; pass null to get all rows.
  Future<List<Map<String, dynamic>>> queryPunchesSince(String since) async {
    final d = await db;
    return d.query(
      tPunches,
      where: '$colDeviceTs >= ?',
      whereArgs: [since],
      orderBy: '$colDeviceTs DESC',
    );
  }

  /// All rows with pending_sync = 1, oldest first (preserve submission order).
  Future<List<Map<String, dynamic>>> queryPendingPunches() async {
    final d = await db;
    return d.query(
      tPunches,
      where: '$colPendingSync = ?',
      whereArgs: [1],
      orderBy: '$colId ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // Auth helpers
  // ---------------------------------------------------------------------------

  Future<String?> readAuthValue(String key) async {
    final d = await db;
    final rows = await d.query(
      tAuth,
      columns: [colValue],
      where: '$colKey = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first[colValue] as String?;
  }

  Future<void> writeAuthValue(String key, String value) async {
    final d = await db;
    await d.insert(
      tAuth,
      {colKey: key, colValue: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAuthValue(String key) async {
    final d = await db;
    await d.delete(tAuth, where: '$colKey = ?', whereArgs: [key]);
  }

  // ---------------------------------------------------------------------------
  // Shifts helpers
  // ---------------------------------------------------------------------------

  /// Upsert a shift row by server shift_id.
  Future<void> upsertShift(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(
      tShifts,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load upcoming shifts (starts_at >= [since]), soonest first.
  Future<List<Map<String, dynamic>>> queryShiftsSince(String since) async {
    final d = await db;
    return d.query(
      tShifts,
      where: '$colStartsAt >= ?',
      whereArgs: [since],
      orderBy: '$colStartsAt ASC',
    );
  }

  /// Delete all cached shifts — called before a full re-cache.
  Future<void> deleteAllShifts() async {
    final d = await db;
    await d.delete(tShifts);
  }

  /// Wipe all user-owned tables in one transaction — call on logout so no
  /// data leaks to the next account that logs in on the same device.
  Future<void> clearUserData() async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tPunches);
      await txn.delete(tShifts);
      await txn.delete(tNotifications);
      await txn.delete(tAvailPatterns);
      await txn.delete(tAvailExceptions);
      await txn.delete(tRosterRequests);
      await txn.delete(tAnnouncements);
      await txn.delete(tLeaves);
      await txn.delete(tPayslips);
    });
  }

  // ---------------------------------------------------------------------------
  // Notifications helpers
  // ---------------------------------------------------------------------------

  /// Upsert a notification row by server notif_id.
  Future<void> upsertNotification(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(
      tNotifications,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load all notifications, newest first.
  Future<List<Map<String, dynamic>>> queryNotifications() async {
    final d = await db;
    return d.query(tNotifications, orderBy: '$colCreatedAt DESC');
  }

  /// Mark a notification as read locally (pending server confirmation).
  Future<void> markNotificationRead(int notifId, String readAt) async {
    final d = await db;
    await d.update(
      tNotifications,
      {colReadAt: readAt, colPendingRead: 0},
      where: '$colNotifId = ?',
      whereArgs: [notifId],
    );
  }

  /// Set pending_read flag on a notification (optimistic, before server ACK).
  Future<void> setNotificationPendingRead(int notifId) async {
    final d = await db;
    await d.update(
      tNotifications,
      {colPendingRead: 1},
      where: '$colNotifId = ?',
      whereArgs: [notifId],
    );
  }

  // ---------------------------------------------------------------------------
  // Availability helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> queryAvailPatterns() async {
    final d = await db;
    return d.query(tAvailPatterns, orderBy: '$colWeekday ASC, $colStartMin ASC');
  }

  Future<void> replaceAvailPatterns(List<Map<String, dynamic>> rows) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tAvailPatterns);
      for (final row in rows) {
        await txn.insert(tAvailPatterns, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> queryAvailExceptions() async {
    final d = await db;
    return d.query(tAvailExceptions, orderBy: '$colDay ASC');
  }

  Future<void> upsertAvailException(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(tAvailExceptions, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Roster requests helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> queryRosterRequests() async {
    final d = await db;
    return d.query(tRosterRequests, orderBy: '$colStartsAt ASC');
  }

  Future<void> replaceRosterRequests(List<Map<String, dynamic>> rows) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tRosterRequests);
      for (final row in rows) {
        await txn.insert(tRosterRequests, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteRosterRequest(int requestId) async {
    final d = await db;
    await d.delete(tRosterRequests,
        where: '$colRequestId = ?', whereArgs: [requestId]);
  }

  // ---------------------------------------------------------------------------
  // Announcements helpers
  // ---------------------------------------------------------------------------

  Future<void> upsertAnnouncement(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(tAnnouncements, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAnnouncements() async {
    final d = await db;
    return d.query(tAnnouncements, orderBy: '$colCreatedAt DESC');
  }

  Future<void> replaceAnnouncements(List<Map<String, dynamic>> rows) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tAnnouncements);
      for (final row in rows) {
        await txn.insert(tAnnouncements, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Leaves helpers
  // ---------------------------------------------------------------------------

  Future<void> upsertLeave(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(tLeaves, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryLeaves() async {
    final d = await db;
    return d.query(tLeaves, orderBy: '$colCreatedAt DESC');
  }

  Future<void> replaceLeaves(List<Map<String, dynamic>> rows) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tLeaves);
      for (final row in rows) {
        await txn.insert(tLeaves, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Payslips helpers
  // ---------------------------------------------------------------------------

  Future<void> upsertPayslip(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(tPayslips, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryPayslips() async {
    final d = await db;
    return d.query(tPayslips, orderBy: '$colPeriodEnd DESC');
  }

  Future<void> replacePayslips(List<Map<String, dynamic>> rows) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(tPayslips);
      for (final row in rows) {
        await txn.insert(tPayslips, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
