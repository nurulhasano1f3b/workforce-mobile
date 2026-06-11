import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/shift.dart';
import 'local_db.dart';

/// ShiftsRepository — local-first cache for GET /m/roster/my.
///
/// - [shifts] is a [ValueNotifier] loaded from SQLite on init (zero network).
/// - [refresh()] pulls from the server and merges into cache + in-memory list.
/// - 404 from the server (flag off) sets [featureAvailable] to false — the UI
///   shows a graceful "feature not available" message instead of an error.
class ShiftsRepository {
  ShiftsRepository({
    String? baseUrl,
    http.Client? httpClient,
    LocalDb? db,
  })  : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client(),
        _db = db ?? LocalDb.instance;

  final String _base;
  final http.Client _http;
  final LocalDb _db;

  String? _token;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  /// Upcoming shifts, soonest first.  Loaded from cache before any network call.
  final ValueNotifier<List<Shift>> shifts = ValueNotifier(const []);

  /// False when the server returned 404 (roster feature flag is off).
  final ValueNotifier<bool> featureAvailable = ValueNotifier(true);

  /// True while a background refresh is in-flight.
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> init(String? token) async {
    _token = token;
    await _loadFromCache();
    // Background refresh; do not await — cache already shown.
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token != null) _refreshFromServer();
  }

  // ---------------------------------------------------------------------------
  // Cache load
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    final rows = await _db.queryShiftsSince(since);
    shifts.value = rows.map(Shift.fromSqlite).toList();
  }

  // ---------------------------------------------------------------------------
  // Network refresh
  // ---------------------------------------------------------------------------

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/roster/my'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 404) {
        featureAvailable.value = false;
        return;
      }
      if (resp.statusCode != 200) return;

      featureAvailable.value = true;
      final list = jsonDecode(resp.body) as List<dynamic>;
      final now = DateTime.now();

      // Full re-cache: clear old rows then insert fresh data.
      await _db.deleteAllShifts();
      for (final item in list) {
        final shift = Shift.fromJson(item as Map<String, dynamic>);
        await _db.upsertShift(shift.toSqliteRow(now));
      }
      await _loadFromCache();
    } on SocketException {
      // Offline — cached data already shown, nothing to do.
    } on http.ClientException {
      // Network error — silently ignore.
    } catch (_) {
      // Any other error — silently ignore.
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    shifts.dispose();
    featureAvailable.dispose();
    isLoading.dispose();
    _http.close();
  }
}
