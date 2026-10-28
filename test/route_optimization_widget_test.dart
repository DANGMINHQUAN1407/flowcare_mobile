import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/models/route_optimization_model.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/route_optimization_service.dart';
import 'package:flowcare_mobile/widgets/route_optimization_card.dart';

class FakeOptimization extends RouteOptimizationService {
  int calls = 0;
  bool proposed = false;
  final complete = Completer<ParaclinicalPlanModel>();
  @override
  Future<RouteOptimizationEligibility> eligibility(
    String id,
    String patient,
  ) async => RouteOptimizationEligibility.fromJson({
    'canOptimize': !proposed,
    'remainingOrders': 2,
    'activePlanId': proposed ? 'proposal' : null,
  });
  @override
  Future<ParaclinicalPlanModel> optimize(String id, String patient) async {
    calls++;
    final result = await complete.future;
    proposed = true;
    return result;
  }
}

void main() {
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    );
    ApiClient.setAuthToken('token');
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
  });
  testWidgets(
    'one tap applies the optimized route and refreshes without doctor approval',
    (tester) async {
      final fake = FakeOptimization();
      addTearDown(fake.close);
      int changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteOptimizationCard(
                encounterId: 'visit',
                patientId: 'patient',
                service: fake,
                onChanged: () async {
                  changed++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('optimize-route'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(fake.calls, 1);
      fake.complete.complete(
        const ParaclinicalPlanModel(
          id: 'proposal',
          encounterId: 'visit',
          status: 'Active',
          source: 'MedicalOrders',
          mode: 'Optimized',
          nextAfterPlan: '',
          steps: [],
          estimatedTotalMinutes: 42,
        ),
      );
      await tester.pumpAndSettle();
      expect(changed, 1);
      expect(
        find.textContaining('Đã tối ưu và áp dụng lộ trình mới'),
        findsOneWidget,
      );
      expect(find.textContaining('Chờ bác sĩ duyệt'), findsNothing);
      expect(
        find.textContaining('Lộ trình đã áp dụng: 42 phút'),
        findsOneWidget,
      );
      expect(find.textContaining('Chờ tiếp nhận'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
