import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureSessionStore implements SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'infox_session_v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class SessionExpired implements Exception {
  const SessionExpired();
  @override
  String toString() => 'Session expired. Please log in again.';
}

class SessionService extends ChangeNotifier {
  static const baseUrl = String.fromEnvironment(
    'INFOX_API_URL',
    defaultValue: 'https://server.projectinfox.tech',
  );
  static final instance = SessionService();
  SessionService({
    http.Client? client,
    SessionStore? store,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _store = store ?? SecureSessionStore(),
       _now = now ?? DateTime.now;

  final http.Client _client;
  final SessionStore _store;
  final DateTime Function() _now;
  Map<String, dynamic>? _session;
  Future<void>? _refreshing;
  Future<void> _writes = Future.value();
  int _generation = 0;
  bool _loggingOut = false;
  bool get isSignedIn => _session != null;
  String? get userId => _session?['user_id']?.toString();
  String get username => _session?['username'] as String? ?? '';
  String get email => _session?['email'] as String? ?? '';

  Future<void> _persist(String? value) {
    final operation = _writes.then(
      (_) => value == null ? _store.delete() : _store.write(value),
    );
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    // Never trust a legacy user_id as proof of authentication.
    for (final key in ['user_password', 'user_id', 'user_name', 'user_email']) {
      await prefs.remove(key);
    }
    final raw = await _store.read();
    if (raw == null) return;
    try {
      _session = _validated(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return;
    } on TypeError {
      await clear();
      return;
    }
    if (!_now().toUtc().isBefore(
      DateTime.parse(_session!['refresh_expires_at']),
    )) {
      await clear();
      return;
    }
    // Preserve the encrypted local session on network failure for offline reading.
    try {
      final response = await request('GET', '/auth/me');
      if (response.statusCode == 200) {
        final profile = jsonDecode(response.body) as Map<String, dynamic>;
        _session!.addAll({
          'username': profile['username'],
          'email': profile['email'],
        });
        await _persist(jsonEncode(_session));
      }
    } on SessionExpired {
      // request already cleared the rejected session.
    } on TimeoutException {
      // Retry when connectivity returns.
    } on http.ClientException {
      // Retry when connectivity returns.
    }
    notifyListeners();
  }

  Map<String, dynamic> _validated(Map<String, dynamic> data) {
    for (final key in ['access_token', 'refresh_token', 'username', 'email']) {
      if (data[key] is! String || (data[key] as String).isEmpty) {
        throw const FormatException('Invalid session response');
      }
    }
    if (data['user_id'] is! int) throw const FormatException('Invalid user ID');
    DateTime.parse(data['access_expires_at'] as String);
    DateTime.parse(data['refresh_expires_at'] as String);
    // Explicit allowlist: never persist passwords or other response fields.
    return {
      for (final key in [
        'access_token',
        'refresh_token',
        'access_expires_at',
        'refresh_expires_at',
        'user_id',
        'username',
        'email',
      ])
        key: data[key],
    };
  }

  Future<void> acceptLogin(Map<String, dynamic> data) async {
    final session = _validated(data);
    final generation = ++_generation;
    await _persist(jsonEncode(session));
    if (generation != _generation) return;
    _session = session;
    notifyListeners();
  }

  Future<void> clear() async {
    ++_generation;
    _session = null;
    notifyListeners();
    await _persist(null);
  }

  Future<void> updateUsername(String value) async {
    if (_session == null) return;
    _session!['username'] = value;
    await _persist(jsonEncode(_session));
    notifyListeners();
  }

  Future<http.Response> publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return _send(request, const Duration(seconds: 15));
  }

  Future<http.Response> _send(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    return (() async => http.Response.fromStream(await _client.send(request)))()
        .timeout(timeout);
  }

  Future<void> _refresh() async {
    if (_loggingOut) throw const SessionExpired();
    if (_refreshing != null) return _refreshing!;
    final future = _rotate();
    _refreshing = future;
    try {
      await future;
    } finally {
      if (identical(_refreshing, future)) _refreshing = null;
    }
  }

  Future<void> _rotate() async {
    final session = _session;
    if (session == null) throw const SessionExpired();
    final generation = _generation;
    if (!_now().toUtc().isBefore(
      DateTime.parse(session['refresh_expires_at']),
    )) {
      await clear();
      throw const SessionExpired();
    }
    final response = await publicRequest(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': session['refresh_token']},
    );
    if (generation != _generation) throw const SessionExpired();
    if (response.statusCode == 401) {
      await clear();
      throw const SessionExpired();
    }
    if (response.statusCode != 200) {
      throw http.ClientException('Could not renew session. Please try again.');
    }
    final renewed = _validated(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    try {
      await _persist(jsonEncode(renewed));
    } catch (_) {
      // Old refresh credentials no longer work after rotation.
      await clear();
      rethrow;
    }
    if (generation != _generation) throw const SessionExpired();
    _session = renewed;
    notifyListeners();
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    return sendAuthenticated(() async {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['Content-Type'] = 'application/json';
      if (body != null) request.body = jsonEncode(body);
      return request;
    });
  }

  /// Factory recreates multipart streams if an expired access token is rejected.
  Future<http.Response> sendAuthenticated(
    Future<http.BaseRequest> Function() build, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final generation = _generation;
    if (_session == null || _loggingOut) throw const SessionExpired();
    if (!_now()
        .toUtc()
        .add(const Duration(seconds: 30))
        .isBefore(DateTime.parse(_session!['access_expires_at']))) {
      await _refresh();
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_session == null || generation != _generation) {
        throw const SessionExpired();
      }
      final token = _session!['access_token'] as String;
      final request = await build();
      if (generation != _generation) throw const SessionExpired();
      request.headers['Authorization'] = 'Bearer $token';
      final response = await _send(request, timeout);
      if (generation != _generation) throw const SessionExpired();
      if (response.statusCode != 401) return response;
      if (attempt == 1) {
        await clear();
        throw const SessionExpired();
      }
      // Another simultaneous request may already have rotated this token.
      if (_session!['access_token'] == token) await _refresh();
    }
    throw const SessionExpired();
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      // Wait for an in-flight rotation so the server gets the current credential.
      if (_refreshing != null) await _refreshing;
      if (_session == null) return;
      final response = await publicRequest(
        'POST',
        '/auth/logout',
        body: {'refresh_token': _session!['refresh_token']},
      );
      if (response.statusCode != 200) {
        throw http.ClientException('Could not log out. Please try again.');
      }
      await clear();
    } finally {
      _loggingOut = false;
    }
  }
}
