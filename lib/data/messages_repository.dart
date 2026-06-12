import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/message.dart';

class MessagesRepository {
  MessagesRepository({
    String? baseUrl,
    http.Client? httpClient,
  })  : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;
  String? _token;

  final ValueNotifier<List<Thread>> threads = ValueNotifier(const []);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(String? token) async {
    _token = token;
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      threads.value = const [];
    } else {
      unawaited(_refreshFromServer());
    }
  }

  Future<void> refresh() => _refreshFromServer();

  Future<void> _refreshFromServer() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/messages/threads'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        threads.value = list
            .map((e) => Thread.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on SocketException {
      // Offline.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any other error.
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Message>> fetchMessages(int threadId) async {
    if (_token == null) return [];
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/messages/threads/$threadId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on SocketException {
      // Offline.
    } on http.ClientException {
      // Network error.
    } catch (_) {
      // Any other error.
    }
    return [];
  }

  Future<bool> sendMessage(int threadId, String body) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/messages/threads/$threadId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'body': body}),
      );
      return resp.statusCode == 201;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<int?> createThread({
    required List<int> participantIds,
    required String body,
    String? subject,
  }) async {
    if (_token == null) return null;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/messages/threads'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          'participantIds': participantIds,
          'body': body,
        }),
      );
      if (resp.statusCode != 201) return null;
      final id = (jsonDecode(resp.body) as Map)['id'] as int;
      unawaited(_refreshFromServer());
      return id;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    threads.dispose();
    isLoading.dispose();
    _http.close();
  }
}
