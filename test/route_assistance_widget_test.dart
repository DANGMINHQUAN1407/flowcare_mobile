import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/core/theme/app_theme.dart';
import 'package:flowcare_mobile/models/route_assistance_model.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/route_assistance_service.dart';
import 'package:flowcare_mobile/widgets/route_assistance_card.dart';

import 'fixtures/route_assistance_fixtures.dart';

class FakeAssistance extends RouteAssistanceService {
  AssistanceEligibility eligible = AssistanceEligibility.fromJson(
    eligibilityJson(),
  );
  RouteAssistanceRequest? row;
  Object? readError;
  Completer<RouteAssistanceRequest>? pendingWrite;
  int writes = 0, reads = 0;
  @override
  Future<AssistanceEligibility> eligibility(String id, String patient) async {
    reads++;
    if (readError != null) throw readError!;
    return eligible;
  }

  @override
  Future<RouteAssistanceRequest?> status(String id, String patient) async =>
      row;
  @override
  Future<RouteAssistanceRequest> request(String id, String patient) async {
    writes++;
    final response = pendingWrite != null
        ? await pendingWrite!.future
        : RouteAssistanceRequest.fromJson(assistanceJson());
    row = response;
    eligible = AssistanceEligibility.fromJson(
      eligibilityJson(canRequest: false),
    );
    return response;
  }

  @override
  Future<RouteComparison> compare(String id, String patient) async =>
      RouteComparison.fromJson(comparisonJson());
}

void main() {
  const previewFont = String.fromEnvironment('FLOW4_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final loader = FontLoader('Flow4Preview')
        ..addFont(File(previewFont).readAsBytes().then(ByteData.sublistView));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    );
    ApiClient.setAuthToken('patient.token.test');
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
  });
  Future<void> show(
    WidgetTester tester,
    FakeAssistance fake, {
    bool stale = false,
    DateTime? refresh,
    Future<void> Function()? applied,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: previewFont.isEmpty
            ? AppTheme.lightTheme
            : AppTheme.lightTheme.copyWith(
                textTheme: AppTheme.lightTheme.textTheme.apply(
                  fontFamily: 'Flow4Preview',
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: AppTheme.lightTheme.outlinedButtonTheme.style!
                      .copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'Flow4Preview',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                ),
                primaryTextTheme: AppTheme.lightTheme.primaryTextTheme.apply(
                  fontFamily: 'Flow4Preview',
                ),
              ),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: ListView(
              children: [
                RepaintBoundary(
                  key: const ValueKey('flow4-capture'),
                  child: RouteAssistanceCard(
                    encounterId: 'visit',
                    patientId: 'patient',
                    service: fake,
                    isStale: stale,
                    refreshToken: refresh,
                    onApplied: applied ?? () async {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton button(WidgetTester tester) => tester.widget<FilledButton>(
    find.byKey(const ValueKey('request-route-assistance')),
  );
  testWidgets(
    'button follows server eligibility and blocks repeated taps during POST',
    (tester) async {
      final fake = FakeAssistance()
        ..pendingWrite = Completer<RouteAssistanceRequest>();
      addTearDown(fake.close);
      await show(tester, fake);
      expect(button(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('request-route-assistance')));
      await tester.pump();
      expect(button(tester).onPressed, isNull);
      expect(fake.writes, 1);
      fake.pendingWrite!.complete(
        RouteAssistanceRequest.fromJson(assistanceJson()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã gửi · Chờ tiếp nhận'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
    },
  );
  testWidgets(
    'one order and lost connection explain why the action is disabled',
    (tester) async {
      final fake = FakeAssistance()
        ..eligible = AssistanceEligibility.fromJson(
          eligibilityJson(count: 1, canRequest: false),
        );
      addTearDown(fake.close);
      await show(tester, fake);
      expect(button(tester).onPressed, isNull);
      expect(find.textContaining('ít nhất 2 y lệnh'), findsOneWidget);
      fake.readError = NetworkException();
      await show(tester, fake, refresh: DateTime(2026));
      expect(button(tester).onPressed, isNull);
      expect(find.textContaining('Không thể kết nối'), findsOneWidget);
    },
  );
  testWidgets('comparison stays readable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeAssistance();
    addTearDown(fake.close);
    await show(tester, fake, scale: 1.5);
    await tester.ensureVisible(
      find.byKey(const ValueKey('compare-route-assistance')),
    );
    await tester.tap(find.byKey(const ValueKey('compare-route-assistance')));
    await tester.pumpAndSettle();
    expect(
      find.text('Dự kiến giảm 15 phút so với thứ tự chỉ định'),
      findsOneWidget,
    );
    expect(find.text('77 phút'), findsOneWidget);
    expect(find.text('62 phút'), findsOneWidget);
    const capturePath = String.fromEnvironment('FLOW4_CAPTURE');
    if (capturePath.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('flow4-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thứ tự tối ưu được đề xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thứ tự tối ưu được đề xuất'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Applied refreshes the patient journey, while Resolved alone does not',
    (tester) async {
      var refreshes = 0;
      final fake = FakeAssistance()
        ..row = RouteAssistanceRequest.fromJson(
          assistanceJson(status: 'Resolved', route: 'Proposed'),
        );
      addTearDown(fake.close);
      await show(
        tester,
        fake,
        applied: () async {
          refreshes++;
        },
      );
      expect(refreshes, 0);
      fake.row = RouteAssistanceRequest.fromJson(
        assistanceJson(status: 'Resolved', route: 'Applied'),
      );
      await show(
        tester,
        fake,
        refresh: DateTime(2026),
        applied: () async {
          refreshes++;
        },
      );
      expect(find.text('Lộ trình mới đã được áp dụng'), findsOneWidget);
      expect(find.text('Gửi yêu cầu tối ưu mới'), findsOneWidget);
      expect(refreshes, 1);
    },
  );
  testWidgets('readonly demo does not call assistance APIs', (tester) async {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'demo',
      isDemo: true,
    );
    final fake = FakeAssistance();
    addTearDown(fake.close);
    await show(tester, fake);
    expect(
      find.byKey(const ValueKey('request-route-assistance')),
      findsNothing,
    );
    expect(fake.reads, 0);
  });
}
