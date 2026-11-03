import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/providers/booking_provider.dart';
import 'package:flowcare_mobile/providers/history_provider.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/widgets/appointment_cancel_button.dart';

class CancellationHome extends HomeProvider {
  CancellationHome() : super(loadOnCreate: false);
  int refreshes = 0;
  @override
  Future<void> loadHomeData({bool isRefresh = false}) async {
    refreshes++;
  }
}

class CancellationBooking extends BookingProvider {
  int refreshes = 0;
  @override
  void resetBooking() {}
  @override
  Future<void> initBooking([String? defaultPhone]) async {
    refreshes++;
  }
}

void main() {
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: '0901234567',
    );
    ApiClient.setAuthToken('patient-token');
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
  });
  testWidgets(
    'cancel requires explicit confirmation then refreshes history, home and booking state',
    (tester) async {
      var writes = 0;
      final history = HistoryProvider(
        appointmentService: AppointmentService(
          apiClient: ApiClient(
            baseUrl: 'http://test/api/v1',
            client: MockClient((request) async {
              final data = {
                'id': 'appointment',
                'patientId': 'patient',
                'patientName': 'Bệnh nhân thử',
                'serviceTypeName': 'Khám',
                'scheduledTime': '2026-11-10T07:30:00+07:00',
                'status': request.method == 'POST' ? 'Cancelled' : 'Confirmed',
              };
              if (request.method == 'POST') {
                writes++;
                expect(
                  request.url.path,
                  '/api/v1/appointments/appointment/cancel',
                );
                expect(jsonDecode(request.body), {'reason': 'Bận việc'});
              }
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': request.method == 'POST' ? data : [data],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        ),
      );
      final home = CancellationHome(), booking = CancellationBooking();
      addTearDown(history.dispose);
      addTearDown(home.dispose);
      addTearDown(booking.dispose);
      await history.loadAppointments('patient');
      expect(history.errorMessage, isNull);
      expect(history.appointments, hasLength(1));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: history),
            ChangeNotifierProvider<HomeProvider>.value(value: home),
            ChangeNotifierProvider<BookingProvider>.value(value: booking),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<HistoryProvider>(
                builder: (_, provider, _) => AppointmentCancelButton(
                  appointment: provider.appointments.single,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hủy lịch hẹn'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.enterText(find.byType(TextField), 'Bận việc');
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(history.appointments.single.status, 'Cancelled');
      expect(home.refreshes, 1);
      expect(booking.refreshes, 1);
      expect(find.text('Hủy lịch hẹn'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
