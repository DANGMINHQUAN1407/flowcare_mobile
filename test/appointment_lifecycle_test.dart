import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/core/utils/hospital_time.dart';
import 'package:flowcare_mobile/models/appointment_model.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/providers/history_provider.dart';

http.Response response(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
AppointmentService service(
  Future<http.Response> Function(http.Request) handle,
) => AppointmentService(
  apiClient: ApiClient(
    baseUrl: 'http://test/api/v1',
    client: MockClient(handle),
  ),
);

void main() {
  setUp(() => ApiClient.setAuthToken('patient-token'));
  tearDown(() {
    ApiClient.setAuthToken(null);
    ApiClient.onPasswordChangeRequired = null;
  });
  test('booking sends the selected instant as UTC without client-assigned status or source', () async {
    final instant = DateTime.parse('2026-11-10T07:30:00+07:00');
    await service((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(request.url.path, '/api/v1/appointments');
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('source'), isFalse);
      expect(DateTime.parse(body['scheduledTime']), instant);
      return response({
        'id': 'appointment',
        'status': 'Confirmed',
        'scheduledTime': body['scheduledTime'],
      });
    }).createAppointment(
      patientId: 'patient',
      serviceTypeId: 'service',
      scheduledTime: instant,
    );
  });
  test('cancellation posts once and accepts only the exact persisted Cancelled appointment', () async {
    var calls = 0;
    final saved = await service((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/appointments/appointment/cancel');
      expect(jsonDecode(request.body), {'reason': 'Bận việc'});
      return response({'id': 'appointment', 'status': 'Cancelled'});
    }).cancelAppointment('appointment', reason: ' Bận việc ');
    expect(calls, 1);
    expect(saved.canCancel, isFalse);
    await expectLater(
      service((_) async => response({'id': 'other', 'status': 'Cancelled'}))
          .cancelAppointment('appointment'),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'business errors keep codes and network loss never retries cancellation',
    () async {
      for (final entry in {
        403: 'PASSWORD_CHANGE_REQUIRED',
        409: 'APPOINTMENT_NOT_CANCELLABLE',
        422: 'SCHEDULE_MISMATCH',
        400: 'INVALID_REQUEST',
      }.entries) {
        await expectLater(
          service(
            (_) async => http.Response(
              jsonEncode({
                'errors': [entry.value],
              }),
              entry.key,
            ),
          ).cancelAppointment('appointment'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.codes,
              'codes',
              contains(entry.value),
            ),
          ),
        );
      }
      var calls = 0;
      await expectLater(
        service((_) async {
          calls++;
          throw http.ClientException('offline');
        }).cancelAppointment('appointment'),
        throwsA(isA<NetworkException>()),
      );
      expect(calls, 1);
    },
  );
  test('only pending/confirmed appointments can be cancelled and offset timestamps display in Vietnam', () {
    for (final status in ['Pending', 'Confirmed', 'Used', 'Cancelled']) {
      expect(
        AppointmentModel.fromJson({'id': 'a', 'status': status}).canCancel,
        ['Pending', 'Confirmed'].contains(status),
      );
    }
    final scheduled = DateTime.parse('2026-10-28T07:30:00+07:00');
    expect(
      hospitalTime(scheduled, pattern: 'HH:mm dd/MM/yyyy'),
      '07:30 28/10/2026',
    );
    expect(
      hospitalTime(
        DateTime.parse('2026-10-27T23:30:00Z'),
        pattern: 'HH:mm dd/MM/yyyy',
      ),
      '06:30 28/10/2026',
    );
  });

  test('a pending history read cannot restore a booking after cancellation was confirmed', () async {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: '0901234567',
    );
    addTearDown(() => PatientSessionService().clearSession());
    final pending = Completer<http.Response>();
    var reads = 0;
    const confirmed = {
      'id': 'appointment',
      'patientId': 'patient',
      'status': 'Confirmed',
    };
    final history = HistoryProvider(
      appointmentService: service((request) async {
        if (request.method == 'POST') {
          return response({...confirmed, 'status': 'Cancelled'});
        }
        reads++;
        if (reads == 2) return pending.future;
        return response([confirmed]);
      }),
    );
    addTearDown(history.dispose);
    await history.loadAppointments('patient');
    final stale = history.loadAppointments('patient', isRefresh: true);
    await pumpEventQueue();
    expect(await history.cancelAppointment('appointment'), isTrue);
    pending.complete(response([confirmed]));
    await stale;
    expect(history.appointments.single.status, 'Cancelled');
    expect(history.isRefreshing, isFalse);
  });
}
