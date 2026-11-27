import 'dart:convert';

import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/models/follow_up_order_model.dart';
import 'package:flowcare_mobile/providers/booking_provider.dart';
import 'package:flowcare_mobile/screens/booking/booking_screen.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/services/encounter_service.dart';
import 'package:flowcare_mobile/services/follow_up_service.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/service_type_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const serviceId = '11111111-1111-1111-1111-111111111111';
const orderId = '22222222-2222-2222-2222-222222222222';
const patientId = '33333333-3333-3333-3333-333333333333';
const encounterId = '44444444-4444-4444-4444-444444444444';
const doctorId = '55555555-5555-5555-5555-555555555555';
const imagingId = '66666666-6666-6666-6666-666666666666';

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
          case '/api/v1/patients/me/encounters/$encounterId/visit-summary':
            data = {'encounterId': encounterId, 'plan': 'Lời dặn đã lưu'};
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
              {
                'id': imagingId,
                'name': 'Siêu âm hình thái thai',
                'serviceType': 'Imaging',
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
    expect(await provider.loadFollowUpVisitAdvice(orderId), 'Lời dặn đã lưu');
    await expectLater(
      provider.loadFollowUpVisitAdvice('another-order'),
      throwsA(isA<SessionChangedException>()),
    );
    expect(provider.selectedSlot, isNull);
    await provider.retrySlots();
    provider.selectSlot(provider.availableSlots.single);
    expect(await provider.submitBooking(), isTrue);
    expect(booked.single['followUpOrderId'], orderId);
    expect(booked.single['doctorId'], doctorId);
    expect(provider.pendingFollowUpOrders, isEmpty);
  });

  testWidgets(
    'Follow-up shows appointment details and opens the saved care advice',
    (tester) async {
      final provider = booking(
        orders: [
          {
            ...order,
            'notes': 'Mang theo phiếu cận lâm sàng',
            'preExamServiceIds': [imagingId],
          },
        ],
        encounterStatus: 'Finalized',
        booked: [],
      );
      await provider.initBooking();
      expect(provider.setupFollowUpFromOrder(orderId), isTrue);
      await provider.retrySlots();
      await tester.pumpWidget(
        ChangeNotifierProvider<BookingProvider>.value(
          value: provider,
          child: const MaterialApp(home: BookingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ngày bác sĩ hẹn'), findsOneWidget);
      expect(find.text('Mang theo phiếu cận lâm sàng'), findsOneWidget);
      expect(find.text('Siêu âm hình thái thai'), findsOneWidget);
      expect(find.textContaining('Chẩn đoán trước'), findsNothing);
      final advice = find.text('Lời dặn về chăm sóc và ăn uống');
      await tester.ensureVisible(advice);
      await tester.tap(advice);
      await tester.pumpAndSettle();
      expect(find.text('Lời dặn đã lưu'), findsOneWidget);
    },
  );

  test(
    'FollowUpOrderModel extracts [Giờ hẹn: HH:mm] and preserves clean notes',
    () {
      final parsed = FollowUpOrderModel.fromJson({
        ...order,
        'notes': '[Giờ hẹn: 8:30]\nNhịn ăn sáng trước siêu âm',
        'targetDate': '2026-11-19',
      });
      expect(parsed.targetTime, '08:30');
      expect(parsed.notes, 'Nhịn ăn sáng trước siêu âm');
      expect(
        parsed.scheduledHospitalUtcTime().toIso8601String(),
        '2026-11-19T01:30:00.000Z',
      );
    },
  );

  test(
    'FollowUpOrderModel parses BE TimeOnly targetTime (HH:mm:ss) and targetAt',
    () {
      final withTargetTime = FollowUpOrderModel.fromJson({
        ...order,
        'targetDate': '2026-12-02',
        'targetTime': '14:30:00',
        'targetAt': '2026-12-02T14:30:00+07:00',
        'notes': 'Uống nhiều nước trước khi siêu âm',
      });
      expect(withTargetTime.targetTime, '14:30');
      expect(withTargetTime.targetAt, isNotNull);
      expect(withTargetTime.notes, 'Uống nhiều nước trước khi siêu âm');
      expect(
        withTargetTime.scheduledHospitalUtcTime().toIso8601String(),
        '2026-12-02T07:30:00.000Z',
      );

      final fromTargetAtOnly = FollowUpOrderModel.fromJson({
        ...order,
        'targetDate': '2026-12-02',
        'targetTime': null,
        'targetAt': '2026-12-02T07:30:00Z',
      });
      expect(fromTargetAtOnly.targetTime, '14:30');
      expect(
        fromTargetAtOnly.scheduledHospitalUtcTime().toIso8601String(),
        '2026-12-02T07:30:00.000Z',
      );
    },
  );

  testWidgets(
    'Narrow 360dp phone shows no overflow on booking switcher and follow-up mode reviews without date/slot pickers',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final booked = <Map<String, dynamic>>[];
      final target = BookingProvider.defaultBookingDate;
      final dateParam =
          '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
      final provider = booking(
        orders: [
          {
            ...order,
            'targetDate': dateParam,
            'notes': '[Giờ hẹn: 09:30]\nMang theo phiếu cận lâm sàng',
            'preExamServiceIds': [imagingId],
          },
        ],
        encounterStatus: 'Finalized',
        booked: booked,
      );
      await provider.initBooking();

      await tester.pumpWidget(
        ChangeNotifierProvider<BookingProvider>.value(
          value: provider,
          child: const MaterialApp(home: BookingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Mode switcher in new-booking mode must not overflow at 360dp width
      expect(tester.takeException(), isNull);
      expect(find.text('Đặt lịch khám trực tuyến'), findsOneWidget);
      expect(find.text('Khám thai'), findsWidgets);
      expect(find.text('Khám phụ khoa'), findsOneWidget);
      expect(find.text('Sản - Phụ khoa khác'), findsNothing);

      provider.setSelectedCategory('other');
      expect(provider.selectedCategory, 'prenatal');
      provider.setSelectedCategory('gynecology');
      expect(provider.selectedCategory, 'gynecology');
      provider.setSelectedCategory('prenatal');
      expect(provider.selectedCategory, 'prenatal');
      await tester.pumpAndSettle();

      // Tap "Tái khám theo hẹn" -> enters follow-up review screen (NOT time-slot wizard)
      await tester.tap(find.text('Tái khám theo hẹn'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Đặt lịch khám trực tuyến'), findsNothing);
      expect(find.text('Tái khám theo hẹn'), findsWidgets);
      expect(find.text('Chọn khung giờ khám'), findsNothing);
      expect(find.text('Thời gian'), findsNothing);
      expect(find.textContaining('Ngày bác sĩ hẹn: 09:30'), findsOneWidget);
      expect(find.text('Siêu âm hình thái thai'), findsOneWidget);
      expect(find.text('Mang theo phiếu cận lâm sàng'), findsOneWidget);
      expect(find.text('Xác nhận lịch tái khám'), findsOneWidget);

      // 1-tap follow-up confirmation works without picking any time slot
      expect(provider.selectedSlot, isNull);
      expect(provider.canSubmit, isTrue);
      expect(await provider.submitBooking(), isTrue);
      final expectedUtc = DateTime.utc(
        target.year,
        target.month,
        target.day,
        9,
        30,
      ).subtract(const Duration(hours: 7)).toIso8601String();
      expect(booked.single['scheduledTime'], expectedUtc);
      expect(booked.single['followUpOrderId'], orderId);

      await tester.pumpAndSettle();
      expect(find.text('Xác nhận lịch tái khám thành công!'), findsOneWidget);
    },
  );
}
