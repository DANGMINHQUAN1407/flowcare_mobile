import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/core/theme/app_theme.dart';
import 'package:flowcare_mobile/models/patient_registration.dart';
import 'package:flowcare_mobile/providers/auth_provider.dart';
import 'package:flowcare_mobile/screens/auth/login_screen.dart';
import 'package:flowcare_mobile/screens/auth/register_screen.dart';
import 'package:flowcare_mobile/services/auth_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

const phone = '0901234567', patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
const registration = PatientRegistration(
  fullName: ' Khách mới ',
  phone: ' $phone ',
  password: ' password123 ',
);
http.Response response(Object data, {int status = 201}) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
AuthService service(Future<http.Response> Function(http.Request) handle) =>
    AuthService(
      client: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient(handle),
      ),
    );

class FakeRegistration extends AuthService {
  PatientRegistration? submitted;
  int writes = 0;
  Completer<String>? pending;
  @override
  Future<String> register(PatientRegistration registration) async {
    writes++;
    submitted = registration;
    return pending != null ? await pending!.future : registration.phone.trim();
  }
}

void main() {
  setUp(() {
    ApiClient.setAuthToken(null);
    PatientSessionService().clearSession();
  });
  tearDown(() {
    ApiClient.setAuthToken(null);
    PatientSessionService().clearSession();
  });

  test('registration sends one anonymous request and never stores credentials or opens a session', () async {
    var calls = 0;
    final auth = AuthProvider(
      service: service((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/register');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'userName': phone,
          'phone': phone,
          'fullName': 'Khách mới',
          'password': ' password123 ',
        });
        return response({
          'userName': phone,
          'patientId': patientId,
          'accessToken': 'unused-token',
        });
      }),
    );
    addTearDown(auth.dispose);
    expect(await auth.register(registration), phone);
    expect(calls, 1);
    expect(auth.isAuthenticated, isFalse);
    expect(ApiClient.authToken, isNull);
    expect(PatientSessionService().patientId, isNull);
  });
  test('existing hospital records direct patients to reception using the current BE error code', () async {
    final auth = AuthProvider(
      service: service(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'errors': ['PATIENT_ACCOUNT_AT_RECEPTION'],
          }),
          409,
        ),
      ),
    );
    addTearDown(auth.dispose);
    expect(await auth.register(registration), isNull);
    expect(auth.message, contains('giấy tờ tùy thân'));
    expect(auth.message, contains('cấp tài khoản'));
    expect(ApiClient.authToken, isNull);
  });
  test(
    'calendar DOB is preserved and invalid signup never reaches BE',
    () async {
      expect(
        PatientRegistration(
          fullName: 'Test',
          phone: phone,
          password: 'password123',
          dob: DateTime(2003, 2, 17),
        ).toJson()['dob'],
        '2003-02-17',
      );
      var calls = 0;
      final auth = service((_) async {
        calls++;
        return response({});
      });
      for (final invalid in [
        const PatientRegistration(
          fullName: 'A',
          phone: phone,
          password: 'password123',
        ),
        const PatientRegistration(
          fullName: 'Test',
          phone: 'abc',
          password: 'password123',
        ),
        const PatientRegistration(
          fullName: 'Test',
          phone: phone,
          password: 'short',
        ),
      ]) {
        await expectLater(
          auth.register(invalid),
          throwsA(isA<ValidationException>()),
        );
      }
      expect(calls, 0);
    },
  );
  test('network loss and mismatched responses never fabricate a successful registration', () async {
    var calls = 0;
    await expectLater(
      service((_) async {
        calls++;
        throw http.ClientException('offline');
      }).register(registration),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('trước khi đăng ký lại'),
        ),
      ),
    );
    expect(calls, 1);
    await expectLater(
      service(
        (_) async => response({'userName': 'other', 'patientId': patientId}),
      ).register(registration),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'duplicate taps send once and a late response cannot survive logout',
    () async {
      final fake = FakeRegistration()..pending = Completer<String>();
      final auth = AuthProvider(service: fake);
      addTearDown(auth.dispose);
      final first = auth.register(registration);
      expect(await auth.register(registration), isNull);
      expect(fake.writes, 1);
      auth.logout();
      fake.pending!.complete(phone);
      expect(await first, isNull);
      expect(auth.isAuthenticated, isFalse);
    },
  );

  Future<void> showLogin(
    WidgetTester tester,
    FakeRegistration fake, {
    double scale = 1,
    double keyboard = 0,
  }) async {
    final auth = AuthProvider(service: fake);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Đăng ký tài khoản'));
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String confirmation = 'password123',
  }) async {
    for (final entry in {
      'register-name': 'Khách mới',
      'register-phone': phone,
      'register-password': 'password123',
      'register-confirmation': confirmation,
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'new registration has no retired reception-code controls and returns a phone for login',
    (tester) async {
      final fake = FakeRegistration();
      await showLogin(tester, fake);
      expect(find.byKey(const Key('register-link-code')), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      await fill(tester);
      expect(fake.writes, 1);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.textContaining('Tạo tài khoản thành công'), findsOneWidget);
      expect(find.textContaining('mật khẩu tạm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('confirmation mismatch prevents signup', (tester) async {
    final fake = FakeRegistration();
    await showLogin(tester, fake);
    await fill(tester, confirmation: 'different');
    expect(fake.writes, 0);
    expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
  });
  testWidgets('signup remains usable with large text and keyboard', (
    tester,
  ) async {
    await showLogin(tester, FakeRegistration(), scale: 1.5, keyboard: 260);
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
