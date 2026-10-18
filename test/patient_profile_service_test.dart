import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';

const patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
http.Response profile({String id = patientId}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'id': id,
      'fullName': 'Patient profile test',
      'phone': '0900000000',
      'dob': '1997-07-18',
      'address': 'Test address',
    },
  }),
  200,
);
PatientService service(Future<http.Response> Function(http.Request) handler) =>
    PatientService(
      apiClient: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient(handler),
      ),
    );

void main() {
  setUp(() {
    PatientSessionService().bindPatient(
      patientId: patientId,
      userName: 'patient.test',
    );
    ApiClient.setAuthToken('patient-token');
    ApiClient.onUnauthorized = null;
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
    ApiClient.onUnauthorized = null;
  });

  test(
    'reads /patients/me with the Patient token and no client-supplied identity',
    () async {
      var calls = 0;
      final result = await service((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/patients/me');
        expect(request.url.query, isEmpty);
        expect(request.headers['Authorization'], 'Bearer patient-token');
        return profile();
      }).getMyProfile();
      expect(calls, 1);
      expect(result!.id, patientId);
      expect(result.fullName, 'Patient profile test');
      expect(result.dob, '1997-07-18');
    },
  );

  test(
    'a mismatched profile is rejected instead of showing another patient',
    () async {
      await expectLater(
        service((_) async => profile(id: 'another-patient')).getMyProfile(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('không khớp'),
          ),
        ),
      );
    },
  );

  for (final status in [403, 404]) {
    test(
      '$status does not retry or fall back to the staff patient endpoint',
      () async {
        var calls = 0;
        await expectLater(
          service((request) async {
            calls++;
            expect(request.url.path, '/api/v1/patients/me');
            return http.Response('{}', status);
          }).getMyProfile(),
          throwsA(
            status == 403
                ? isA<ForbiddenException>()
                : isA<NotFoundException>(),
          ),
        );
        expect(calls, 1);
        expect(ApiClient.authToken, 'patient-token');
      },
    );
  }

  test(
    '401 clears the expired token without repeating the profile read',
    () async {
      var calls = 0, expired = 0;
      ApiClient.onUnauthorized = () => expired++;
      await expectLater(
        service((_) async {
          calls++;
          return http.Response('{}', 401);
        }).getMyProfile(),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(calls, 1);
      expect(expired, 1);
      expect(ApiClient.authToken, isNull);
    },
  );

  test('a late response cannot cross patient sessions even if the token was not replaced yet', () async {
    final pending = Completer<http.Response>();
    final read = service((_) => pending.future).getMyProfile();
    await pumpEventQueue();
    PatientSessionService().bindPatient(
      patientId: 'new-patient',
      userName: 'other',
    );
    pending.complete(profile());
    await expectLater(read, throwsA(isA<SessionChangedException>()));
  });

  test('a signed-out session never sends a profile request', () async {
    PatientSessionService().clearSession();
    var calls = 0;
    await expectLater(
      service((_) async {
        calls++;
        return profile();
      }).getMyProfile(),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(calls, 0);
  });
}
