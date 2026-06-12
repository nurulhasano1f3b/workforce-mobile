import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/announcement.dart';
import 'local_db.dart';

class AnnouncementsRepository {
  AnnouncementsRepository({
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

  final ValueNotifier<List<Announcement>> announcements =
      ValueNotifier(const []);
  final ValueNotifier<bool> canPost = ValueNotifier(false);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(String? token) async {
    _token = token;
    await _loadFromCache();
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      announcements.value = const [];
      canPost.value = false;
    } else {
      unawaited(_refreshFromServer());
    }
  }

  Future<void> _loadFromCache() async {
    final rows = await _db.queryAnnouncements();
    announcements.value = rows.map(Announcement.fromSqlite).toList();
  }

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _http.get(
          Uri.parse('$_base/m/announcements/'),
          headers: {'Authorization': 'Bearer $_token'},
        ),
        _http.post(
          Uri.parse('$_base/m/announcements/'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: '{}',
        ),
      ]);

      final listResp = results[0];
      final probeResp = results[1];

      if (listResp.statusCode == 200) {
        final list = jsonDecode(listResp.body) as List<dynamic>;
        final parsed = list
            .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
            .toList();
        await _db.replaceAnnouncements(
            parsed.map((a) => a.toSqliteRow()).toList());
        announcements.value = parsed;
      }

      canPost.value = probeResp.statusCode == 400;
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

  Future<bool> postAnnouncement(String title, {String? body}) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/announcements/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'title': title,
          if (body != null && body.isNotEmpty) 'body': body,
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

  void dispose() {
    announcements.dispose();
    canPost.dispose();
    isLoading.dispose();
    _http.close();
  }
}
