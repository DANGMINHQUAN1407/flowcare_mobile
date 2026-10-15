import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';

import 'home_journey_provider_test.dart' show fakeHome, FakeEncounters;
import 'fixtures/journey_fixtures.dart';

void main() {
  testWidgets(
    'Finalized visit shows real services without stale queue or invented room on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PatientSessionService().setPhone('patient');
      final home = fakeHome(
        encounters: FakeEncounters()
          ..plan = ParaclinicalPlanModel.fromJson(timedPlanJson()),
      );
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
      expect(find.textContaining('12/10/2026'), findsWidgets);
      expect(find.textContaining('Đang chờ gọi số'), findsNothing);
      expect(find.textContaining('Mai Hoa'), findsNothing);
      expect(find.textContaining('~5 phút'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Tổng di chuyển cận lâm sàng'),
        120,
      );
      expect(find.text('6 phút'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('3. Chụp X-Quang'), 150);
      expect(find.text('3. Chụp X-Quang'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Khoảng 3 phút').first, 100);
      expect(find.text('Di chuyển dự kiến'), findsWidgets);
      expect(find.text('Khoảng 3 phút'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Chờ kết quả dự kiến').first,
        100,
      );
      expect(find.text('15 phút'), findsWidgets);
      await tester.scrollUntilVisible(find.text('4. Xét nghiệm máu'), 150);
      expect(find.text('4. Xét nghiệm máu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
