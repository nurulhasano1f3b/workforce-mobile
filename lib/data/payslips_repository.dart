import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/payslip.dart';
import 'local_db.dart';

class PayslipsRepository {
  PayslipsRepository({
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

  final ValueNotifier<List<Payslip>> payslips = ValueNotifier(const []);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(String? token) async {
    _token = token;
    await _loadFromCache();
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      payslips.value = const [];
    } else {
      unawaited(_refreshFromServer());
    }
  }

  Future<void> _loadFromCache() async {
    final rows = await _db.queryPayslips();
    payslips.value = rows.map(Payslip.fromSqlite).toList();
  }

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/payslips/my'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        final parsed = list
            .map((e) => Payslip.fromJson(e as Map<String, dynamic>))
            .toList();
        await _db.replacePayslips(parsed.map((p) => p.toSqliteRow()).toList());
        payslips.value = parsed;
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

  void dispose() {
    payslips.dispose();
    isLoading.dispose();
    _http.close();
  }
}
