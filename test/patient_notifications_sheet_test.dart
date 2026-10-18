import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/main.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/providers/auth_provider.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/screens/auth/login_screen.dart';
import 'package:flowcare_mobile/screens/route/route_screen.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

import 'fixtures/journey_fixtures.dart';
import 'home_journey_provider_test.dart' show fakeHome, FakeEncounters;
import 'patient_auth_test.dart' show FakePatientAuth;

void main() {
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    );
    ApiClient.setAuthToken(null);
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
  });

  Future<({HomeProvider home, FakeEncounters encounters})> showRoute(
    WidgetTester tester, {
    bool called = false,
    double textScale = 1,
  }) async {
    final encounters = FakeEncounters()
      ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Waiting')
      ..plan = null;
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();
    if (called) {
      encounters.summary = summaryFixture(
        status: 'InQueue',
        queueStatus: 'Called',
      );
      await home.refreshJourney();
      expect(home.unreadNoticeCount, greaterThan(0));
    }
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // Match production: the Navigator is ABOVE this patient-scoped provider.
        home: ChangeNotifierProvider<HomeProvider>.value(
          value: home,
          child: const RouteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (home: home, encounters: encounters);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Thông báo lượt khám'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Thông báo lượt khám'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'notifications open from a provider below the navigator without ProviderNotFound',
    (tester) async {
      await showRoute(tester);
      await openSheet(tester);
      expect(find.textContaining('Chưa có thông báo mới'), findsOneWidget);
    },
  );

  testWidgets(
    'the sheet marks notices read and listens to the current patient instance',
    (tester) async {
      final fixture = await showRoute(tester, called: true);
      final calledMessage = fixture.home.notices.first.message;
      await openSheet(tester);
      expect(find.text(calledMessage), findsOneWidget);
      expect(fixture.home.unreadNoticeCount, 0);

      fixture.encounters.summary = summaryFixture(
        status: 'InQueue',
        queueStatus: 'InProgress',
      );
      await fixture.home.refreshJourney();
      await tester.pumpAndSettle();
      expect(find.text(fixture.home.notices.first.message), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing and reopening a sheet never disposes its shared HomeProvider',
    (tester) async {
      final fixture = await showRoute(tester, called: true);
      await openSheet(tester);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      var changes = 0;
      void listener() => changes++;
      fixture.home.addListener(listener);
      fixture.home.markNoticesRead();
      fixture.home.removeListener(listener);
      expect(changes, greaterThan(0));
      await openSheet(tester);
      expect(find.text(fixture.home.notices.first.message), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notification content fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showRoute(tester, called: true, textScale: 1.5);
    await openSheet(tester);
    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logout removes the notification sheet with the old patient providers',
    (tester) async {
      PatientSessionService().clearSession();
      await tester.pumpWidget(FlowCareApp(authService: FakePatientAuth()));
      final auth = tester
          .element(find.byType(LoginScreen))
          .read<AuthProvider>();
      await auth.login('patient.test', 'test-only');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Thông báo lượt khám'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
