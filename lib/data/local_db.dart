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
const _dbVersion = 3;

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

  // Migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createShiftsTable(db);
      await _createNotificationsTable(db);
    }
    if (oldVersion < 3) {
      await _createAvailTables(db);
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
}
