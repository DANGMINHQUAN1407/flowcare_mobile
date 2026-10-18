import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/models/route_assistance_model.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/services/route_assistance_service.dart';

import 'fixtures/route_assistance_fixtures.dart';

http.Response ok(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
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
  RouteAssistanceService service(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final result = RouteAssistanceService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient(handler),
      ),
    );
    addTearDown(result.close);
    return result;
  }

  test(
    'checks fresh eligibility then posts once under the real Patient session',
    () async {
      final calls = <http.Request>[];
      final client = service((r) async {
        calls.add(r);
        return ok(
          r.method == 'POST' ? assistanceJson() : eligibilityJson(),
          status: r.method == 'POST' ? 201 : 200,
        );
      });
      final result = await client.request('visit', 'patient');
      expect(result.status, 'Pending');
      expect(calls.map((r) => r.method), ['GET', 'POST']);
      expect(
        calls.last.url.path,
        '/api/v1/encounters/visit/assistance-requests',
      );
      expect(
        calls.every(
          (r) => r.headers['authorization'] == 'Bearer patient.token.test',
        ),
        isTrue,
      );
    },
  );
  test('fewer than two orders or an open request prevents POST', () async {
    for (final eligibility in [
      eligibilityJson(count: 1, canRequest: false),
      eligibilityJson(canRequest: false),
    ]) {
      final methods = <String>[];
      final client = service((r) async {
        methods.add(r.method);
        return ok(eligibility);
      });
      await expectLater(
        client.request('visit', 'patient'),
        throwsA(isA<ApiException>()),
      );
      expect(methods, ['GET']);
    }
  });
  test('demo and another patient cannot use support APIs', () async {
    var calls = 0;
    final client = service((r) async {
      calls++;
      return ok(null);
    });
    await expectLater(
      client.status('visit', 'other'),
      throwsA(isA<ForbiddenException>()),
    );
    PatientSessionService().bindPatient(
      patientId: 'patient',
      userName: 'demo',
      isDemo: true,
    );
    await expectLater(
      client.request('visit', 'patient'),
      throwsA(isA<ForbiddenException>()),
    );
    expect(calls, 0);
  });
  test('mismatched status record cannot be displayed as the current patient request', () async {
    final client = service((r) async => ok(assistanceJson(patientId: 'other')));
    await expectLater(
      client.status('visit', 'patient'),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'lost POST response is surfaced and never automatically replayed',
    () async {
      var writes = 0;
      final client = service((r) async {
        if (r.method == 'POST') {
          writes++;
          throw http.ClientException('lost response');
        }
        return ok(eligibilityJson());
      });
      await expectLater(
        client.request('visit', 'patient'),
        throwsA(isA<NetworkException>()),
      );
      expect(writes, 1);
    },
  );
  test(
    'comparison parses shared estimates and never invents savings',
    () async {
      final client = service((r) async => ok(comparisonJson(improved: false)));
      final result = await client.compare('visit', 'patient');
      expect(result.savedMinutes, 0);
      expect(result.baseline.total, result.optimized.total);
      final bad = comparisonJson(improved: false)..['savedMinutes'] = 15;
      expect(() => RouteComparison.fromJson(bad), throwsFormatException);
    },
  );
  test('Resolved alone is not Applied; proof requires the linked plan and timestamp', () {
    expect(
      RouteAssistanceRequest.fromJson(assistanceJson(status: 'Resolved'))
          .isApplied,
      isFalse,
    );
    expect(
      RouteAssistanceRequest.fromJson(
        assistanceJson(status: 'Resolved', route: 'Applied'),
      ).isApplied,
      isTrue,
    );
    final bad = assistanceJson(status: 'Resolved', route: 'Applied')
      ..remove('appliedAt');
    expect(RouteAssistanceRequest.fromJson(bad).isApplied, isFalse);
  });
}
