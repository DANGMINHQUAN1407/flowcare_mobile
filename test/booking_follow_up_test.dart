import 'dart:convert';

import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/providers/booking_provider.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/services/encounter_service.dart';
import 'package:flowcare_mobile/services/follow_up_service.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/service_type_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const serviceId = '11111111-1111-1111-1111-111111111111';
const orderId = '22222222-2222-2222-2222-222222222222';
const patientId = '33333333-3333-3333-3333-333333333333';
const encounterId = '44444444-4444-4444-4444-444444444444';
const doctorId = '55555555-5555-5555-5555-555555555555';

void main() {
  final session = PatientSessionService();
  setUp(() {
    session.bindPatient(patientId: patientId, userName: '0901234567');
    ApiClient.setAuthToken('patient-token');
  });
  tearDown(() {
    session.clearSession();
    ApiClient.setAuthToken(null);
  });

  BookingProvider booking({
    required List<Map<String, Object>> orders,
    required String encounterStatus,
    required List<Map<String, dynamic>> booked,
  }) {
    final start = BookingProvider.defaultBookingDate.add(
      const Duration(hours: 9),
    );
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        final path = request.url.path;
        final Object data;
        switch (path) {
          case '/api/v1/patients/me':
            data = {
              'id': patientId,
              'fullName': 'Bệnh nhân mẫu',
              'phone': '0901234567',
            };
          case '/api/v1/follow-up-orders/patient/$patientId':
            data = orders;
          case '/api/v1/patients/me/encounters':
            data = [
              {'encounterId': encounterId, 'encounterStatus': encounterStatus},
            ];
          case '/api/v1/services':
            data = [
              {
                'id': '00000000-0000-0000-0000-000000000000',
                'name': 'Không hợp lệ',
              },
              {
                'id': serviceId,
                'name': 'Khám thai',
                'serviceType': 'Consultation',
              },
            ];
          case '/api/v1/appointments/slots':
            expect(request.url.queryParameters['serviceId'], serviceId);
            data = [
              {
                'timeRange': '09:00 - 10:00',
                'startTime': start.toIso8601String(),
                'endTime': start
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
                'isAvailable': true,
              },
            ];
          case '/api/v1/appointments':
            booked.add(jsonDecode(request.body) as Map<String, dynamic>);
            data = {
              'id': 'appointment',
              'status': 'Confirmed',
              'scheduledTime': start.toIso8601String(),
            };
          default:
            throw StateError('Unexpected request: $path');
        }
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final provider = BookingProvider(
      appointmentService: AppointmentService(apiClient: client),
      patientService: PatientService(apiClient: client),
      serviceTypeService: ServiceTypeService(apiClient: client),
      followUpService: FollowUpService(apiClient: client),
      encounterService: EncounterService(apiClient: client),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  final order = <String, Object>{
    'id': orderId,
    'patientId': patientId,
    'encounterId': encounterId,
    'originalDoctorId': doctorId,
    'targetDate': BookingProvider.defaultBookingDate.toIso8601String(),
    'isBooked': false,
  };

  test('new patient can book normally and cannot enter follow-up', () async {
    final booked = <Map<String, dynamic>>[];
    final provider = booking(orders: [], encounterStatus: '', booked: booked);
    await provider.initBooking();

    expect(provider.errorMessage, isNull);
    expect(provider.slotsErrorMessage, isNull);
    expect(provider.pendingFollowUpOrders, isEmpty);
    expect(provider.setupFollowUpFromOrder(orderId), isFalse);
    expect(provider.isFollowUp, isFalse);
    provider.selectSlot(provider.availableSlots.single);
    expect(await provider.submitBooking(), isTrue);
    expect(booked.single['serviceId'], serviceId);
    expect(booked.single.containsKey('followUpOrderId'), isFalse);
  });

  test(
    'excludes orders from an active visit, another patient or a used order',
    () async {
      final active = booking(
        orders: [order],
        encounterStatus: 'InQueue',
        booked: [],
      );
      await active.initBooking();
      expect(active.pendingFollowUpOrders, isEmpty);
      expect(await active.openFollowUp(orderId), isFalse);

      final completed = booking(
        orders: [
          {...order, 'patientId': 'different patient'},
          {...order, 'isBooked': true},
        ],
        encounterStatus: 'Completed',
        booked: [],
      );
      await completed.initBooking();
      expect(completed.pendingFollowUpOrders, isEmpty);
    },
  );

  test('only the doctor order from a completed visit can be booked', () async {
    final booked = <Map<String, dynamic>>[];
    final provider = booking(
      orders: [order],
      encounterStatus: 'Finalized',
      booked: booked,
    );
    await provider.initBooking();
    expect(provider.errorMessage, isNull);
    expect(provider.followUpError, isNull);
    expect(provider.pendingFollowUpOrders.single.id, orderId);
    expect(provider.setupFollowUpFromOrder('unknown order'), isFalse);

    provider.selectSlot(provider.availableSlots.single);
    expect(provider.setupFollowUpFromOrder(orderId), isTrue);
    expect(provider.selectedSlot, isNull);
    await provider.retrySlots();
    provider.selectSlot(provider.availableSlots.single);
    expect(await provider.submitBooking(), isTrue);
    expect(booked.single['followUpOrderId'], orderId);
    expect(booked.single['doctorId'], doctorId);
    expect(provider.pendingFollowUpOrders, isEmpty);
  });
}
