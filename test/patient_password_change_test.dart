import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/main.dart';
import 'package:flowcare_mobile/providers/auth_provider.dart';
import 'package:flowcare_mobile/screens/auth/change_password_screen.dart';
import 'package:flowcare_mobile/screens/main_shell_screen.dart';
import 'package:flowcare_mobile/services/auth_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

const patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a', phone = '0901234567';
http.Response ok(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response credentials(String token) => ok({
  'accessToken': token,
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
});
http.Response profile({bool required = true}) => ok({
  'roles': ['PATIENT'],
  'patientId': patientId,
  'userName': phone,
  'mustChangePassword': required,
});
ApiClient client(Future<http.Response> Function(http.Request) handle) =>
    ApiClient(baseUrl: 'http://test/api/v1', client: MockClient(handle));

void main() {
  setUp(() {
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
    ApiClient.onPasswordChangeRequired = null;
    PatientSessionService().clearSession();
  });
  tearDown(() {
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
    ApiClient.onPasswordChangeRequired = null;
    PatientSessionService().clearSession();
  });

  test('temporary login remains restricted and never binds the normal patient session', () async {
    final auth = AuthProvider(
      service: AuthService(
        client: client(
          (request) async => request.url.path.endsWith('/login')
              ? credentials('temporary')
              : profile(),
        ),
      ),
    );
    addTearDown(auth.dispose);
    expect(await auth.login(phone, '01234567'), isTrue);
    expect(auth.mustChangePassword, isTrue);
    expect(ApiClient.authToken, 'temporary');
    expect(PatientSessionService().isAuthenticated, isFalse);
  });
  test('change password posts once then authenticates and verifies a fresh token before enabling the app', () async {
    final requests = <http.Request>[];
    var changed = false;
    final auth = AuthProvider(
      service: AuthService(
        client: client((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/change-password')) {
            expect(request.headers['Authorization'], 'Bearer temporary');
            expect(jsonDecode(request.body), {
              'currentPassword': '01234567',
              'newPassword': 'new-password123',
            });
            changed = true;
            return ok(true);
          }
          if (request.url.path.endsWith('/login')) {
            expect(request.headers['Authorization'], isNull);
            if (changed) {
              expect(jsonDecode(request.body)['password'], 'new-password123');
            }
            return credentials(changed ? 'fresh' : 'temporary');
          }
          expect(
            request.headers['Authorization'],
            changed ? 'Bearer fresh' : 'Bearer temporary',
          );
          return profile(required: !changed);
        }),
      ),
    );
    addTearDown(auth.dispose);
    await auth.login(phone, '01234567');
    expect(await auth.changePassword('01234567', 'new-password123'), isTrue);
    expect(requests.map((r) => r.url.path), [
      '/api/v1/auth/login',
      '/api/v1/auth/me',
      '/api/v1/auth/change-password',
      '/api/v1/auth/login',
      '/api/v1/auth/me',
    ]);
    expect(auth.mustChangePassword, isFalse);
    expect(ApiClient.authToken, 'fresh');
    expect(PatientSessionService().patientId, patientId);
  });
  test('after a committed password change a failed automatic login signs out with an instruction to use the new password', () async {
    var logins = 0, changes = 0;
    final auth = AuthProvider(
      service: AuthService(
        client: client((request) async {
          if (request.url.path.endsWith('/login')) {
            logins++;
            return logins == 1
                ? credentials('temporary')
                : http.Response('{}', 401);
          }
          if (request.url.path.endsWith('/change-password')) {
            changes++;
            return ok(true);
          }
          return profile();
        }),
      ),
    );
    addTearDown(auth.dispose);
    await auth.login(phone, '01234567');
    expect(await auth.changePassword('01234567', 'new-password123'), isFalse);
    expect(changes, 1);
    expect(auth.isAuthenticated, isFalse);
    expect(ApiClient.authToken, isNull);
    expect(auth.message, contains('mật khẩu mới'));
  });
  test('a rejected or lost password-change response cannot unlock the app or retry the mutation', () async {
    for (final lost in [false, true]) {
      var changes = 0;
      final auth = AuthProvider(
        service: AuthService(
          client: client((request) async {
            if (request.url.path.endsWith('/login')) {
              return credentials('temporary');
            }
            if (request.url.path.endsWith('/change-password')) {
              changes++;
              if (lost) throw http.ClientException('offline');
              return http.Response(
                jsonEncode({
                  'message': 'Mật khẩu hiện tại sai',
                  'errors': ['INVALID_PASSWORD'],
                }),
                400,
              );
            }
            return profile();
          }),
        ),
      );
      await auth.login(phone, '01234567');
      expect(await auth.changePassword('01234567', 'new-password123'), isFalse);
      expect(changes, 1);
      expect(auth.mustChangePassword, isTrue);
      expect(PatientSessionService().isAuthenticated, isFalse);
      auth.dispose();
    }
  });
  test(
    'duplicate submissions and a late change response cannot survive logout',
    () async {
      final pending = Completer<http.Response>();
      var changes = 0;
      final auth = AuthProvider(
        service: AuthService(
          client: client((request) async {
            if (request.url.path.endsWith('/login')) {
              return credentials('temporary');
            }
            if (request.url.path.endsWith('/change-password')) {
              changes++;
              return pending.future;
            }
            return profile();
          }),
        ),
      );
      addTearDown(auth.dispose);
      await auth.login(phone, '01234567');
      final first = auth.changePassword('01234567', 'new-password123');
      expect(
        await auth.changePassword('01234567', 'another-password'),
        isFalse,
      );
      await pumpEventQueue();
      auth.logout();
      pending.complete(ok(true));
      expect(await first, isFalse);
      expect(changes, 1);
      expect(auth.isAuthenticated, isFalse);
      expect(ApiClient.authToken, isNull);
    },
  );
  test('PASSWORD_CHANGE_REQUIRED guards an existing session while ordinary 403 and stale responses do not change another session', () async {
    final auth = AuthProvider(
      service: AuthService(
        client: client(
          (request) async => request.url.path.endsWith('/login')
              ? credentials('normal')
              : profile(required: false),
        ),
      ),
    );
    addTearDown(auth.dispose);
    await auth.login(phone, 'normal-password');
    await expectLater(
      client(
        (_) async => http.Response(
          jsonEncode({
            'errors': ['NOT_PERMITTED'],
          }),
          403,
        ),
      ).get('/patients/me'),
      throwsA(isA<ForbiddenException>()),
    );
    expect(auth.mustChangePassword, isFalse);
    final pending = Completer<http.Response>();
    final stale = client((_) => pending.future).get('/patients/me');
    await pumpEventQueue();
    ApiClient.setAuthToken('new-session');
    pending.complete(
      http.Response(
        jsonEncode({
          'errors': ['PASSWORD_CHANGE_REQUIRED'],
        }),
        403,
      ),
    );
    await expectLater(stale, throwsA(isA<SessionChangedException>()));
    expect(auth.mustChangePassword, isFalse);
    await expectLater(
      client(
        (_) async => http.Response(
          jsonEncode({
            'errors': ['PASSWORD_CHANGE_REQUIRED'],
          }),
          403,
        ),
      ).get('/patients/me'),
      throwsA(isA<PasswordChangeRequiredException>()),
    );
    expect(auth.mustChangePassword, isTrue);
    expect(PatientSessionService().isAuthenticated, isFalse);
  });
  testWidgets(
    'the real authentication gate shows only mandatory password change before normal providers and blocks back',
    (tester) async {
      await tester.pumpWidget(
        FlowCareApp(
          authService: AuthService(
            client: client(
              (request) async => request.url.path.endsWith('/login')
                  ? credentials('temporary')
                  : profile(),
            ),
          ),
        ),
      );
      final auth = tester
          .element(find.byType(PatientAuthGate))
          .read<AuthProvider>();
      await auth.login(phone, '01234567');
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.byType(MainShellScreen), findsNothing);
      expect(PatientSessionService().isAuthenticated, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('change-current-password')),
        '01234567',
      );
      await tester.enterText(
        find.byKey(const Key('change-new-password')),
        '01234567',
      );
      await tester.enterText(
        find.byKey(const Key('change-confirm-password')),
        '01234567',
      );
      await tester.ensureVisible(
        find.byKey(const Key('change-password-submit')),
      );
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu mới phải khác mật khẩu tạm.'), findsOneWidget);
      expect(auth.mustChangePassword, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
