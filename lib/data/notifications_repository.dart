import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/notification_item.dart';
import 'local_db.dart';

/// NotificationsRepository — local-first cache for GET /notifications.
///
/// markRead() is optimistic: it updates the local cache immediately and
/// fires the POST in the background.  Failures are silently ignored; the
/// server is the source of truth on next refresh.
class NotificationsRepository {
  NotificationsRepository({
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

  /// Notifications, newest first.
  final ValueNotifier<List<NotificationItem>> notifications =
      ValueNotifier(const []);

  /// True while background refresh is in-flight.
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  int get unreadCount =>
      notifications.value.where((n) => !n.isRead).length;

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
      notifications.value = const [];
    } else {
      _refreshFromServer();
    }
  }

  // ---------------------------------------------------------------------------
  // Cache load
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    final rows = await _db.queryNotifications();
    notifications.value =
        rows.map(NotificationItem.fromSqlite).toList();
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
        Uri.parse('$_base/notifications'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode != 200) return;

      final list = jsonDecode(resp.body) as List<dynamic>;
      for (final item in list) {
        final n = NotificationItem.fromJson(item as Map<String, dynamic>);
        await _db.upsertNotification(n.toSqliteRow());
      }
      await _loadFromCache();
    } on SocketException {
      // Offline — cached data stays.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any error — silently ignore.
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Optimistic mark-read
  // ---------------------------------------------------------------------------

  /// Marks a notification as read in the local cache immediately, then
  /// confirms with POST /notifications/:id/read in the background.
  Future<void> markRead(int notifId) async {
    // 1. Optimistic local update.
    await _db.setNotificationPendingRead(notifId);
    final current = List<NotificationItem>.from(notifications.value);
    final idx = current.indexWhere((n) => n.id == notifId);
    if (idx >= 0) {
      current[idx] = current[idx].copyWith(pendingRead: true);
      notifications.value = current;
    }

    // 2. Background server call.
    unawaited(_postMarkRead(notifId));
  }

  Future<void> _postMarkRead(int notifId) async {
    if (_token == null) return;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/notifications/$notifId/read'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        final now = DateTime.now().toIso8601String();
        await _db.markNotificationRead(notifId, now);
        await _loadFromCache();
      }
    } catch (_) {
      // Silently ignore — will correct on next refresh.
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    notifications.dispose();
    isLoading.dispose();
    _http.close();
  }
}
