import 'dart:async' hide TimeoutException;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/models/appointment_model.dart';
import 'package:flowcare_mobile/models/encounter_summary_model.dart';
import 'package:flowcare_mobile/models/follow_up_order_model.dart';
import 'package:flowcare_mobile/models/paraclinical_plan_model.dart';
import 'package:flowcare_mobile/models/patient_model.dart';
import 'package:flowcare_mobile/models/patient_visit_model.dart';
import 'package:flowcare_mobile/models/queue_ticket_model.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
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
  Future<PatientModel?> getMyProfile() async {
    final phone = PatientSessionService().patientId!;
    if (phone == 'old' && oldResponse != null) return oldResponse!.future;
    return PatientModel(id: phone, fullName: 'Bệnh nhân $phone', phone: phone);
  }
}

class FakeAppointments extends AppointmentService {
  @override
  Future<List<AppointmentModel>> getAppointmentsByPatient(
    String patientId,
  ) async => [];
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
  Object? summaryError, planError, historyError, activeError;
  @override
  Future<List<PatientVisitModel>?> getPatientHistory(String patientId) async {
    if (historyError != null) throw historyError!;
    return [
      PatientVisitModel(
        encounterId: patientId,
        serviceTypeName: 'Khám kiểm thử',
        status: summary.encounterStatus,
        createdAt: DateTime.parse('2026-10-12T00:00:00Z'),
      ),
    ];
  }

  @override
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(
    String patientId,
  ) async {
    if (activeError != null) throw activeError!;
    return null;
  }

  @override
  Future<EncounterSummaryModel?> getEncounterStatusSummary(
    String encounterId,
  ) async {
    if (summaryError != null) throw summaryError!;
    return summaryFixture(
      status: summary.encounterStatus,
      queueStatus: summary.queueStatus ?? 'Waiting',
      encounterId: encounterId,
      phone: encounterId,
      nursingIntake: summary.nursingIntake,
      nursingComplete: false,
    );
  }

  @override
  Future<ParaclinicalPlanModel?> getParaclinicalPlan(String encounterId) async {
    if (failPlan) throw StateError('Offline');
    if (planError != null) throw planError!;
    return plan;
  }
}

class FakeRealtime extends PatientRealtimeService {
  PatientEventCallback? callback;
  void Function(bool)? connectionChanged;
  @override
  Future<void> connect({
    required String encounterId,
    required PatientEventCallback onEvent,
    required void Function(bool) onConnectionChanged,
  }) async {
    callback = onEvent;
    connectionChanged = onConnectionChanged;
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
  setUp(
    () => PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    ),
  );
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
    'Late response from previous login cannot overwrite the new patient',
    () async {
      final patients = FakePatients()..oldResponse = Completer<PatientModel?>();
      PatientSessionService().bindPatient(
        patientId: 'old',
        userName: 'old.test',
      );
      final home = fakeHome(patients: patients);
      final pending = home.loadHomeData();
      await pumpEventQueue();
      home.dispose();
      PatientSessionService().bindPatient(
        patientId: 'new',
        userName: 'new.test',
      );
      final newHome = fakeHome();
      addTearDown(newHome.dispose);
      await newHome.loadHomeData();
      await pumpEventQueue();
      patients.oldResponse!.complete(
        const PatientModel(id: 'old', fullName: 'Old patient', phone: 'old'),
      );
      await pending;
      expect(newHome.patient?.phone, 'new');
      expect(home.patient, isNull);
      expect(newHome.encounterSummary?.encounterId, 'new');
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

  test('Network failure preserves the last successful route and timestamp, then recovers', () async {
    final encounters = FakeEncounters()
      ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Waiting')
      ..plan = ParaclinicalPlanModel.fromJson(activeTimedPlanJson());
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();
    final timestamp = home.lastUpdatedAt;
    final plan = home.paraclinicalPlan;
    encounters.summaryError = NetworkException();
    await home.refreshJourney();
    expect(home.journey, isNotNull);
    expect(home.paraclinicalPlan, same(plan));
    expect(home.lastUpdatedAt, timestamp);
    expect(home.isJourneyStale, isTrue);
    expect(home.isJourneyOffline, isTrue);
    encounters.summaryError = null;
    await home.refreshJourney();
    expect(home.isJourneyStale, isFalse);
    expect(home.isJourneyOffline, isFalse);
    expect(home.journeyError, isNull);
    expect(home.lastUpdatedAt!.isBefore(timestamp!), isFalse);
  });

  test('A failed plan refresh cannot publish a new summary with an old route as fresh', () async {
    final encounters = FakeEncounters()
      ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Waiting')
      ..plan = ParaclinicalPlanModel.fromJson(activeTimedPlanJson());
    final home = fakeHome(encounters: encounters);
    addTearDown(home.dispose);
    await home.loadHomeData();
    final timestamp = home.lastUpdatedAt;
    final oldSummary = home.encounterSummary;
    encounters.summary = summaryFixture(status: 'Finalized');
    encounters.planError = TimeoutException();
    await home.refreshJourney();
    expect(home.encounterSummary, same(oldSummary));
    expect(home.lastUpdatedAt, timestamp);
    expect(home.isJourneyOffline, isTrue);
    expect(home.isJourneyStale, isTrue);
    encounters.planError = null;
    await home.refreshJourney();
    expect(home.journey!.isFinalized, isTrue);
    expect(home.isJourneyStale, isFalse);
  });

  test(
    'Resuming and reloading home offline keeps the selected visit and route',
    () async {
      final encounters = FakeEncounters();
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      await home.loadHomeData();
      final timestamp = home.lastUpdatedAt;
      encounters.historyError = NetworkException();
      encounters.activeError = NetworkException();
      encounters.summaryError = NetworkException();
      await home.loadHomeData(isRefresh: true);
      expect(home.visits, hasLength(1));
      expect(home.journey!.summary.encounterId, 'patient');
      expect(home.lastUpdatedAt, timestamp);
      expect(home.isJourneyOffline, isTrue);
    },
  );

  test(
    'Manual refresh also reports offline data for a finalized history visit',
    () async {
      final encounters = FakeEncounters();
      final home = fakeHome(encounters: encounters);
      addTearDown(home.dispose);
      await home.loadHomeData();
      final timestamp = home.lastUpdatedAt;
      encounters.summaryError = NetworkException();
      await home.refreshJourney(includeFinalized: true);
      expect(home.journey!.isFinalized, isTrue);
      expect(home.lastUpdatedAt, timestamp);
      expect(home.isJourneyOffline, isTrue);
      encounters.summaryError = null;
      // Periodic retries can recover even when the selected visit has ended.
      await home.refreshJourney();
      expect(home.isJourneyOffline, isFalse);
    },
  );

  test('Server errors and realtime transport loss do not claim the device is offline', () async {
    final encounters = FakeEncounters()
      ..summary = summaryFixture(status: 'InQueue', queueStatus: 'Waiting')
      ..plan = null;
    final realtime = FakeRealtime();
    final home = fakeHome(encounters: encounters, realtime: realtime);
    addTearDown(home.dispose);
    await home.loadHomeData();
    home.startUpdates();
    await pumpEventQueue();
    realtime.connectionChanged!(false);
    expect(home.isRealtimeConnected, isFalse);
    expect(home.isJourneyOffline, isFalse);
    expect(home.isJourneyStale, isFalse);
    encounters.summaryError = ServerException('Server error', statusCode: 500);
    await home.refreshJourney();
    expect(home.isJourneyStale, isTrue);
    expect(home.isJourneyOffline, isFalse);
    home.logout();
    expect(home.lastUpdatedAt, isNull);
    expect(home.isJourneyStale, isFalse);
    expect(home.isJourneyOffline, isFalse);
  });

  test('First partial snapshot has no successful update time', () async {
    final home = fakeHome(
      encounters: FakeEncounters()..planError = NetworkException(),
    );
    addTearDown(home.dispose);
    await home.loadHomeData();
    expect(home.encounterSummary, isNotNull);
    expect(home.lastUpdatedAt, isNull);
    expect(home.isJourneyStale, isTrue);
  });
}
