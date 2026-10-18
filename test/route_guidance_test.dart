import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/core/utils/hospital_time.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

import 'fixtures/journey_fixtures.dart';
import 'home_journey_provider_test.dart' show fakeHome, FakeEncounters;

FakeEncounters activeEncounters() => FakeEncounters()
  ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Done')
  ..plan = ParaclinicalPlanModel.fromJson(activeTimedPlanJson());

Future<HomeProvider> showRoute(
  WidgetTester tester,
  FakeEncounters encounters, {
  double textScale = 1,
}) async {
  final home = fakeHome(encounters: encounters);
  addTearDown(home.dispose);
  await home.loadHomeData();
  await tester.pumpWidget(
    ChangeNotifierProvider<HomeProvider>.value(
      value: home,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const RouteScreen(),
      ),
    ),
  );
  return home;
}

void main() {
  testWidgets(
    'OriginalOrder from the API explains that assistance has not optimized the route yet',
    (tester) async {
      PatientSessionService().bindPatient(
        patientId: 'patient',
        userName: 'patient.test',
      );
      final original = activeTimedPlanJson()..['mode'] = 'OriginalOrder';
      await showRoute(
        tester,
        activeEncounters()..plan = ParaclinicalPlanModel.fromJson(original),
      );
      expect(
        find.textContaining('Lộ trình ban đầu theo thứ tự chỉ định.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  setUp(
    () => PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    ),
  );
  tearDown(() => PatientSessionService().clearSession());

  testWidgets(
    'Active route prominently pairs the assigned room, travel and queue wait',
    (tester) async {
      final home = await showRoute(tester, activeEncounters());
      final nextStop = find.byKey(const ValueKey('journey-next-stop'));
      expect(
        find.descendant(of: nextStop, matching: find.text('Phòng cần đến')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: nextStop,
          matching: find.text('Phòng X-Quang thực tế'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('next-stop-travel')),
          matching: find.text('3 phút'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('next-stop-wait')),
          matching: find.text('5 phút'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Cập nhật lúc ${hospitalTime(home.lastUpdatedAt!, pattern: 'dd/MM HH:mm:ss')}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Guidance fits a narrow screen with large text and long room names',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = activeTimedPlanJson();
      (json['steps'] as List)[0]['assignedRoomName'] =
          'Phòng Chẩn đoán hình ảnh Sản Phụ khoa số 104';
      (json['steps'] as List)[0]['assignedRoomBuilding'] =
          'Khu khám chuyên sâu';
      (json['steps'] as List)[0]['assignedRoomFloor'] = '2';
      await showRoute(
        tester,
        activeEncounters()..plan = ParaclinicalPlanModel.fromJson(json),
        textScale: 1.5,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('next-stop-wait')),
        160,
      );
      expect(find.text('5 phút'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Refresh failure keeps the room and timestamp but clearly marks cached guidance',
    (tester) async {
      final encounters = activeEncounters();
      final home = await showRoute(tester, encounters);
      final timestamp = hospitalTime(
        home.lastUpdatedAt!,
        pattern: 'dd/MM HH:mm:ss',
      );
      encounters.summaryError = NetworkException();
      await tester.tap(find.byTooltip('Cập nhật lộ trình'));
      await tester.pumpAndSettle();
      expect(find.text('Mất kết nối máy chủ'), findsOneWidget);
      expect(
        find.text('Đang hiển thị dữ liệu cập nhật lúc $timestamp'),
        findsOneWidget,
      );
      expect(find.text('Phòng theo lần cập nhật trước'), findsOneWidget);
      expect(find.text('Phòng cần đến'), findsNothing);
      expect(
        find.textContaining('Hãy cập nhật lại hoặc hỏi nhân viên'),
        findsOneWidget,
      );
      encounters.summaryError = null;
      await tester.tap(find.byTooltip('Cập nhật lộ trình'));
      await tester.pumpAndSettle();
      expect(find.text('Mất kết nối máy chủ'), findsNothing);
      expect(find.text('Phòng cần đến'), findsOneWidget);
    },
  );

  testWidgets(
    'Missing estimates stay unknown rather than becoming zero-minute promises',
    (tester) async {
      await showRoute(
        tester,
        activeEncounters()
          ..plan = planFixture(
            status: 'Active',
            steps: [serviceFixture(status: 'InQueue')],
          ),
      );
      final nextStop = find.byKey(const ValueKey('journey-next-stop'));
      expect(
        find.descendant(of: nextStop, matching: find.text('Chưa có ước tính')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: nextStop, matching: find.text('0 phút')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'A first partial load cannot invent a destination from an incomplete summary',
    (tester) async {
      await showRoute(
        tester,
        activeEncounters()..planError = NetworkException(),
      );
      expect(find.text('Chưa có lần cập nhật đầy đủ.'), findsOneWidget);
      expect(
        find.textContaining('Chưa đủ dữ liệu để hướng dẫn di chuyển'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('journey-next-stop')), findsNothing);
    },
  );

  testWidgets('Unapproved routes never direct a patient to a room', (
    tester,
  ) async {
    final json = activeTimedPlanJson()..['status'] = 'Proposed';
    await showRoute(
      tester,
      activeEncounters()..plan = ParaclinicalPlanModel.fromJson(json),
    );
    expect(
      find.textContaining('Hãy chờ hướng dẫn trước khi di chuyển'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('journey-next-stop')), findsNothing);
    expect(find.byKey(const ValueKey('next-stop-travel')), findsNothing);
  });

  testWidgets(
    'Waiting only for results gives no travel instruction or invented queue wait',
    (tester) async {
      await showRoute(
        tester,
        activeEncounters()
          ..plan = planFixture(
            status: 'Active',
            steps: [serviceFixture(status: 'WaitingResult')],
          ),
      );
      expect(find.text('Chưa có phòng tiếp theo để di chuyển'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-stop-travel')), findsNothing);
      expect(find.byKey(const ValueKey('next-stop-wait')), findsNothing);
    },
  );

  testWidgets(
    'An ongoing service shows its current room without asking the patient to walk again',
    (tester) async {
      final json = activeTimedPlanJson();
      (json['steps'] as List)[0]['status'] = 'InProgress';
      await showRoute(
        tester,
        activeEncounters()..plan = ParaclinicalPlanModel.fromJson(json),
      );
      expect(find.text('Phòng đang thực hiện'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-stop-travel')), findsNothing);
      expect(find.byKey(const ValueKey('next-stop-wait')), findsNothing);
    },
  );

  testWidgets(
    'Finalized history uses historical estimate labels and has no next-room card',
    (tester) async {
      await showRoute(
        tester,
        FakeEncounters()
          ..plan = ParaclinicalPlanModel.fromJson(timedPlanJson()),
      );
      expect(find.text('Đã hoàn tất lượt khám'), findsOneWidget);
      expect(find.byKey(const ValueKey('journey-next-stop')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Ước tính của lộ trình đã thực hiện'),
        120,
      );
      expect(
        find.textContaining('không phải thời gian thực tế'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Hoàn tất cận lâm sàng dự kiến:'),
        findsNothing,
      );
    },
  );
}
