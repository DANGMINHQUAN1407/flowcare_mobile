import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

import 'fixtures/journey_fixtures.dart';
import 'home_journey_provider_test.dart' show FakeEncounters, fakeHome;

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_NURSING_JOURNEY')) return;
    final textFont = FontLoader('Roboto')
      ..addFont(
        File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          'C:/Users/dangm/Downloads/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await Future.wait([textFont.load(), icons.load()]);
  });
  setUp(
    () => PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    ),
  );
  tearDown(() => PatientSessionService().clearSession());

  Future<({HomeProvider home, FakeEncounters encounters})> showRoute(
    WidgetTester tester, {
    NursingIntakeProgressModel? nursing,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final encounters = FakeEncounters()
      ..summary = summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingComplete: false,
        nursingIntake: nursing,
      )
      ..plan = null;
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('nursing-route-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: ChangeNotifierProvider<HomeProvider>.value(
            value: home,
            child: const RouteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (home: home, encounters: encounters);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_NURSING_JOURNEY')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('nursing-route-capture')),
      );
      final snapshot = await boundary.toImage(pixelRatio: 1.5);
      final png = await snapshot.toByteData(format: ui.ImageByteFormat.png);
      await File('D:/DoAn/artifacts/$name.png')
          .writeAsBytes(png!.buffer.asUint8List());
      snapshot.dispose();
    });
  }

  testWidgets('Called patient sees nursing guidance and both missing records', (
    tester,
  ) async {
    await showRoute(tester, nursing: const NursingIntakeProgressModel());
    expect(find.text('Đã gọi — mời đến điều dưỡng'), findsWidgets);
    expect(
      find.byKey(const ValueKey('journey-nursing-guidance')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Khai báo sản phụ khoa: Chưa ghi nhận'),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('next-stop-travel')), findsNothing);
    await capture(tester, 'MOBILE_NURSING_CURRENT_2026-10-18');
    expect(find.text('1/4 bước đã xử lý'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2. Điều dưỡng tiếp nhận & đo sinh hiệu'),
      180,
    );
    await tester.scrollUntilVisible(find.text('3. Khám bác sĩ'), 150);
    expect(find.text('3. Khám bác sĩ'), findsOneWidget);
    expect(find.text('Sau tiếp nhận điều dưỡng'), findsOneWidget);
    await tester.ensureVisible(
      find.text('2. Điều dưỡng tiếp nhận & đo sinh hiệu'),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'MOBILE_NURSING_TIMELINE_2026-10-18');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Nursing saves update the same screen and hand over to consultation',
    (tester) async {
      final fixture = await showRoute(
        tester,
        nursing: const NursingIntakeProgressModel(),
      );
      final savedAt = DateTime.parse('2026-10-18T14:15:00+07:00');
      fixture.encounters.summary = summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingIntake: NursingIntakeProgressModel(intakeSavedAt: savedAt),
      );
      await fixture.home.refreshJourney();
      await tester.pumpAndSettle();
      expect(find.text('Đang tiếp nhận điều dưỡng'), findsWidgets);
      expect(find.textContaining('Sinh hiệu: Chưa ghi nhận'), findsWidgets);

      fixture.encounters.summary = summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
        nursingIntake: NursingIntakeProgressModel(
          intakeSavedAt: savedAt,
          vitalSignsRecordedAt: savedAt.add(const Duration(minutes: 2)),
        ),
      );
      await fixture.home.refreshJourney();
      await tester.pumpAndSettle();
      expect(fixture.home.journey?.currentStep?.id, 'consultation');
      expect(find.text('Đã gọi — mời vào phòng'), findsWidgets);
      expect(
        fixture.home.notices.any(
          (n) => n.message.contains('Đã ghi nhận đủ thông tin'),
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('journey-nursing-guidance')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('2. Điều dưỡng tiếp nhận & đo sinh hiệu'),
        180,
      );
      expect(find.text('2/4 bước đã xử lý'), findsOneWidget);
      expect(find.text('Đã ghi nhận đủ thông tin'), findsOneWidget);
      await capture(tester, 'MOBILE_NURSING_DONE_2026-10-18');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Two approved orders appear after nursing and doctor, with real rooms',
    (tester) async {
      final fixture = await showRoute(
        tester,
        nursing: NursingIntakeProgressModel(
          intakeSavedAt: DateTime.parse('2026-10-18T14:15:00+07:00'),
          vitalSignsRecordedAt: DateTime.parse('2026-10-18T14:17:00+07:00'),
        ),
      );
      fixture.encounters.plan = ParaclinicalPlanModel.fromJson(
        activeTimedPlanJson(),
      );
      await fixture.home.refreshJourney();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('4. Chụp X-Quang'), 180);
      expect(find.text('3/6 bước đã xử lý'), findsOneWidget);
      expect(find.text('Phòng X-Quang thực tế'), findsWidgets);
      await tester.scrollUntilVisible(find.text('5. Xét nghiệm máu'), 180);
      expect(find.text('Phòng xét nghiệm thực tế'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Nursing guidance handles large text on a narrow phone', (
    tester,
  ) async {
    await showRoute(
      tester,
      nursing: const NursingIntakeProgressModel(),
      textScale: 1.6,
    );
    tester.view.physicalSize = const Size(320, 740);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2. Điều dưỡng tiếp nhận & đo sinh hiệu'),
      180,
    );
    expect(tester.takeException(), isNull);
  });
}
