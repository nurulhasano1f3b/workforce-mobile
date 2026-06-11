import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/manager_models.dart';

class ManagerRepository {
  ManagerRepository({String? baseUrl, http.Client? httpClient})
      : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;
  String? _token;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  /// True if the current user has manager (roster.edit) access.
  final ValueNotifier<bool> isManager = ValueNotifier(false);

  final ValueNotifier<List<StaffMember>> staff = ValueNotifier(const []);

  final ValueNotifier<DateTime> selectedDate =
      ValueNotifier(DateTime.now());

  final ValueNotifier<List<StaffDayView>> dailyView =
      ValueNotifier(const []);

  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  // ---------------------------------------------------------------------------
  // Init / token
  // ---------------------------------------------------------------------------

  Future<void> init(String? token) async {
    _token = token;
    if (token == null) return;
    await _fetchStaff();
    if (isManager.value) await _fetchDaily(selectedDate.value);
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      isManager.value = false;
      staff.value = const [];
      dailyView.value = const [];
    } else {
      unawaited(init(token));
    }
  }

  // ---------------------------------------------------------------------------
  // Date navigation
  // ---------------------------------------------------------------------------

  Future<void> setDate(DateTime date) async {
    selectedDate.value = date;
    await _fetchDaily(date);
  }

  Future<void> refresh() async {
    await _fetchDaily(selectedDate.value);
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  Future<void> _fetchStaff() async {
    if (_token == null) return;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/roster/staff'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        staff.value = list
            .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
            .toList();
        isManager.value = true;
      } else {
        isManager.value = false;
      }
    } on SocketException {
      // Offline — leave isManager as-is.
    } on http.ClientException {
      // Network error.
    }
  }

  Future<void> _fetchDaily(DateTime date) async {
    if (_token == null || !isManager.value) return;
    isLoading.value = true;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/roster/manager/daily?date=$dateStr'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        dailyView.value = list
            .map((e) => StaffDayView.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on SocketException {
      // Offline.
    } on http.ClientException {
      // Network error.
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Create a shift and immediately attempt to publish it.
  /// Returns (shiftId, status) where status is 'published' or 'pending_accept'.
  Future<({int shiftId, String status})?> createAndPublish({
    required int userId,
    required DateTime startsAt,
    required DateTime endsAt,
    String department = 'general',
  }) async {
    if (_token == null) return null;
    try {
      // 1. Create draft.
      final createResp = await _http.post(
        Uri.parse('$_base/m/roster'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'userId': userId,
          'startsAt': startsAt.toIso8601String(),
          'endsAt': endsAt.toIso8601String(),
          'department': department,
        }),
      );
      if (createResp.statusCode != 201) return null;
      final shiftId = (jsonDecode(createResp.body) as Map)['id'] as int;

      // 2. Publish (triggers availability check server-side).
      final pubResp = await _http.post(
        Uri.parse('$_base/m/roster/$shiftId/publish'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (pubResp.statusCode != 200) return null;
      final pubStatus =
          (jsonDecode(pubResp.body) as Map)['status'] as String? ??
              'published';

      unawaited(_fetchDaily(selectedDate.value));
      return (shiftId: shiftId, status: pubStatus);
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  /// Publish an existing draft shift.
  Future<({String status})?> publishShift(int shiftId) async {
    if (_token == null) return null;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/roster/$shiftId/publish'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode != 200) return null;
      final status =
          (jsonDecode(resp.body) as Map)['status'] as String? ?? 'published';
      unawaited(_fetchDaily(selectedDate.value));
      return (status: status);
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  /// Delete a draft/declined shift.
  Future<bool> deleteShift(int shiftId) async {
    if (_token == null) return false;
    try {
      final resp = await _http.delete(
        Uri.parse('$_base/m/roster/$shiftId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode != 200) return false;
      unawaited(_fetchDaily(selectedDate.value));
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  void dispose() {
    isManager.dispose();
    staff.dispose();
    selectedDate.dispose();
    dailyView.dispose();
    isLoading.dispose();
    _http.close();
  }
}
