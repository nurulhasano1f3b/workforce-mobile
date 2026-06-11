import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/punch.dart';
import 'local_db.dart';

const _tokenKey = 'auth_token';
const _emailKey = 'auth_email';

/// PunchRepository — the single source of truth for punch data.
///
/// Contract:
///   - Widgets observe [punches] (a [ValueNotifier]) and never touch HTTP.
///   - [recordPunch] is the only way to create a punch.  It:
///       1. Writes to SQLite immediately (< 5 ms on device).
///       2. Updates [punches] and [lastPunchType] synchronously.
///       3. Attempts the HTTP call in the background.
///       4. On success: updates the local row with server ids / timestamps.
///       5. On failure: leaves pending_sync=1 — the offline queue drains on
///          the next connectivity change.
///   - The offline queue is flushed when connectivity is restored via the
///     Connectivity stream.
///   - [isSyncing] is true while any HTTP call is in-flight — the UI shows
///     a subtle icon (not a spinner) while this is true.
class PunchRepository {
  PunchRepository({
    String? baseUrl,
    http.Client? httpClient,
    LocalDb? db,
    FlutterSecureStorage? secureStorage,
  })  : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client(),
        _db = db ?? LocalDb.instance,
        _storage = secureStorage ?? const FlutterSecureStorage();

  final String _base;
  final http.Client _http;
  final LocalDb _db;
  final FlutterSecureStorage _storage;

  // ---------------------------------------------------------------------------
  // Public state — widgets listen to these
  // ---------------------------------------------------------------------------

  /// Today's punches, newest first.  Updated optimistically on every tap.
  final ValueNotifier<List<Punch>> punches = ValueNotifier(const []);

  /// The type of the most recent punch, or 'none'.  Drives the UI button label.
  final ValueNotifier<String> lastPunchType = ValueNotifier('none');

  /// True while any background sync is in-flight.
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  // Connectivity subscription — kept alive for the lifetime of the app.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  String? _token;
  int _syncInFlight = 0;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  /// Loads the cached punches synchronously (from SQLite) so the first frame
  /// is already populated — no network call blocks the initial render.
  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    await _loadTodayFromCache();
    _startConnectivityWatcher();
    // Background refresh — do not await.  First paint is already done.
    unawaited(_refreshFromServer());
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<bool> login(String email, String password) async {
    try {
      final resp = await _http.post(
        Uri.parse('$_base/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (resp.statusCode != 200) return false;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = body['token'] as String?;
      if (token == null) return false;
      _token = token;
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);
      // Kick off a background server refresh now that we have a token.
      // Do not await — the cached state is already shown in the UI.
      unawaited(_refreshFromServer());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _db.clearUserData();
    punches.value = const [];
    lastPunchType.value = 'none';
  }

  bool get isLoggedIn => _token != null;

  /// The JWT token — null when not logged in.
  /// Used by other repositories to share the same credential.
  String? get token => _token;

  // ---------------------------------------------------------------------------
  // Core operation: record a punch
  // ---------------------------------------------------------------------------

  /// Called by the UI when the user taps the punch button.
  ///
  /// Returns in < 5 ms (SQLite write only).  The HTTP call happens in the
  /// background.  The UI must never await this for its first-paint update.
  Future<void> recordPunch(PunchType type) async {
    final now = DateTime.now();

    // 1. Write to SQLite and update in-memory state as fast as possible.
    //    We start with isOffline=false; if connectivity check later returns
    //    false, the sync attempt will fail and the row stays pending_sync=1.
    //    Connectivity check runs in parallel with the SQLite write.
    final connectivityFuture = _hasConnectivity();

    final localId = await _db.insertPunch(Punch(
      localId: 0,
      type: type,
      deviceTs: now,
      pendingSync: true,
      isOffline: false, // refined below after connectivity resolves
    ).toSqliteInsert());

    final localPunch = Punch(
      localId: localId,
      type: type,
      deviceTs: now,
      pendingSync: true,
      isOffline: false,
    );

    // 2. Optimistic update — happens before the connectivity check resolves.
    _upsertInMemory(localPunch);
    lastPunchType.value = type.serverValue;

    // 3. Now resolve connectivity (was running in parallel with the DB write).
    final isOnline = await connectivityFuture;

    if (isOnline) {
      // 4a. Online: sync in background.
      unawaited(_syncPunch(localPunch));
    } else {
      // 4b. Offline: mark the row as offline so the flush will send offline:true.
      await _db.updatePunch(localId, {colIsOffline: 1});
      // The connectivity watcher will call _flushOfflineQueue() on reconnect.
    }
  }

  // ---------------------------------------------------------------------------
  // Background sync
  // ---------------------------------------------------------------------------

  Future<void> _syncPunch(Punch punch) async {
    _incrementSyncing();
    try {
      final confirmed = await _postPunch(punch);
      if (confirmed != null) {
        await _db.updatePunch(punch.localId, {
          colServerId: confirmed.serverId,
          colServerTs: confirmed.serverTs?.toIso8601String(),
          colEffectiveTs: confirmed.effectiveTs?.toIso8601String(),
          colFlags: confirmed.flags.isEmpty ? '{}' : jsonEncode(confirmed.flags),
          colPendingSync: 0,
        });
        _upsertInMemory(confirmed);
      }
    } catch (_) {
      // Network error — leave pending_sync=1, will retry on reconnect.
    } finally {
      _decrementSyncing();
    }
  }

  /// POST /m/timecard/punch and return a confirmed Punch, or null on error.
  Future<Punch?> _postPunch(Punch punch) async {
    if (_token == null) return null;
    try {
      final body = <String, dynamic>{
        'type': punch.type.serverValue,
        'deviceTs': punch.deviceTs.toIso8601String(),
        if (punch.isOffline) 'offline': true,
      };
      final resp = await _http.post(
        Uri.parse('$_base/m/timecard/punch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode != 201) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return Punch.fromServerResponse(
        localId: punch.localId,
        type: punch.type,
        deviceTs: punch.deviceTs,
        json: json,
        isOffline: punch.isOffline,
      );
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  /// Flush all pending punches in insertion order (oldest first).
  Future<void> _flushOfflineQueue() async {
    if (_token == null) return;
    final pending = await _db.queryPendingPunches();
    if (pending.isEmpty) return;
    _incrementSyncing();
    try {
      for (final row in pending) {
        final punch = Punch.fromSqlite(row);
        final confirmed = await _postPunch(punch);
        if (confirmed != null) {
          await _db.updatePunch(punch.localId, {
            colServerId: confirmed.serverId,
            colServerTs: confirmed.serverTs?.toIso8601String(),
            colEffectiveTs: confirmed.effectiveTs?.toIso8601String(),
            colFlags:
                confirmed.flags.isEmpty ? '{}' : jsonEncode(confirmed.flags),
            colPendingSync: 0,
          });
          _upsertInMemory(confirmed);
        } else {
          // One failure aborts the queue to preserve ordering.
          break;
        }
      }
    } finally {
      _decrementSyncing();
    }
  }

  /// Pull the last 14 days from GET /m/timecard/my and merge into cache.
  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    _incrementSyncing();
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/timecard/my'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode != 200) return;
      final list = jsonDecode(resp.body) as List<dynamic>;
      for (final item in list) {
        final json = item as Map<String, dynamic>;
        // Server row — upsert by server_id.
        await _upsertServerPunch(json);
      }
      await _loadTodayFromCache();
    } catch (_) {
      // Silently ignore — cached data is already shown.
    } finally {
      _decrementSyncing();
    }
  }

  /// Insert or update a punch row received from the server GET /my response.
  Future<void> _upsertServerPunch(Map<String, dynamic> json) async {
    final serverId = json['id'] as int?;
    if (serverId == null) return;
    final typeStr = json['type'] as String?;
    if (typeStr == null) return;
    PunchType type;
    try {
      type = PunchType.fromServerValue(typeStr);
    } catch (_) {
      return;
    }

    // Check if we already have this server punch.
    final d = await _db.db;
    final existing = await d.query(
      tPunches,
      where: '$colServerId = ?',
      whereArgs: [serverId],
    );

    final serverTs = json['server_ts'] != null
        ? DateTime.parse(json['server_ts'] as String)
        : null;
    final effectiveTs = json['effective_ts'] != null
        ? DateTime.parse(json['effective_ts'] as String)
        : null;
    final flags =
        (json['flags'] as Map<String, dynamic>?) ?? {};

    if (existing.isEmpty) {
      await _db.insertPunch({
        colType: type.serverValue,
        colDeviceTs: (json['device_ts'] as String?) ??
            (serverTs ?? DateTime.now()).toIso8601String(),
        colServerId: serverId,
        colServerTs: serverTs?.toIso8601String(),
        colEffectiveTs: effectiveTs?.toIso8601String(),
        colFlags: flags.isEmpty ? '{}' : jsonEncode(flags),
        colPendingSync: 0,
        colIsOffline: (json['offline'] as bool? ?? false) ? 1 : 0,
      });
    } else {
      await _db.updatePunch(existing.first[colId] as int, {
        colEffectiveTs: effectiveTs?.toIso8601String(),
        colFlags: flags.isEmpty ? '{}' : jsonEncode(flags),
        colPendingSync: 0,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // In-memory list management
  // ---------------------------------------------------------------------------

  Future<void> _loadTodayFromCache() async {
    final todayStart = DateTime.now();
    final since = DateTime(todayStart.year, todayStart.month, todayStart.day)
        .toIso8601String();
    final rows = await _db.queryPunchesSince(since);
    final loaded = rows.map(Punch.fromSqlite).toList();
    punches.value = loaded;
    lastPunchType.value =
        loaded.isEmpty ? 'none' : loaded.first.type.serverValue;
  }

  /// Update or prepend a punch in the in-memory list.
  void _upsertInMemory(Punch punch) {
    final current = List<Punch>.from(punches.value);
    final idx = current.indexWhere((p) => p.localId == punch.localId);
    if (idx >= 0) {
      current[idx] = punch;
    } else {
      current.insert(0, punch);
    }
    punches.value = current;
    if (current.isNotEmpty) {
      lastPunchType.value = current.first.type.serverValue;
    }
  }

  // ---------------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------------

  void _startConnectivityWatcher() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final online = results
          .any((r) => r != ConnectivityResult.none);
      if (online) {
        await _flushOfflineQueue();
        unawaited(_refreshFromServer());
      }
    });
  }

  Future<bool> _hasConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Syncing counter — drives isSyncing notifier
  // ---------------------------------------------------------------------------

  void _incrementSyncing() {
    _syncInFlight++;
    if (_syncInFlight == 1) isSyncing.value = true;
  }

  void _decrementSyncing() {
    if (_syncInFlight > 0) _syncInFlight--;
    if (_syncInFlight == 0) isSyncing.value = false;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    _connectivitySub?.cancel();
    punches.dispose();
    lastPunchType.dispose();
    isSyncing.dispose();
    _http.close();
  }
}
