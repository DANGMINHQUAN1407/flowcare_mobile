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
    final plan = await service.optimize('visit', 'patient');
    expect(plan.status, 'Active');
    expect(
      calls.single.headers['Idempotency-Key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
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
      service.optimize('visit', 'other-patient'),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      service.optimize('visit', 'patient'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a failed response keeps the request key; a successful new tap gets a new key', () async {
    final keys = <String?>[];
    final service = RouteOptimizationService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient((r) async {
          keys.add(r.headers['Idempotency-Key']);
          if (keys.length == 1) throw http.ClientException('Lost response');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'active',
                'encounterId': 'visit',
                'status': 'Active',
                'mode': 'Optimized',
                'steps': [],
              },
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.optimize('visit', 'patient'),
      throwsA(isA<ApiException>()),
    );
    await service.optimize('visit', 'patient');
    await service.optimize('visit', 'patient');
    expect(keys[0], keys[1]);
    expect(keys[1], isNot(keys[2]));
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
      service.optimize('visit', 'patient'),
      throwsA(isA<ApiException>()),
    );
  });
}
