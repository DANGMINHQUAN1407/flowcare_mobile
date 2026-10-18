import 'dart:convert';
import 'dart:io';

import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/utils/hospital_time.dart';
import 'package:flowcare_mobile/models/patient_journey_model.dart';
import 'package:flowcare_mobile/services/encounter_service.dart';
import 'package:flowcare_mobile/services/auth_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

/// Read-only check of the same API/models used by the mobile journey screen.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError(
      'Usage: dart run tool/mobile_journey_probe.dart API_BASE_URL [yyyy-MM-dd] (set FLOWCARE_PATIENT_USERNAME and FLOWCARE_PATIENT_PASSWORD)',
    );
  }
  final client = ApiClient(baseUrl: args[0]);
  final userName = Platform.environment['FLOWCARE_PATIENT_USERNAME'];
  final password = Platform.environment['FLOWCARE_PATIENT_PASSWORD'];
  if (userName == null || password == null) {
    throw ArgumentError(
      'Patient credentials are required in environment variables.',
    );
  }
  final login = await AuthService(client: client).login(userName, password);
  ApiClient.setAuthToken(login.token);
  PatientSessionService().bindPatient(
    patientId: login.patientId,
    userName: login.userName,
  );
  final encounters = EncounterService(apiClient: client);
  final visits = await encounters.getPatientHistory(login.patientId);
  if (visits == null) {
    throw StateError('Restart the backend with the patient history endpoint.');
  }
  final selected = visits
      .where(
        (v) =>
            args.length < 2 ||
            hospitalTime(v.visitTime, pattern: 'yyyy-MM-dd') == args[1],
      )
      .firstOrNull;
  if (selected == null) {
    throw StateError('No visit matches the requested date.');
  }
  final summary = await encounters.getEncounterStatusSummary(
    selected.encounterId,
  );
  if (summary == null) throw StateError('Visit summary was not found.');
  final plan = await encounters.getParaclinicalPlan(selected.encounterId);
  final journey = PatientJourney.build(summary, plan);
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'visitDate': hospitalTime(selected.visitTime, pattern: 'yyyy-MM-dd'),
      'status': summary.encounterStatus,
      'queueStatus': summary.queueStatus,
      'isFinalized': journey.isFinalized,
      'currentStep': journey.currentStep?.title,
      'resolvedSteps': journey.resolvedCount,
      'totalSteps': journey.steps.length,
      'planStatus': plan?.status,
      'services': plan?.steps
          .map(
            (s) => {
              'name': s.serviceTypeName,
              'status': s.status,
              'room': s.roomName,
            },
          )
          .toList(),
    }),
  );
  ApiClient.setAuthToken(null);
  PatientSessionService().clearSession();
  client.close();
}
