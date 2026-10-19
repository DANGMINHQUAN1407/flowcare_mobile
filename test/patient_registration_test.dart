import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const phone = '0901234567';
const patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
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
http.Response conflict(String code) => http.Response(
  jsonEncode({
    'success': false,
    'message': 'Conflict',
    'errors': [code],
  }),
  409,
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
  Object? error;
  @override
  Future<String> register(PatientRegistration registration) async {
    writes++;
    submitted = registration;
    if (error != null) throw error!;
    return pending != null
        ? await pending!.future
        : registration.isFromReception
        ? phone
        : registration.phone.trim();
  }
}

void main() {
  const captureDirectory = String.fromEnvironment('AUTH_CAPTURE_DIR');
  const captureFont = String.fromEnvironment('AUTH_CAPTURE_FONT');
  setUpAll(() async {
    if (captureDirectory.isNotEmpty && captureFont.isNotEmpty) {
      final loader = FontLoader('AuthPreview')
        ..addFont(File(captureFont).readAsBytes().then(ByteData.sublistView));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  setUp(() {
    ApiClient.setAuthToken(null);
    PatientSessionService().clearSession();
  });
  tearDown(() {
    ApiClient.setAuthToken(null);
    PatientSessionService().clearSession();
  });

  test('registration sends one anonymous BE POST; no password/token/session is stored', () async {
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
          'accessToken': 'unused-new-token',
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

  test(
    'optional DOB is sent as a calendar date; invalid inputs never call BE',
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
      final auth = service((request) async {
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

  test('a new online patient signs in with the same account and verified PatientId', () async {
    final paths = <String>[];
    final auth = AuthProvider(
      service: service((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/register')) {
          return response({'userName': phone, 'patientId': patientId});
        }
        if (request.url.path.endsWith('/login')) {
          expect(jsonDecode(request.body), {
            'userName': phone,
            'password': ' password123 ',
          });
          return response({
            'accessToken': 'patient-token',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          }, status: 200);
        }
        expect(request.headers['Authorization'], 'Bearer patient-token');
        return response({
          'roles': ['PATIENT'],
          'patientId': patientId,
          'userName': phone,
        }, status: 200);
      }),
    );
    addTearDown(auth.dispose);
    final userName = await auth.register(registration);
    expect(await auth.login(userName!, registration.password), isTrue);
    expect(paths, [
      '/api/v1/auth/register',
      '/api/v1/auth/login',
      '/api/v1/auth/me',
    ]);
    expect(PatientSessionService().patientId, patientId);
    expect(auth.currentUser!.isDemo, isFalse);
  });

  test('an existing walk-in record requires verification without offering staff-issued credentials', () async {
    final auth = AuthProvider(
      service: service(
        (request) async => conflict('PATIENT_LINK_VERIFICATION_REQUIRED'),
      ),
    );
    addTearDown(auth.dispose);
    expect(await auth.register(registration), isNull);
    expect(auth.message, contains('đã có hồ sơ'));
    expect(auth.message, contains('mã liên kết trên phiếu khám'));
    expect(auth.message, isNot(contains('cấp tài khoản')));
    expect(auth.message, isNot(contains('quầy tiếp đón')));
    expect(ApiClient.authToken, isNull);
  });

  test('walk-in registration sends the normalized receipt code in one anonymous POST', () async {
    var writes = 0;
    final auth = service((request) async {
      writes++;
      expect(request.headers['Authorization'], isNull);
      final body = jsonDecode(request.body) as Map;
      expect(body['registrationLinkCode'], 'ABCDEF01023456789ABCDEF0');
      expect(request.url.path, '/api/v1/auth/register-from-reception');
      expect(body.containsKey('phone'), isFalse);
      expect(body.containsKey('fullName'), isFalse);
      expect(body.containsKey('dob'), isFalse);
      expect(body['password'], 'password123');
      return response({'userName': phone, 'patientId': patientId});
    });
    expect(
      await auth.register(
        const PatientRegistration.fromReception(
          password: 'password123',
          registrationLinkCode: 'abcdef01-02345678-9abcdef0',
        ),
      ),
      phone,
    );
    expect(writes, 1);
    expect(ApiClient.authToken, isNull);
  });

  test('malformed link code never sends a signup POST and invalid proof offers reissue guidance', () async {
    var writes = 0;
    final auth = service((request) async {
      writes++;
      return conflict('REGISTRATION_LINK_INVALID');
    });
    await expectLater(
      auth.register(
        const PatientRegistration.fromReception(
          password: 'password123',
          registrationLinkCode: '123',
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(writes, 0);
    final provider = AuthProvider(service: auth);
    addTearDown(provider.dispose);
    expect(
      await provider.register(
        const PatientRegistration.fromReception(
          password: 'password123',
          registrationLinkCode: 'ABCDEF01-02345678-9ABCDEF0',
        ),
      ),
      isNull,
    );
    expect(writes, 1);
    expect(provider.message, contains('xin mã mới tại quầy'));
    expect(provider.isAuthenticated, isFalse);
  });

  for (final code in ['DUPLICATE_USERNAME', 'ACCOUNT_ALREADY_EXISTS']) {
    test(
      '$code is a useful Vietnamese error without a local fallback identity',
      () async {
        final auth = AuthProvider(
          service: service((request) async => conflict(code)),
        );
        addTearDown(auth.dispose);
        expect(await auth.register(registration), isNull);
        expect(auth.message, contains('đã tồn tại'));
        expect(auth.isAuthenticated, isFalse);
      },
    );
  }

  test('lost response never replays registration and instructs login before another attempt', () async {
    var writes = 0;
    final auth = AuthProvider(
      service: service((request) async {
        writes++;
        throw http.ClientException('disconnected');
      }),
    );
    addTearDown(auth.dispose);
    expect(await auth.register(registration), isNull);
    expect(writes, 1);
    expect(auth.message, contains('trước khi đăng ký lại'));
    expect(auth.isAuthenticated, isFalse);
  });

  test(
    'mismatched registration response does not create a mobile session',
    () async {
      final auth = AuthProvider(
        service: service(
          (request) async =>
              response({'userName': 'another-user', 'patientId': patientId}),
        ),
      );
      addTearDown(auth.dispose);
      expect(await auth.register(registration), isNull);
      expect(auth.message, contains('Chưa xác minh'));
      expect(ApiClient.authToken, isNull);
    },
  );

  test(
    'concurrent taps send once; logout ignores a late registration result',
    () async {
      final fake = FakeRegistration()..pending = Completer<String>();
      final auth = AuthProvider(service: fake);
      addTearDown(auth.dispose);
      final write = auth.register(registration);
      expect(auth.isBusy, isTrue);
      expect(await auth.register(registration), isNull);
      expect(fake.writes, 1);
      auth.logout();
      fake.pending!.complete(phone);
      expect(await write, isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(ApiClient.authToken, isNull);
    },
  );

  Future<AuthProvider> showLogin(
    WidgetTester tester,
    FakeRegistration fake, {
    double scale = 1,
    double keyboard = 0,
  }) async {
    final auth = AuthProvider(service: fake);
    addTearDown(auth.dispose);
    var theme = AppTheme.lightTheme;
    if (captureDirectory.isNotEmpty && captureFont.isNotEmpty) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'AuthPreview'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'AuthPreview',
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: 'AuthPreview',
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: theme.outlinedButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: 'AuthPreview', fontSize: 14),
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('auth-preview'),
        child: ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            theme: theme,
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
      ),
    );
    return auth;
  }

  Future<void> openRegistration(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Đăng ký tài khoản'));
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
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
    'login replaces the demo with registration and returns with the real username',
    (tester) async {
      if (captureDirectory.isNotEmpty) {
        tester.view.physicalSize = const Size(393, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      Future<void> capture(String name) async {
        if (captureDirectory.isEmpty) return;
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('auth-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$captureDirectory/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final fake = FakeRegistration();
      final auth = await showLogin(tester, fake);
      expect(find.textContaining('Demo'), findsNothing);
      await capture('MOBILE_PATIENT_LOGIN_2026-10-17');
      await openRegistration(tester);
      await capture('MOBILE_PATIENT_REGISTER_2026-10-17');
      await fill(tester);
      expect(fake.writes, 1);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.textContaining('Tạo tài khoản thành công'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        phone,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      expect(auth.isAuthenticated, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmation mismatch prevents a signup POST', (tester) async {
    final fake = FakeRegistration();
    await showLogin(tester, fake);
    await openRegistration(tester);
    await fill(tester, confirmation: 'different');
    expect(fake.writes, 0);
    expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
  });

  testWidgets(
    'online and reception forms have separate fields and clear secrets when switching',
    (tester) async {
      if (captureDirectory.isNotEmpty) {
        tester.view.physicalSize = const Size(393, 1050);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      Future<void> captureMode(String name) async {
        if (captureDirectory.isEmpty) return;
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('auth-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$captureDirectory/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final fake = FakeRegistration();
      await showLogin(tester, fake);
      await openRegistration(tester);
      expect(find.byKey(const Key('register-name')), findsOneWidget);
      expect(find.byKey(const Key('register-phone')), findsOneWidget);
      expect(find.text('Ngày sinh (không bắt buộc)'), findsOneWidget);
      expect(find.byKey(const Key('register-link-code')), findsNothing);
      await captureMode('ONLINE_REGISTRATION_2026-10-19');
      await tester.enterText(
        find.byKey(const Key('register-name')),
        'Draft name',
      );
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Đã có mã tại quầy'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đã có mã tại quầy'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('register-name')), findsNothing);
      expect(find.byKey(const Key('register-phone')), findsNothing);
      expect(find.text('Ngày sinh (không bắt buộc)'), findsNothing);
      await captureMode('WALKIN_ACTIVATION_2026-10-19');
      final code = find.byKey(const Key('register-link-code'));
      await tester.ensureVisible(code);
      await tester.enterText(code, 'ABCDEF01-02345678-9ABCDEF0');
      final password = find.byKey(const Key('register-password'));
      await tester.ensureVisible(password);
      await tester.enterText(password, 'password123');
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Đăng ký mới'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đăng ký mới'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('register-link-code')), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('register-name')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
      expect(fake.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('anonymous receipt activation surfaces throttling without retry or a session', () async {
    var calls = 0;
    final auth = AuthProvider(
      service: service((request) async {
        calls++;
        return response({}, status: 429);
      }),
    );
    addTearDown(auth.dispose);
    expect(
      await auth.register(
        const PatientRegistration.fromReception(
          registrationLinkCode: 'ABCDEF01-02345678-9ABCDEF0',
          password: 'password123',
        ),
      ),
      isNull,
    );
    expect(auth.message, contains('Chờ một phút'));
    expect(calls, 1);
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets(
    'patient can enter the receipt code and choose their own password',
    (tester) async {
      final fake = FakeRegistration();
      await showLogin(tester, fake);
      await openRegistration(tester);
      final code = find.byKey(const Key('register-link-code'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đã có mã tại quầy'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('register-name')), findsNothing);
      expect(find.byKey(const Key('register-phone')), findsNothing);
      expect(find.text('Ngày sinh (không bắt buộc)'), findsNothing);
      await tester.ensureVisible(code);
      await tester.enterText(code, 'ABCDEF01-02345678-9ABCDEF0');
      final password = find.byKey(const Key('register-password'));
      await tester.ensureVisible(password);
      await tester.enterText(password, 'password123');
      final confirmation = find.byKey(const Key('register-confirmation'));
      await tester.ensureVisible(confirmation);
      await tester.enterText(confirmation, 'password123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.writes, 1);
      expect(
        fake.submitted!.registrationLinkCode,
        'ABCDEF01-02345678-9ABCDEF0',
      );
      expect(fake.submitted!.password, 'password123');
      expect(fake.submitted!.isFromReception, isTrue);
      expect(fake.submitted!.fullName, isEmpty);
      expect(fake.submitted!.phone, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration failure stays on form with entered fields and actionable help',
    (tester) async {
      final fake = FakeRegistration()
        ..error = ApiException(
          'Số điện thoại đã có hồ sơ. Liên hệ quầy tiếp đón.',
        );
      await showLogin(tester, fake);
      await openRegistration(tester);
      await fill(tester);
      expect(fake.writes, 1);
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.textContaining('Số điện thoại đã có hồ sơ'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('register-phone')))
            .controller!
            .text,
        phone,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration fits 320px with a keyboard and enlarged text; back preserves no password',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = FakeRegistration();
      await showLogin(tester, fake, scale: 1.4, keyboard: 260);
      await openRegistration(tester);
      await tester.ensureVisible(find.text('Tạo tài khoản'));
      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập họ tên từ 2 đến 150 ký tự.'), findsOneWidget);
      expect(fake.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Về đăng nhập'));
      await tester.tap(find.text('Về đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.textContaining('Demo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
