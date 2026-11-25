import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/models/route_optimization_model.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/route_optimization_service.dart';
import 'package:flowcare_mobile/widgets/route_optimization_card.dart';

class FakeOptimization extends RouteOptimizationService {
  int calls = 0;
  int requests = 0;
  bool proposed = false;
  String? declinedReason;
  String proposalId = 'proposal';
  String encounterId = 'visit';
  String? activePlanId;
  DateTime? expiresAt;
  bool replaceOnAccept = false;
  final complete = Completer<ParaclinicalPlanModel>();
  @override
  Future<RouteOptimizationEligibility> decline(
    String id,
    String patient,
    String proposedPlanId,
    String reason,
  ) async {
    declinedReason = reason;
    proposed = true;
    return RouteOptimizationEligibility.fromJson({
      'canOptimize': false,
      'remainingOrders': 2,
    });
  }

  @override
  Future<RouteOptimizationEligibility> eligibility(
    String id,
    String patient,
  ) async => RouteOptimizationEligibility.fromJson({
    'canOptimize': !proposed,
    'remainingOrders': 2,
    'activePlanId': proposed ? 'proposal' : activePlanId,
    if (!proposed) 'proposedPlanId': proposalId,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (!proposed) 'savedMinutes': 12,
    if (!proposed)
      'offer': {
        'id': proposalId,
        'encounterId': encounterId,
        'status': 'Proposed',
        'steps': [],
      },
  });

  @override
  Future<RouteOptimizationEligibility> requestOptimization(
    String id,
    String patient,
  ) {
    requests++;
    return eligibility(id, patient);
  }

  @override
  Future<ParaclinicalPlanModel> accept(
    String id,
    String patient,
    String proposedPlanId,
  ) async {
    calls++;
    if (replaceOnAccept) {
      proposalId = 'replacement';
      throw ApiException(
        'Lộ trình được đề nghị không còn nhanh hơn đáng kể.',
        statusCode: 409,
        data: {
          'errors': ['OFFER_NOT_WORTH'],
        },
      );
    }
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
  testWidgets('offer actions appear before the expanded current route', (
    tester,
  ) async {
    final fake = FakeOptimization()..activePlanId = 'original';
    addTearDown(fake.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RouteOptimizationCard(
              encounterId: 'visit',
              patientId: 'patient',
              service: fake,
              currentPlan: const ParaclinicalPlanModel(
                id: 'original',
                encounterId: 'visit',
                status: 'Active',
                source: 'MedicalOrders',
                nextAfterPlan: '',
                steps: [
                  ParaclinicalStepModel(
                    id: 'step',
                    serviceTypeName: 'Xét nghiệm',
                    roomName: 'Phòng 1',
                    stepOrder: 1,
                    status: 'Pending',
                  ),
                ],
              ),
              onRouteReviewed: (_) {},
              onChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lộ trình hiện tại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối ưu lộ trình'));
    await tester.pumpAndSettle();
    expect(fake.requests, 1);
    expect(fake.calls, 0);
    expect(
      tester.getTopLeft(find.text('Chấp nhận đề xuất')).dy,
      lessThan(tester.getTopLeft(find.text('Lộ trình hiện tại')).dy),
    );
  });
  for (final expired in [true, false]) {
    testWidgets(
      expired
          ? 'expired offer cannot be accepted'
          : 'replacement needs another confirmation',
      (tester) async {
        final fake = FakeOptimization()
          ..replaceOnAccept = !expired
          ..expiresAt = expired
              ? DateTime.now().subtract(const Duration(minutes: 1))
              : null;
        addTearDown(fake.close);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RouteOptimizationCard(
                encounterId: 'visit',
                patientId: 'patient',
                service: fake,
                onChanged: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final accept = find.text('Chấp nhận đề xuất');
        if (expired) {
          expect(accept, findsNothing);
          expect(find.text('Đề xuất tối ưu đã hết hạn.'), findsOneWidget);
          expect(fake.calls, 0);
        } else {
          expect(accept, findsNothing);
          await tester.tap(find.text('Nhờ tối ưu lộ trình'));
          await tester.pumpAndSettle();
          await tester.tap(accept);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Xác nhận chấp nhận'));
          await tester.pumpAndSettle();
          expect(fake.calls, 1);
          expect(accept, findsNothing);
          expect(find.text('Nhờ tối ưu lộ trình'), findsOneWidget);
          expect(
            find.textContaining('không còn nhanh hơn đáng kể'),
            findsOneWidget,
          );
          expect(
            find.textContaining('tiếp tục theo lộ trình hiện tại'),
            findsOneWidget,
          );
        }
      },
    );
  }
  testWidgets('patient can decline with a reason without accepting', (
    tester,
  ) async {
    final fake = FakeOptimization();
    addTearDown(fake.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteOptimizationCard(
            encounterId: 'visit',
            patientId: 'patient',
            service: fake,
            onChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Từ chối đề xuất'), findsNothing);
    await tester.tap(find.text('Nhờ tối ưu lộ trình'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối đề xuất'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Muốn giữ thứ tự hiện tại');
    await tester.tap(find.text('Xác nhận từ chối'));
    await tester.pumpAndSettle();
    expect(fake.declinedReason, 'Muốn giữ thứ tự hiện tại');
    expect(fake.calls, 0);
    expect(find.text('Đã từ chối đề xuất.'), findsOneWidget);
  });
  testWidgets(
    'a patient can choose an optimized draft and then waits for the doctor to lock it',
    (tester) async {
      final fake = FakeOptimization()..activePlanId = 'original';
      addTearDown(fake.close);
      var updates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteOptimizationCard(
              encounterId: 'visit',
              patientId: 'patient',
              service: fake,
              currentPlan: const ParaclinicalPlanModel(
                id: 'original',
                encounterId: 'visit',
                status: 'Proposed',
                source: 'MedicalOrders',
                isLocked: true,
                nextAfterPlan: '',
                steps: [],
              ),
              onChanged: () async {
                updates++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lộ trình chờ duyệt'), findsOneWidget);
      await tester.tap(find.text('Tối ưu lộ trình'));
      await tester.pumpAndSettle();
      expect(fake.requests, 1);
      expect(find.text('Lộ trình đề xuất'), findsOneWidget);
      await tester.tap(find.text('Chấp nhận đề xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận chấp nhận'));
      await tester.pump();
      expect(fake.calls, 1);
      fake.complete.complete(
        const ParaclinicalPlanModel(
          id: 'proposal',
          encounterId: 'visit',
          status: 'Proposed',
          source: 'MedicalOrders',
          acceptedOfferSavedMinutes: 12,
          nextAfterPlan: '',
          steps: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(updates, 1);
      expect(find.text('Phương án đã chọn'), findsOneWidget);
      expect(
        find.textContaining('Chờ bác sĩ duyệt và khóa lộ trình.'),
        findsWidgets,
      );
      expect(find.text('Lộ trình đã áp dụng'), findsNothing);
      expect(find.text('Tối ưu lộ trình'), findsNothing);
    },
  );
  testWidgets(
    'patient confirms the optimized route and cannot optimize it again',
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
      expect(find.byKey(const ValueKey('accept-route-offer')), findsNothing);
      expect(fake.requests, 0);
      await tester.tap(find.text('Nhờ tối ưu lộ trình'));
      await tester.pumpAndSettle();
      expect(fake.requests, 1);
      expect(find.text('Dự kiến tiết kiệm 12 phút.'), findsOneWidget);
      final button = find.byKey(const ValueKey('accept-route-offer'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn có chấp nhận lộ trình đề xuất không?'),
        findsOneWidget,
      );
      expect(fake.calls, 0);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(fake.calls, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận chấp nhận'));
      await tester.pump();
      expect(fake.calls, 1);
      fake.complete.complete(
        const ParaclinicalPlanModel(
          id: 'proposal',
          encounterId: 'visit',
          status: 'Active',
          source: 'MedicalOrders',
          mode: 'Optimized',
          acceptedOfferSavedMinutes: 12,
          nextAfterPlan: '',
          steps: [],
          estimatedTotalMinutes: 42,
        ),
      );
      await tester.pumpAndSettle();
      expect(changed, 1);
      expect(
        find.textContaining('Đã áp dụng lộ trình tối ưu.'),
        findsOneWidget,
      );
      expect(find.textContaining('Chờ bác sĩ duyệt'), findsNothing);
      expect(find.text('Lộ trình đã áp dụng'), findsOneWidget);
      expect(find.text('Nhờ tối ưu lộ trình'), findsNothing);
      expect(button, findsNothing);
      expect(find.textContaining('Chờ tiếp nhận'), findsNothing);
      expect(tester.takeException(), isNull);

      // Reopen the card while the old backend still reports another offer.
      fake
        ..proposed = false
        ..activePlanId = 'proposal'
        ..proposalId = 'new-proposal';
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteOptimizationCard(
              encounterId: 'visit',
              patientId: 'patient',
              service: fake,
              currentPlan: await fake.complete.future,
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhờ tối ưu lộ trình'), findsNothing);
      expect(find.text('Chấp nhận đề xuất'), findsNothing);
    },
  );
}
