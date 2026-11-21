import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/medical_payment_service.dart';
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
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(String patientId) async => summary;
}

void main() {
  testWidgets('Two follow-up services offer one QR payment', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = PatientSessionService()
      ..bindPatient(patientId: 'patient', userName: 'test');
    ApiClient.setAuthToken('patient-token');
    addTearDown(session.clearSession);
    addTearDown(() => ApiClient.setAuthToken(null));

    final plan = activeTimedPlanJson()..['source'] = 'PreExamOrders';
    final steps = (plan['steps'] as List).cast<Map<String, dynamic>>();
    steps[0]['preExamOrderId'] = 'pre-1';
    steps[1]['preExamOrderId'] = 'pre-2';
    final encounters = _ActiveEncounters()
      ..summary = summaryFixture(status: 'PendingPreExam')
      ..plan = ParaclinicalPlanModel.fromJson(plan);
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();

    final requests = <http.Request>[];
    final service = MedicalPaymentService(api: ApiClient(
      baseUrl: 'https://fixture.test/api/v1',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/billing')) {
          return http.Response(jsonEncode({'success': true, 'data': {
            'encounterId': 'visit-1',
            'items': [for (final id in ['pre-1', 'pre-2']) {
              'purpose': 'PreExamOrder', 'referenceId': id,
              'outstanding': 100000, 'isSettled': false, 'payBeforeService': true,
            }],
          }}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'success': true, 'data': {
          'purpose': 'Paraclinical', 'orderIds': ['pre-1', 'pre-2'],
          'encounterId': 'visit-1', 'orderCode': 123, 'amount': 200000,
          'status': 'Pending', 'qrCode': 'synthetic QR payload',
          'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        }}), 200, headers: {'content-type': 'application/json'});
      }),
    ));
    addTearDown(service.close);
    final optimization = FakeOptimization();
    addTearDown(optimization.close);
    await tester.pumpWidget(ChangeNotifierProvider<HomeProvider>.value(
      value: home, child: MaterialApp(home: RouteScreen(
        optimizationService: optimization, paymentService: service,
      )),
    ));
    await tester.pumpAndSettle();
    final paymentButton = find.widgetWithText(OutlinedButton, 'Thanh toán tổng phí');
    await tester.scrollUntilVisible(paymentButton, 120);
    await tester.pumpAndSettle();
    expect(paymentButton, findsOneWidget);
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    final create = requests.singleWhere((request) => request.method == 'POST');
    expect(jsonDecode(create.body), {'purpose': 'Paraclinical', 'orderIds': ['pre-1', 'pre-2']});
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
