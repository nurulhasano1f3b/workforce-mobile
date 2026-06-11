import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository({String? baseUrl, http.Client? httpClient})
      : _base = baseUrl ?? kBaseUrl,
        _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;

  String? _token;

  final ValueNotifier<UserProfile?> profile = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  void updateToken(String? token) {
    _token = token;
    if (token != null) _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    if (_token == null) return;
    isLoading.value = true;
    try {
      final resp = await _http.get(
        Uri.parse('$_base/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode == 200) {
        profile.value = UserProfile.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // keep stale value on network error
    } finally {
      isLoading.value = false;
    }
  }

  void clear() {
    _token = null;
    profile.value = null;
  }

  void dispose() {
    profile.dispose();
    isLoading.dispose();
    _http.close();
  }
}
