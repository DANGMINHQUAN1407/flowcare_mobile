import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/route_optimization_service.dart';

void main() {
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'patient.test',
    );
    ApiClient.setAuthToken('patient.token.test');
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
  });
  test('optimization posts directly and returns an active route without a doctor approval call', () async {
    final calls = <http.Request>[];
    final service = RouteOptimizationService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient((r) async {
          calls.add(r);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'proposal',
                'encounterId': 'visit',
                'status': 'Active',
                'mode': 'Optimized',
                'steps': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(service.close);
    final plan = await service.accept('visit', 'patient', 'proposal');
    expect(plan.status, 'Active');
    expect(jsonDecode(calls.single.body), {'proposedPlanId': 'proposal'});
    expect(plan.mode, 'Optimized');
    expect(calls.single.method, 'POST');
    expect(
      calls.single.url.path,
      '/api/v1/encounters/visit/paraclinical-plan/optimize',
    );
    expect(calls.single.headers['authorization'], 'Bearer patient.token.test');
  });
  test('another patient cannot submit and a mismatched response cannot become this route', () async {
    final service = RouteOptimizationService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'proposal',
                'encounterId': 'other',
                'status': 'Active',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.accept('visit', 'other-patient', 'proposal'),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      service.accept('visit', 'patient', 'proposal'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a proposal response cannot be presented as an applied route', () async {
    final service = RouteOptimizationService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'proposal',
                'encounterId': 'visit',
                'status': 'Proposed',
                'mode': 'Optimized',
                'steps': [],
              },
            }),
            200,
          ),
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.accept('visit', 'patient', 'proposal'),
      throwsA(isA<ApiException>()),
    );
  });
}
