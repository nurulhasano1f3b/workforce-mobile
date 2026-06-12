import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/leave.dart';
import 'local_db.dart';

class LeavesRepository {
  LeavesRepository({
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

  final ValueNotifier<List<LeaveRequest>> myLeaves = ValueNotifier(const []);
  final ValueNotifier<List<LeaveRequest>> queue = ValueNotifier(const []);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(String? token) async {
    _token = token;
    await _loadFromCache();
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      myLeaves.value = const [];
      queue.value = const [];
    } else {
      unawaited(_refreshFromServer());
    }
  }

  Future<void> _loadFromCache() async {
    final rows = await _db.queryLeaves();
    myLeaves.value = rows.map(LeaveRequest.fromSqlite).toList();
  }

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/leaves/my'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        final parsed = list
            .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
            .toList();
        await _db.replaceLeaves(parsed.map((l) => l.toSqliteRow()).toList());
        myLeaves.value = parsed;
      }
    } on SocketException {
      // Offline — cached data shown.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any other error.
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshQueue() async {
    if (_token == null) return;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/leaves/queue'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        queue.value = list
            .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on SocketException {
      // Offline.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any other error.
    }
  }

  Future<bool> submitLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/leaves/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );
      if (resp.statusCode != 201) return false;
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

  Future<bool> decideLeave(int leaveId, bool approve) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/leaves/$leaveId/decide'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'approve': approve}),
      );
      if (resp.statusCode != 200) return false;
      queue.value = queue.value.where((l) => l.id != leaveId).toList();
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    myLeaves.dispose();
    queue.dispose();
    isLoading.dispose();
    _http.close();
  }
}
