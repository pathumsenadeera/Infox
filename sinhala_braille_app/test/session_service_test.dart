import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/services/session_service.dart';

class MemorySessionStore implements SessionStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    if (failWrite) throw StateError('Storage unavailable');
    value = next;
  }

  @override
  Future<void> delete() async => value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 18, 12);
  Map<String, dynamic> session({bool expired = false, String suffix = '1'}) => {
    'access_token': 'access-$suffix',
    'refresh_token': 'refresh-$suffix',
    'access_expires_at':
        now.add(Duration(minutes: expired ? -1 : 30)).toIso8601String(),
    'refresh_expires_at': now.add(const Duration(days: 30)).toIso8601String(),
    'user_id': 1,
    'username': 'reader',
    'email': 'reader@example.com',
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('removes legacy password and does not trust a legacy user ID', () async {
    SharedPreferences.setMockInitialValues({
      'user_password': 'secret',
      'user_id': '99',
      'user_name': 'old',
    });
    final store = MemorySessionStore();
    final service = SessionService(
      store: store,
      now: () => now,
      client: MockClient((_) async => throw StateError('No request expected')),
    );
    await service.initialize();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('user_password'), isFalse);
    expect(prefs.containsKey('user_id'), isFalse);
    expect(service.isSignedIn, isFalse);
    expect(store.value, isNull);
  });

  test('persists only session fields in secure store', () async {
    final store = MemorySessionStore();
    final service = SessionService(store: store, now: () => now);
    await service.acceptLogin({
      ...session(),
      'password': 'never store',
      'password_hash': 'never store',
    });
    expect(service.userId, '1');
    expect(store.value, isNot(contains('password')));
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('refreshes an expired token once for simultaneous requests', () async {
    var refreshes = 0;
    final store = MemorySessionStore();
    final service = SessionService(
      store: store,
      now: () => now,
      client: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshes++;
          expect(jsonDecode(request.body)['refresh_token'], 'refresh-1');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(jsonEncode(session(suffix: '2')), 200);
        }
        expect(request.headers['Authorization'], 'Bearer access-2');
        return http.Response('{}', 200);
      }),
    );
    await service.acceptLogin(session(expired: true));
    final responses = await Future.wait([
      service.request('GET', '/settings/1'),
      service.request('GET', '/scan/10'),
    ]);
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshes, 1);
    expect(jsonDecode(store.value!)['refresh_token'], 'refresh-2');
  });

  test('retries a 401 with a renewed token', () async {
    var calls = 0;
    final service = SessionService(
      store: MemorySessionStore(),
      now: () => now,
      client: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          return http.Response(jsonEncode(session(suffix: '2')), 200);
        }
        calls++;
        return http.Response(
          '{}',
          request.headers['Authorization'] == 'Bearer access-1' ? 401 : 200,
        );
      }),
    );
    await service.acceptLogin(session());
    expect((await service.request('GET', '/auth/me')).statusCode, 200);
    expect(calls, 2);
  });

  test('rejected refresh clears credentials and notifies listeners', () async {
    final store = MemorySessionStore();
    final service = SessionService(
      store: store,
      now: () => now,
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await service.acceptLogin(session(expired: true));
    var notified = false;
    service.addListener(() => notified = !service.isSignedIn);
    await expectLater(
      service.request('GET', '/settings/1'),
      throwsA(isA<SessionExpired>()),
    );
    expect(store.value, isNull);
    expect(notified, isTrue);
  });

  test(
    'offline restore preserves encrypted session but expired refresh does not',
    () async {
      final store = MemorySessionStore()..value = jsonEncode(session());
      final service = SessionService(
        store: store,
        now: () => now,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await service.initialize();
      expect(service.isSignedIn, isTrue);
      store.value = jsonEncode({
        ...session(),
        'refresh_expires_at':
            now.subtract(const Duration(seconds: 1)).toIso8601String(),
      });
      await service.initialize();
      expect(service.isSignedIn, isFalse);
      expect(store.value, isNull);
    },
  );

  test('transient refresh failure preserves credentials for retry', () async {
    final store = MemorySessionStore();
    final service = SessionService(
      store: store,
      now: () => now,
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await service.acceptLogin(session(expired: true));
    await expectLater(
      service.request('GET', '/auth/me'),
      throwsA(isA<http.ClientException>()),
    );
    expect(service.isSignedIn, isTrue);
    expect(store.value, isNotNull);
  });

  test(
    'logout submits refresh credential then removes local session',
    () async {
      final store = MemorySessionStore();
      final service = SessionService(
        store: store,
        now: () => now,
        client: MockClient((request) async {
          expect(request.url.path, '/auth/logout');
          expect(jsonDecode(request.body)['refresh_token'], 'refresh-1');
          return http.Response('{"success":true}', 200);
        }),
      );
      await service.acceptLogin(session());
      await service.logout();
      expect(service.isSignedIn, isFalse);
      expect(store.value, isNull);
    },
  );

  test(
    'failed logout does not claim server revocation or clear credentials',
    () async {
      final store = MemorySessionStore();
      final service = SessionService(
        store: store,
        now: () => now,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await service.acceptLogin(session());
      await expectLater(service.logout(), throwsA(isA<http.ClientException>()));
      expect(service.isSignedIn, isTrue);
    },
  );

  test('late refresh cannot restore a cleared session', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final store = MemorySessionStore();
    final service = SessionService(
      store: store,
      now: () => now,
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    await service.acceptLogin(session(expired: true));
    final request = service.request('GET', '/auth/me');
    final assertion = expectLater(request, throwsA(isA<SessionExpired>()));
    await started.future;
    await service.clear();
    response.complete(http.Response(jsonEncode(session(suffix: '2')), 200));
    await assertion;
    expect(service.isSignedIn, isFalse);
    expect(store.value, isNull);
  });

  test('secure storage failure never accepts login', () async {
    final store = MemorySessionStore()..failWrite = true;
    final service = SessionService(store: store, now: () => now);
    await expectLater(service.acceptLogin(session()), throwsStateError);
    expect(service.isSignedIn, isFalse);
  });
}
