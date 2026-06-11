import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/availability.dart';
import 'local_db.dart';

class AvailabilityRepository {
  AvailabilityRepository({
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

  final ValueNotifier<AvailabilityData> data =
      ValueNotifier(AvailabilityData.empty);

  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isSaving = ValueNotifier(false);

  // ---------------------------------------------------------------------------
  // Init / token
  // ---------------------------------------------------------------------------

  Future<void> init(String? token) async {
    _token = token;
    await _loadFromCache();
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      data.value = AvailabilityData.empty;
    } else {
      _refreshFromServer();
    }
  }

  Future<void> refresh() => _refreshFromServer();

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    final patternRows = await _db.queryAvailPatterns();
    final exceptionRows = await _db.queryAvailExceptions();
    data.value = AvailabilityData(
      pattern: patternRows.map(AvailPattern.fromSqlite).toList(),
      exceptions: exceptionRows.map(AvailException.fromSqlite).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/availability/my'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final patterns = (body['pattern'] as List<dynamic>)
          .map((e) => AvailPattern.fromJson(e as Map<String, dynamic>))
          .toList();
      final exceptions = (body['exceptions'] as List<dynamic>)
          .map((e) => AvailException.fromJson(e as Map<String, dynamic>))
          .toList();
      await _db.replaceAvailPatterns(patterns.map((p) => p.toSqliteRow()).toList());
      for (final ex in exceptions) {
        await _db.upsertAvailException(ex.toSqliteRow());
      }
      await _loadFromCache();
    } on SocketException {
      // Offline — cached data shown.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Silently ignore.
    } finally {
      isLoading.value = false;
    }
  }

  /// Replace the full weekly pattern on the server.
  Future<bool> updatePattern(List<AvailPattern> pattern) async {
    if (_token == null) return false;
    isSaving.value = true;
    try {
      final resp = await _http.put(
        Uri.parse('$_base/m/availability/my'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'pattern': pattern.map((p) => p.toJson()).toList()}),
      );
      if (resp.statusCode != 200) return false;
      // Update local cache optimistically.
      await _db.replaceAvailPatterns(pattern.map((p) => p.toSqliteRow()).toList());
      await _loadFromCache();
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Add or replace a dated exception.
  Future<bool> addException(AvailException exception) async {
    if (_token == null) return false;
    isSaving.value = true;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/availability/my/exceptions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(exception.toJson()),
      );
      if (resp.statusCode != 200) return false;
      await _db.upsertAvailException(exception.toSqliteRow());
      await _loadFromCache();
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    data.dispose();
    isLoading.dispose();
    isSaving.dispose();
    _http.close();
  }
}
