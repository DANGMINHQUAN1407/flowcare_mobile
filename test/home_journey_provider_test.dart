import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/appointment_model.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/follow_up_order_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/models/patient_model.dart';
import 'package:flowcare_mobile/models/patient_visit_model.dart';
import 'package:flowcare_mobile/models/queue_ticket_model.dart';
import 'package:flowcare_mobile/providers/home_provider.dart';
import 'package:flowcare_mobile/services/appointment_service.dart';
import 'package:flowcare_mobile/services/encounter_service.dart';
import 'package:flowcare_mobile/services/follow_up_service.dart';
import 'package:flowcare_mobile/services/patient_realtime_service.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/queue_service.dart';

import 'fixtures/journey_fixtures.dart';

class FakePatients extends PatientService {
  Completer<PatientModel?>? oldResponse;
  @override
  Future<PatientModel?> searchPatientByPhone(String phone) async {
    if (phone == 'old' && oldResponse != null) return oldResponse!.future;
    return PatientModel(id: phone, fullName: 'Bệnh nhân $phone', phone: phone);
  }
}

class FakeAppointments extends AppointmentService {
  @override
  Future<AppointmentCheckModel> checkAppointmentByPhone(String phone) async =>
      const AppointmentCheckModel(hasAppointment: false);
}

class FakeFollowUps extends FollowUpService {
  @override
  Future<List<FollowUpOrderModel>> getFollowUpOrdersByPatient(
    String patientId,
  ) async => [];
}

class FakeQueue extends QueueService {
  @override
  Future<QueueTicketModel?> getQueueTicketByEncounter(
    String encounterId,
  ) async => null;
}

class FakeEncounters extends EncounterService {
  EncounterSummaryModel summary = summaryFixture();
  ParaclinicalPlanModel? plan = planFixture();
  bool failPlan = false;
  @override
  Future<List<PatientVisitModel>?> getPatientHistory(String patientId) async =>
      [
        PatientVisitModel(
          encounterId: patientId,
          serviceTypeName: 'Khám kiểm thử',
          status: summary.encounterStatus,
          createdAt: DateTime.parse('2026-10-12T00:00:00Z'),
        ),
      ];
  @override
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(
    String patientId,
  ) async => null;
  @override
  Future<EncounterSummaryModel?> getEncounterStatusSummary(
    String encounterId,
  ) async => summaryFixture(
    status: summary.encounterStatus,
    queueStatus: summary.queueStatus ?? 'Waiting',
    encounterId: encounterId,
    phone: encounterId,
  );
  @override
  Future<ParaclinicalPlanModel?> getParaclinicalPlan(String encounterId) async {
    if (failPlan) throw StateError('Offline');
    return plan;
  }
}

class FakeRealtime extends PatientRealtimeService {
  PatientEventCallback? callback;
  @override
  Future<void> connect({
    required String encounterId,
    required PatientEventCallback onEvent,
    required void Function(bool) onConnectionChanged,
  }) async {
    callback = onEvent;
    onConnectionChanged(true);
  }

  @override
  Future<void> disconnect() async {
    callback = null;
  }
}

HomeProvider fakeHome({
  FakePatients? patients,
  FakeEncounters? encounters,
  FakeRealtime? realtime,
}) => HomeProvider(
  patientService: patients ?? FakePatients(),
  appointmentService: FakeAppointments(),
  encounterService: encounters ?? FakeEncounters(),
  queueService: FakeQueue(),
  followUpService: FakeFollowUps(),
  realtimeService: realtime ?? FakeRealtime(),
  loadOnCreate: false,
);

void main() {
  setUp(() => PatientSessionService().setPhone('patient'));
  tearDown(() => PatientSessionService().clearSession());

  test(
    'A finalized history visit remains selectable when active lookup is empty',
    () async {
      final home = fakeHome();
      addTearDown(home.dispose);
      await home.loadHomeData();
      expect(home.journey?.isFinalized, isTrue);
      expect(home.hasActiveEncounter, isFalse);
      expect(home.visits, hasLength(1));
      expect(home.journey?.steps.where((s) => s.isService), hasLength(2));
      expect(home.errorMessage, isNull);
    },
  );

  test(
    'Late response from previous phone cannot overwrite selected patient',
    () async {
      final patients = FakePatients()..oldResponse = Completer<PatientModel?>();
      PatientSessionService().setPhone('old');
      final home = fakeHome(patients: patients);
      addTearDown(home.dispose);
      final pending = home.loadHomeData();
      await pumpEventQueue();
      home.switchPhone('new');
      await pumpEventQueue();
      patients.oldResponse!.complete(
        const PatientModel(id: 'old', fullName: 'Old patient', phone: 'old'),
      );
      await pending;
      expect(home.patient?.phone, 'new');
      expect(home.encounterSummary?.encounterId, 'new');
    },
  );

  test(
    'Failure loading services preserves visit and shows a sync error',
    () async {
      final encounters = FakeEncounters()..failPlan = true;
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      await home.loadHomeData();
      expect(home.encounterSummary, isNotNull);
      expect(home.journeyError, isNotNull);
    },
  );

  test('A queue update produces one notice; repeated snapshots do not duplicate it', () async {
    final encounters = FakeEncounters()
      ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Waiting')
      ..plan = null;
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();
    encounters.summary = summaryFixture(
      status: 'InQueue',
      queueStatus: 'Called',
    );
    await home.refreshJourney();
    final count = home.notices.length;
    expect(count, greaterThan(0));
    expect(home.notices.first.message, contains('Đã gọi'));
    await home.refreshJourney();
    expect(home.notices, hasLength(count));
    home.logout();
    expect(home.notices, isEmpty);
    expect(home.journey, isNull);
  });
}
