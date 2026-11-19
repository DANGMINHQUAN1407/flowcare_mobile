import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/providers/history_provider.dart';
import 'package:flowcare_mobile/screens/history/history_screen.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/models/visit_summary_model.dart';
import 'package:flowcare_mobile/models/patient_visit_model.dart';
import 'package:flowcare_mobile/models/route_optimization_model.dart';
import 'package:flowcare_mobile/services/route_optimization_service.dart';

import 'home_journey_provider_test.dart' show fakeHome, FakeEncounters;
import 'fixtures/journey_fixtures.dart';

class _VisitSummaryEncounters extends FakeEncounters {
  final requestedIds = <String>[];
  final downloadedIds = <String>[];
  Object? visitSummaryError;

  @override
  Future<DownloadedFile> downloadVisitAttachment(String attachmentId) async {
    downloadedIds.add(attachmentId);
    return (
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      contentType: 'application/pdf',
    );
  }

  @override
  Future<List<PatientVisitModel>?> getPatientHistory(String patientId) async =>
      [
        ...?await super.getPatientHistory(patientId),
        PatientVisitModel(
          encounterId: 'old-visit',
          serviceTypeName: 'Khoa Sản - Phụ Khoa',
          status: 'Completed',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];

  @override
  Future<VisitSummaryModel> getVisitSummary(String encounterId) async {
    requestedIds.add(encounterId);
    if (visitSummaryError != null) throw visitSummaryError!;
    return VisitSummaryModel.fromJson({
      'encounterId': encounterId,
      'diagnosis': 'Chẩn đoán đã lưu',
      'plan': 'Lời dặn đã lưu',
      'prescriptions': [
        {
          'medicationName': 'Thuốc kiểm thử',
          'quantity': 12,
          'dosage': 'Liều dùng đã lưu',
          'instructions': 'Hướng dẫn đã lưu',
        },
      ],
      'services': [
        {
          'serviceName': 'Tổng phân tích nước tiểu',
          'status': 'Completed',
          'result': 'Kết quả CLS đã chốt',
          'resultNotes': 'Ghi chú xét nghiệm đã lưu',
          'resultFinalizedAt': '2026-10-01T06:30:00Z',
          'attachments': [
            {'id': 'result-file', 'fileName': 'phieu-ket-qua.pdf'},
          ],
        },
      ],
    });
  }
}

class _NoFasterRoute extends RouteOptimizationService {
  int requests = 0;

  @override
  Future<RouteOptimizationEligibility> eligibility(
    String encounterId,
    String patientId,
  ) async => RouteOptimizationEligibility.fromJson({
    'canOptimize': false,
    'reason': 'NO_BETTER_ROUTE',
    'remainingOrders': 2,
    'activePlanId': 'plan-1',
  });

  @override
  Future<RouteOptimizationEligibility> requestOptimization(
    String encounterId,
    String patientId,
  ) {
    requests++;
    return eligibility(encounterId, patientId);
  }
}

void main() {
  for (final status in ['Active', 'Proposed']) {
    testWidgets(
      '$status route with two pending orders can request optimization before any offer exists',
      (tester) async {
        final session = PatientSessionService()
          ..bindPatient(patientId: 'patient', userName: 'patient.test');
        ApiClient.setAuthToken('test-token');
        addTearDown(session.clearSession);
        addTearDown(() => ApiClient.setAuthToken(null));
        final optimization = _NoFasterRoute();
        addTearDown(optimization.close);
        final plan = activeTimedPlanJson()
          ..['encounterId'] = 'patient'
          ..['status'] = status
          ..['isLocked'] = status == 'Proposed';
        final steps = (plan['steps'] as List).cast<Map<String, dynamic>>();
        steps[0]['medicalOrderId'] = 'order-xray';
        steps[1]['medicalOrderId'] = 'order-lab';
        final home = fakeHome(
          encounters: FakeEncounters()
            ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Done')
            ..plan = ParaclinicalPlanModel.fromJson(plan),
        );
        addTearDown(home.dispose);
        await home.loadHomeData();
        await tester.pumpWidget(
          ChangeNotifierProvider<HomeProvider>.value(
            value: home,
            child: MaterialApp(
              home: RouteScreen(optimizationService: optimization),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final notice = find.text(
          status == 'Proposed'
              ? 'Chưa có phương án tiết kiệm thời gian hơn. Phương án hiện tại vẫn đang chờ bác sĩ duyệt.'
              : 'Đã tính lại theo hàng đợi hiện tại. Chưa có phương án đáp ứng ràng buộc của bác sĩ và mức tiết kiệm yêu cầu. Bạn tiếp tục theo lộ trình hiện tại.',
        );
        final optimize = find.text('Tối ưu lộ trình');
        await tester.scrollUntilVisible(optimize.hitTestable(), 120);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: optimize,
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        expect(notice, findsNothing);
        expect(
          find.text(
            'Bấm Tối ưu lộ trình để kiểm tra phương án theo hàng đợi hiện tại.',
          ),
          findsOneWidget,
        );
        expect(optimization.requests, 0);
        await tester.tap(optimize);
        await tester.pumpAndSettle();
        expect(optimization.requests, 1);
        await tester.scrollUntilVisible(notice, 120);
        expect(notice, findsOneWidget);
        expect(find.text('Hỗ trợ tối ưu lộ trình'), findsNothing);
        expect(find.text('Chấp nhận đề xuất'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Finalized visit shows real services without stale queue or invented room on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PatientSessionService().bindPatient(
        patientId: 'patient',
        userName: 'patient.test',
      );
      final encounters = _VisitSummaryEncounters()
        ..plan = ParaclinicalPlanModel.fromJson(timedPlanJson());
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      addTearDown(() => PatientSessionService().clearSession());
      await home.loadHomeData();
      await tester.pumpWidget(
        ChangeNotifierProvider<HomeProvider>.value(
          value: home,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const RouteScreen(),
          ),
        ),
      );
      expect(find.text('Đã hoàn tất lượt khám'), findsWidgets);
      expect(encounters.requestedIds, isEmpty);
      expect(find.text('Đơn thuốc đã kê'), findsNothing);
      expect(find.textContaining('12/10/2026'), findsWidgets);
      expect(find.textContaining('Đang chờ gọi số'), findsNothing);
      expect(find.textContaining('Mai Hoa'), findsNothing);
      expect(find.textContaining('~5 phút'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Tổng di chuyển cận lâm sàng'),
        120,
      );
      expect(find.text('6 phút'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('4. Chụp X-Quang'), 150);
      expect(find.text('4. Chụp X-Quang'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Khoảng 3 phút').first, 100);
      expect(find.text('Di chuyển theo kế hoạch'), findsWidgets);
      expect(find.text('Khoảng 3 phút'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Chờ kết quả theo kế hoạch').first,
        100,
      );
      expect(find.text('15 phút'), findsWidgets);
      await tester.scrollUntilVisible(find.text('5. Xét nghiệm máu'), 150);
      expect(find.text('5. Xét nghiệm máu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'History opens the selected visit without switching the current route',
    (tester) async {
      final session = PatientSessionService()
        ..bindPatient(patientId: 'patient', userName: 'patient.test');
      addTearDown(session.clearSession);
      final encounters = _VisitSummaryEncounters()
        ..visitSummaryError = ApiException(
          'Chưa chốt',
          data: {
            'errors': ['VISIT_NOT_FINALIZED'],
          },
        );
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      await home.loadHomeData();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeProvider>.value(value: home),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final currentRoute = home.encounterSummary!.encounterId;
      await tester.tap(find.text('Khoa Sản - Phụ Khoa'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết lượt khám'), findsOneWidget);
      expect(
        find.text('Hồ sơ sẽ có sau khi bác sĩ hoàn tất lượt khám.'),
        findsOneWidget,
      );
      expect(encounters.requestedIds, ['old-visit']);
      expect(home.encounterSummary!.encounterId, currentRoute);
      encounters.visitSummaryError = null;
      await tester.tap(find.text('Thử tải lại hồ sơ'));
      await tester.pumpAndSettle();

      expect(encounters.requestedIds, ['old-visit', 'old-visit']);
      expect(find.text('Chẩn đoán đã lưu'), findsOneWidget);
      expect(find.text('Lời dặn đã lưu'), findsOneWidget);
      expect(find.text('Thuốc kiểm thử'), findsOneWidget);
      expect(find.text('Số lượng: 12'), findsOneWidget);
      expect(find.text('Liều dùng: Liều dùng đã lưu'), findsOneWidget);
      expect(find.text('Hướng dẫn sử dụng: Hướng dẫn đã lưu'), findsOneWidget);
      final results = find.text('Kết quả cận lâm sàng');
      expect(
        tester.getTopLeft(results).dy,
        greaterThan(tester.getTopLeft(find.text('Đơn thuốc đã kê')).dy),
      );
      const fileSaver = MethodChannel('flowcare/result_files');
      MethodCall? savedFile;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(fileSaver, (call) async {
        savedFile = call;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(fileSaver, null));

      final download = find.text('Tải tệp kết quả');
      await tester.scrollUntilVisible(
        download.hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kết quả CLS đã chốt'), findsNothing);
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(encounters.downloadedIds, ['result-file']);
      expect(savedFile?.method, 'save');
      expect(savedFile?.arguments['fileName'], 'phieu-ket-qua.pdf');
      expect(savedFile?.arguments['bytes'], [37, 80, 68, 70]);

      final showResult = find.text('Xem nội dung');
      await tester.ensureVisible(showResult);
      await tester.tap(showResult);
      await tester.pumpAndSettle();
      expect(find.text('Kết quả CLS đã chốt'), findsOneWidget);
      expect(find.text('Ghi chú: Ghi chú xét nghiệm đã lưu'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử lịch hẹn & Khám'), findsOneWidget);
      expect(find.text('Lịch hẹn trực tuyến'), findsOneWidget);
    },
  );
}
