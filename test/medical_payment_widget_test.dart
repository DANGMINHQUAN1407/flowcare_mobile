import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/medical_payment_service.dart';
import 'package:flowcare_mobile/services/route_optimization_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'fixtures/journey_fixtures.dart';
import 'home_journey_provider_test.dart' show FakeEncounters, fakeHome;
import 'route_optimization_widget_test.dart' show FakeOptimization;

class _ActiveEncounters extends FakeEncounters {
  @override
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(
    String patientId,
  ) async => summary;
}

http.Response _billingResponse(Map<String, int> balances) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'encounterId': 'visit-1',
      'items': [
        for (final entry in balances.entries)
          {
            'purpose': 'MedicalOrder',
            'referenceId': entry.key,
            'outstanding': entry.value,
            'isSettled': entry.value == 0,
            'payBeforeService': true,
          },
      ],
    },
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'Approved orders can be optimized before payment and then locked',
    (tester) async {
      final session = PatientSessionService()
        ..bindPatient(patientId: 'patient', userName: 'test');
      ApiClient.setAuthToken('patient-token');
      addTearDown(session.clearSession);
      addTearDown(() => ApiClient.setAuthToken(null));

      final baseline = activeTimedPlanJson()
        ..['mode'] = 'OriginalOrder'
        ..['estimatedTotalMinutes'] = 29;
      final steps = (baseline['steps'] as List).cast<Map<String, dynamic>>();
      steps[0]['medicalOrderId'] = 'order-xray';
      steps[1]['medicalOrderId'] = 'order-lab';
      steps[0]['serviceCode'] = 'XRAY';
      steps[1]['serviceCode'] = 'LAB_TEST';
      for (final step in steps) {
        step['serviceName'] = step.remove('serviceTypeName');
      }
      final offered = {
        ...baseline,
        'id': 'optimized-plan',
        'status': 'Proposed',
        'mode': 'Optimized',
        'estimatedTotalMinutes': 24,
        'steps': [
          {...steps[1], 'stepOrder': 1, 'status': 'InQueue'},
          {...steps[0], 'stepOrder': 2, 'status': 'Pending'},
        ],
      };
      final encounters = _ActiveEncounters()
        ..summary = summaryFixture(status: 'InQueue', queueStatus: 'InProgress')
        ..plan = ParaclinicalPlanModel.fromJson({
          ...baseline,
          'status': 'Proposed',
        });
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      await home.loadHomeData();

      final requests = <http.Request>[];
      final optimization = RouteOptimizationService(
        apiClient: ApiClient(
          baseUrl: 'https://fixture.test/api/v1',
          client: MockClient((request) async {
            requests.add(request);
            final plan = encounters.plan!;
            Object? result;
            if (request.method == 'POST' &&
                request.url.path.endsWith('/optimize')) {
              expect(jsonDecode(request.body), {
                'proposedPlanId': 'optimized-plan',
              });
              result = {
                ...offered,
                'status': 'Active',
                'offer': {'status': 'Accepted', 'savedMinutes': 5},
              };
              encounters.plan = ParaclinicalPlanModel.fromJson(
                result as Map<String, dynamic>,
              );
            } else {
              final canOptimize =
                  plan.status == 'Active' &&
                  plan.id == 'plan-1' &&
                  !plan.isLocked;
              result = {
                'activePlanId': plan.isProposed ? null : plan.id,
                'remainingOrders': plan.isProposed ? 0 : 2,
                'canOptimize': canOptimize,
                if (canOptimize) ...{
                  'proposedPlanId': 'optimized-plan',
                  'currentTotalMinutes': 29,
                  'offeredTotalMinutes': 24,
                  'savedMinutes': 5,
                  'offer': offered,
                } else
                  'reason': plan.isLocked ? 'ROUTE_LOCKED' : 'NO_BETTER_ROUTE',
              };
            }
            return http.Response(
              jsonEncode({'success': true, 'data': result}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      addTearDown(optimization.close);
      final balances = {'order-xray': 100000, 'order-lab': 120000};
      final paymentService = MedicalPaymentService(
        api: ApiClient(
          baseUrl: 'https://fixture.test/api/v1',
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/encounters/visit-1/billing');
            return _billingResponse(balances);
          }),
        ),
      );
      addTearDown(paymentService.close);
      await tester.pumpWidget(
        ChangeNotifierProvider<HomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: RouteScreen(
              optimizationService: optimization,
              paymentService: paymentService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final optimize = find.text('Tối ưu lộ trình');
      final payment = find.text('Thanh toán cận lâm sàng');
      expect(find.text('Lộ trình chờ duyệt'), findsOneWidget);
      expect(optimize, findsOneWidget);
      expect(payment, findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      encounters.plan = ParaclinicalPlanModel.fromJson(baseline);
      await home.refreshJourney(includeFinalized: true);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(optimize, 150);
      await tester.pumpAndSettle();
      expect(payment, findsNothing);
      expect(find.textContaining('1. Chụp X-Quang'), findsOneWidget);
      expect(find.textContaining('2. Xét nghiệm máu'), findsOneWidget);
      await tester.tap(optimize);
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/optimize/request'),
        ),
        hasLength(1),
      );

      final accept = find.text('Chấp nhận đề xuất');
      await tester.scrollUntilVisible(accept, 120);
      await tester.pumpAndSettle();
      expect(find.text('Hiện tại 29 phút · Đề xuất 24 phút'), findsOneWidget);
      expect(payment, findsNothing);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      final accepts = requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/optimize'),
      );
      expect(accepts, isEmpty);
      await tester.tap(find.text('Xác nhận chấp nhận'));
      await tester.pumpAndSettle();
      expect(accepts, hasLength(1));
      expect(home.journey!.plan!.steps.first.medicalOrderId, 'order-lab');
      expect(optimize, findsNothing);
      expect(accept, findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(payment, 120);
      await tester.pumpAndSettle();
      expect(find.textContaining('Còn phải trả: 120.000'), findsOneWidget);
      expect(find.textContaining('Còn phải trả: 100.000'), findsOneWidget);

      encounters.plan = ParaclinicalPlanModel.fromJson({
        ...offered,
        'status': 'Active',
        'isLocked': true,
        'offer': {'status': 'Accepted', 'savedMinutes': 5},
      });
      await home.refreshJourney(includeFinalized: true);
      await tester.pumpAndSettle();
      expect(home.journey!.plan!.isLocked, isTrue);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final locked = find.text('Lộ trình đã được bác sĩ khóa.');
      await tester.scrollUntilVisible(locked, 120);
      await tester.pumpAndSettle();
      expect(locked, findsOneWidget);
      expect(optimize, findsNothing);
      expect(accept, findsNothing);
      await tester.scrollUntilVisible(payment, 120);
      expect(payment, findsOneWidget);

      balances['order-lab'] = 0;
      await home.refreshJourney(includeFinalized: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Còn phải trả: 120.000'), findsNothing);
      expect(find.textContaining('Còn phải trả: 100.000'), findsOneWidget);

      balances['order-xray'] = 0;
      await home.refreshJourney(includeFinalized: true);
      await tester.pumpAndSettle();
      expect(home.journey!.plan!.steps, hasLength(2));
      expect(payment, findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Chụp X-Quang'), findsNothing);
    },
  );

  testWidgets('An approved service offers counter payment and verifies PayOS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = PatientSessionService()
      ..bindPatient(patientId: 'patient', userName: 'test');
    ApiClient.setAuthToken('patient-token');
    addTearDown(session.clearSession);
    addTearDown(() => ApiClient.setAuthToken(null));
    final plan = activeTimedPlanJson();
    final xray = (plan['steps'] as List).first as Map<String, dynamic>;
    xray['medicalOrderId'] = 'order-xray';
    xray['serviceCode'] = 'XRAY';
    xray['serviceName'] = xray.remove('serviceTypeName');
    final home = fakeHome(
      encounters: _ActiveEncounters()
        ..summary = summaryFixture(status: 'InQueue')
        ..plan = ParaclinicalPlanModel.fromJson(plan),
    );
    addTearDown(home.dispose);
    await home.loadHomeData();
    final calls = <http.Request>[];
    var status = 'Pending';
    var checkCode = 123;
    final service = MedicalPaymentService(
      api: ApiClient(
        baseUrl: 'https://fixture.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/encounters/visit-1/billing') {
            return _billingResponse({
              'order-xray': status == 'Paid' ? 0 : 80000,
            });
          }
          calls.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'purpose': 'MedicalOrder',
                'referenceId': 'order-xray',
                'encounterId': 'visit-1',
                'orderCode': checkCode,
                'amount': 80000,
                'status': status,
                'qrCode': 'synthetic QR payload',
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 15))
                    .toIso8601String(),
              },
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(service.close);
    final optimization = FakeOptimization()..proposed = true;
    addTearDown(optimization.close);

    Widget screen(bool visible) => ChangeNotifierProvider<HomeProvider>.value(
      value: home,
      child: MaterialApp(
        home: RouteScreen(
          isVisible: visible,
          optimizationService: optimization,
          paymentService: service,
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final paymentButton = find.widgetWithText(OutlinedButton, 'Chụp X-Quang');
    await tester.scrollUntilVisible(paymentButton, 120);
    await tester.pumpAndSettle();
    expect(find.textContaining('Còn phải trả: 80.000'), findsOneWidget);
    expect(find.text('Dịch vụ cận lâm sàng'), findsNothing);
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại quầy lễ tân'));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán tại quầy lễ tân'), findsOneWidget);
    expect(find.textContaining('và thu phí Chụp X-Quang'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Còn phải trả: 80.000'),
      ),
      findsOneWidget,
    );
    expect(calls, isEmpty);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.scrollUntilVisible(paymentButton, 120);
    await tester.pumpAndSettle();
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán QR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Số tiền thanh toán: 80.000'), findsOneWidget);
    expect(
      find.byType(QrImageView),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .join(' | '),
    );
    expect(
      calls.single.url.path,
      '/api/v1/encounters/visit-1/payos/payment-links',
    );
    expect(jsonDecode(calls.single.body), {
      'purpose': 'MedicalOrder',
      'referenceId': 'order-xray',
    });

    expect(find.text('Kiểm tra thanh toán'), findsNothing);
    status = 'Paid';
    checkCode = 999;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    checkCode = 123;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(calls.last.url.path, '/api/v1/payos/payment-links/123');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    const paidNotice = 'Đã chuyển tiền thành công 80.000\u00a0₫ cho Chụp X-Quang.';
    expect(find.text(paidNotice), findsOneWidget);
    expect(home.notices.map((n) => n.message), contains(paidNotice));
    expect(paymentButton, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
