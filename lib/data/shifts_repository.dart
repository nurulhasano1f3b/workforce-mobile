import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/shift.dart';
import 'local_db.dart';

/// ShiftsRepository — local-first cache for roster data.
///
/// - [shifts]   upcoming shifts from GET /m/roster/my
/// - [requests] pending shift requests from GET /m/roster/requests/my
/// - [peers]    colleagues on shift from GET /m/roster/peers (no SQLite cache)
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

  /// Upcoming shifts, soonest first.
  final ValueNotifier<List<Shift>> shifts = ValueNotifier(const []);

  /// Pending shift requests the user needs to accept or decline.
  final ValueNotifier<List<ShiftRequest>> requests = ValueNotifier(const []);

  /// Colleagues working at the same time (real-time, no SQLite cache).
  final ValueNotifier<List<ShiftPeer>> peers = ValueNotifier(const []);

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
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      shifts.value = const [];
      requests.value = const [];
      peers.value = const [];
    } else {
      _refreshFromServer();
    }
  }

  // ---------------------------------------------------------------------------
  // Cache load
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    final shiftRows = await _db.queryShiftsSince(since);
    shifts.value = shiftRows.map(Shift.fromSqlite).toList();

    final reqRows = await _db.queryRosterRequests();
    requests.value = reqRows.map(ShiftRequest.fromSqlite).toList();
  }

  // ---------------------------------------------------------------------------
  // Network refresh
  // ---------------------------------------------------------------------------

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      // Fire all three in parallel.
      final results = await Future.wait([
        _http.get(Uri.parse('$_base/m/roster/my'),
            headers: {'Authorization': 'Bearer $_token'}),
        _http.get(Uri.parse('$_base/m/roster/requests/my'),
            headers: {'Authorization': 'Bearer $_token'}),
        _http.get(Uri.parse('$_base/m/roster/peers'),
            headers: {'Authorization': 'Bearer $_token'}),
      ]);

      final shiftsResp = results[0];
      final requestsResp = results[1];
      final peersResp = results[2];

      // Shifts
      if (shiftsResp.statusCode == 404) {
        featureAvailable.value = false;
      } else if (shiftsResp.statusCode == 200) {
        featureAvailable.value = true;
        final list = jsonDecode(shiftsResp.body) as List<dynamic>;
        final now = DateTime.now();
        await _db.deleteAllShifts();
        for (final item in list) {
          final shift = Shift.fromJson(item as Map<String, dynamic>);
          await _db.upsertShift(shift.toSqliteRow(now));
        }
        await _loadShiftsFromCache();
      }

      // Requests
      if (requestsResp.statusCode == 200) {
        final list = jsonDecode(requestsResp.body) as List<dynamic>;
        final parsed =
            list.map((e) => ShiftRequest.fromJson(e as Map<String, dynamic>)).toList();
        await _db.replaceRosterRequests(
            parsed.map((r) => r.toSqliteRow()).toList());
        requests.value = parsed;
      }

      // Peers (no SQLite cache — real-time only)
      if (peersResp.statusCode == 200) {
        final list = jsonDecode(peersResp.body) as List<dynamic>;
        peers.value =
            list.map((e) => ShiftPeer.fromJson(e as Map<String, dynamic>)).toList();
      }
    } on SocketException {
      // Offline — cached data already shown.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any other error.
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadShiftsFromCache() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    final rows = await _db.queryShiftsSince(since);
    shifts.value = rows.map(Shift.fromSqlite).toList();
  }

  // ---------------------------------------------------------------------------
  // Respond to a shift request
  // ---------------------------------------------------------------------------

  Future<bool> respondToRequest(int requestId, bool accept) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/roster/requests/$requestId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'accept': accept}),
      );
      if (resp.statusCode != 200) return false;
      // Remove from local cache immediately.
      await _db.deleteRosterRequest(requestId);
      requests.value =
          requests.value.where((r) => r.id != requestId).toList();
      // Refresh shifts since accepting a request makes it published.
      unawaited(_refreshFromServer());
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    shifts.dispose();
    requests.dispose();
    peers.dispose();
    featureAvailable.dispose();
    isLoading.dispose();
    _http.close();
  }
}
