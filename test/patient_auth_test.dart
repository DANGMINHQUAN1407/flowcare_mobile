import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/providers/auth_provider.dart';
import 'package:flowcare_mobile/screens/auth/login_screen.dart';
import 'package:flowcare_mobile/services/auth_service.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/main.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/models/patient_visit_model.dart';

const patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> tokenData() => {
  'accessToken': 'patient-token',
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 15))
      .toUtc()
      .toIso8601String(),
};
ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(baseUrl: 'http://test/api/v1', client: MockClient(handler));

class FakePatientAuth extends AuthService {
  final Duration lifetime;
  FakePatientAuth({this.lifetime = const Duration(minutes: 15)});
  @override
  Future<PatientLogin> login(String userName, String password) async =>
      PatientLogin(
        token: 'test-patient-token',
        patientId: patientId,
        userName: userName,
        expiresAt: DateTime.now().add(lifetime),
      );
}

void main() {
  setUp(() {
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
    PatientSessionService().clearSession();
  });
  tearDown(() {
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
    PatientSessionService().clearSession();
  });

  test(
    'publishes only a verified PATIENT session and clears it on logout',
    () async {
      final requests = <http.Request>[];
      final auth = AuthProvider(
        service: AuthService(
          client: client((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/login')) {
              expect(request.headers['Authorization'], isNull);
              expect(jsonDecode(request.body), {
                'userName': 'patient.test',
                'password': ' secret ',
              });
              return ok(tokenData());
            }
            expect(ApiClient.authToken, isNull);
            expect(request.headers['Authorization'], 'Bearer patient-token');
            return ok({
              'id': 'user-id',
              'roles': ['PATIENT'],
              'patientId': patientId,
              'userName': 'patient.test',
            });
          }),
        ),
      );
      addTearDown(auth.dispose);
      expect(await auth.login(' patient.test ', ' secret '), isTrue);
      expect(requests, hasLength(2));
      expect(PatientSessionService().patientId, patientId);
      expect(ApiClient.authToken, 'patient-token');
      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(ApiClient.authToken, isNull);
      expect(PatientSessionService().patientId, isNull);
    },
  );

  for (final profile in [
    {
      'roles': ['RECEPTIONIST'],
      'patientId': patientId,
    },
    {
      'roles': ['PATIENT'],
      'patientId': null,
    },
    {
      'roles': ['PATIENT'],
      'patientId': '00000000-0000-0000-0000-000000000000',
    },
  ]) {
    test('rejects wrong role or missing identity: $profile', () async {
      final auth = AuthProvider(
        service: AuthService(
          client: client(
            (request) async => request.url.path.endsWith('/login')
                ? ok(tokenData())
                : ok(profile),
          ),
        ),
      );
      addTearDown(auth.dispose);
      expect(await auth.login('patient.test', 'secret'), isFalse);
      expect(auth.message, isNotNull);
      expect(ApiClient.authToken, isNull);
      expect(PatientSessionService().patientId, isNull);
    });
  }

  test(
    'failed login does not create a session or retry with another account',
    () async {
      var calls = 0;
      final auth = AuthProvider(
        service: AuthService(
          client: client((request) async {
            calls++;
            return http.Response('{}', 401);
          }),
        ),
      );
      addTearDown(auth.dispose);
      expect(await auth.login('patient.test', 'wrong'), isFalse);
      expect(calls, 1);
      expect(auth.message, contains('mật khẩu'));
      expect(auth.isAuthenticated, isFalse);
    },
  );

  test('logout while login is pending ignores the late success', () async {
    final pending = Completer<http.Response>();
    final auth = AuthProvider(
      service: AuthService(
        client: client(
          (request) async => request.url.path.endsWith('/login')
              ? pending.future
              : ok({
                  'roles': ['PATIENT'],
                  'patientId': patientId,
                }),
        ),
      ),
    );
    addTearDown(auth.dispose);
    final login = auth.login('patient.test', 'secret');
    auth.logout();
    pending.complete(ok(tokenData()));
    expect(await login, isFalse);
    expect(ApiClient.authToken, isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  for (final method in ['get', 'post', 'put', 'patch']) {
    test(
      '$method 401 clears session once and never replays the request',
      () async {
        var calls = 0, expired = 0;
        ApiClient.setAuthToken('patient-token');
        ApiClient.onUnauthorized = () => expired++;
        final api = client((request) async {
          calls++;
          return http.Response('{}', 401);
        });
        final future = switch (method) {
          'post' => api.post('/appointments', body: {'patientId': patientId}),
          'put' => api.put('/patients/$patientId'),
          'patch' => api.patch('/notifications/id/read'),
          _ => api.get('/patients/me/encounters'),
        };
        await expectLater(future, throwsA(isA<UnauthorizedException>()));
        expect(calls, 1);
        expect(expired, 1);
        expect(ApiClient.authToken, isNull);
      },
    );
  }

  test('403 keeps the current session', () async {
    ApiClient.setAuthToken('patient-token');
    var expired = false;
    ApiClient.onUnauthorized = () => expired = true;
    await expectLater(
      client((_) async => http.Response('{}', 403)).get('/patients/$patientId'),
      throwsA(isA<ForbiddenException>()),
    );
    expect(expired, isFalse);
    expect(ApiClient.authToken, 'patient-token');
  });

  test('old 401 cannot log out a newly signed-in account', () async {
    ApiClient.setAuthToken('old-token');
    final pending = Completer<http.Response>();
    var expired = false;
    ApiClient.onUnauthorized = () => expired = true;
    final future = client((_) => pending.future).get('/patients/me/encounters');
    await pumpEventQueue();
    ApiClient.setAuthToken('new-token');
    pending.complete(http.Response('{}', 401));
    await expectLater(future, throwsA(isA<SessionChangedException>()));
    expect(ApiClient.authToken, 'new-token');
    expect(expired, isFalse);
  });

  test(
    'profile updates surface server failure instead of fabricating success',
    () async {
      PatientSessionService().bindPatient(
        patientId: patientId,
        userName: 'patient.test',
      );
      ApiClient.setAuthToken('patient-token');
      final service = PatientService(
        apiClient: client((_) async => http.Response('{}', 500)),
      );
      await expectLater(
        service.updatePatient(id: patientId, fullName: 'Test'),
        throwsA(isA<ServerException>()),
      );
    },
  );

  test(
    'slot failures never turn into fabricated available booking times',
    () async {
      ApiClient.setAuthToken('patient-token');
      final service = AppointmentService(
        apiClient: client((_) async => http.Response('{}', 500)),
      );
      await expectLater(
        service.getAvailableSlots(
          serviceTypeId: 'service-id',
          date: '2026-10-18',
        ),
        throwsA(isA<ServerException>()),
      );
    },
  );

  test('encounter summaries from the current /patients/me endpoint parse correctly', () {
    final visit = PatientVisitModel.fromJson({
      'encounterId': 'encounter-id',
      'encounterStatus': 'Finalized',
      'departmentName': 'Khoa Sản',
      'checkInTime': '2026-10-17T08:00:00Z',
    });
    expect(visit.isFinalized, isTrue);
    expect(visit.serviceTypeName, 'Khoa Sản');
    expect(visit.visitTime, DateTime.parse('2026-10-17T08:00:00Z'));
    final noDate = PatientVisitModel.fromJson({
      'encounterId': 'encounter-id',
      'encounterStatus': 'Draft',
    });
    expect(noDate.visitTime.millisecondsSinceEpoch, 0);
  });

  testWidgets(
    'logout removes open patient dialogs and returns the real app to login',
    (tester) async {
      await tester.pumpWidget(FlowCareApp(authService: FakePatientAuth()));
      final auth = tester
          .element(find.byType(LoginScreen))
          .read<AuthProvider>();
      await auth.login('patient.test', 'test-only');
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập bệnh nhân'), findsNothing);
      final context = tester.element(find.byType(NavigationBar));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) =>
              const AlertDialog(content: Text('private patient data')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private patient data'), findsOneWidget);
      auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập bệnh nhân'), findsOneWidget);
      expect(find.text('private patient data'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(PatientSessionService().patientId, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'expiry timer returns the app to login and clears the patient token',
    (tester) async {
      await tester.pumpWidget(
        FlowCareApp(
          authService: FakePatientAuth(lifetime: const Duration(seconds: 2)),
        ),
      );
      final auth = tester
          .element(find.byType(LoginScreen))
          .read<AuthProvider>();
      await auth.login('patient.test', 'test-only');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập bệnh nhân'), findsOneWidget);
      expect(find.textContaining('hết hạn'), findsOneWidget);
      expect(ApiClient.authToken, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('login fits a small screen with keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    expect(find.text('Đăng nhập bệnh nhân'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(find.text('Nhập tên đăng nhập.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
