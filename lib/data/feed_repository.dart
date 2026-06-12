import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/feed.dart';

class FeedRepository {
  FeedRepository({
    String? baseUrl,
    http.Client? httpClient,
  })  : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;
  String? _token;

  final ValueNotifier<List<FeedPost>> posts = ValueNotifier(const []);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(String? token) async {
    _token = token;
    unawaited(_refreshFromServer());
  }

  void updateToken(String? token) {
    _token = token;
    if (token == null) {
      posts.value = const [];
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
        Uri.parse('$_base/m/feed/'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        posts.value = list
            .map((e) => FeedPost.fromJson(e as Map<String, dynamic>))
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

  Future<List<FeedComment>> fetchComments(int postId) async {
    if (_token == null) return [];
    try {
      final resp = await _http.get(
        Uri.parse('$_base/m/feed/$postId/comments'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => FeedComment.fromJson(e as Map<String, dynamic>))
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

  Future<bool> createPost(String body) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/feed/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'body': body}),
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

  Future<bool> addComment(int postId, String body) async {
    if (_token == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_base/m/feed/$postId/comments'),
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

  void dispose() {
    posts.dispose();
    isLoading.dispose();
    _http.close();
  }
}
