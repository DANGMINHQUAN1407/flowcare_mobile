import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/providers/profile_provider.dart';

const patientId = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
http.Response profile({
  String id = patientId,
  String address = 'Test address',
}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'id': id,
      'fullName': 'Patient profile test',
      'phone': '0900000000',
      'dob': '1997-07-18',
      'address': address,
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

  test('self-service updates use /patients/me and send only supplied fields, including an explicit address clear', () async {
    var calls = 0;
    final saved = await service((request) async {
      calls++;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/patients/me');
      expect(jsonDecode(request.body), {'address': ''});
      expect(request.headers['Authorization'], 'Bearer patient-token');
      return profile();
    }).updatePatient(address: '');
    expect(saved.id, patientId);
    expect(calls, 1);
  });

  test('locked identity errors preserve the code and an address-only save remains possible', () async {
    var calls = 0;
    final provider = ProfileProvider(
      patientService: service((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'errors': ['PATIENT_IDENTITY_LOCKED'],
            }),
            409,
          );
        }
        expect(jsonDecode(request.body), {'address': 'Địa chỉ mới'});
        return profile();
      }),
    );
    addTearDown(provider.dispose);
    expect(await provider.saveProfile(fullName: 'Changed identity'), isFalse);
    expect(provider.identityLocked, isTrue);
    expect(provider.errorMessage, contains('Liên hệ quầy'));
    expect(await provider.saveProfile(address: 'Địa chỉ mới'), isTrue);
    expect(calls, 2);
  });

  test('a late profile mutation response is never published to another patient session', () async {
    final pending = Completer<http.Response>();
    final write = service((_) => pending.future)
        .updatePatient(address: 'Updated');
    await pumpEventQueue();
    PatientSessionService().bindPatient(patientId: 'other', userName: 'other');
    pending.complete(profile());
    await expectLater(write, throwsA(isA<SessionChangedException>()));
  });

  test(
    'an older profile read cannot overwrite an acknowledged address update',
    () async {
      final pending = Completer<http.Response>();
      final provider = ProfileProvider(
        patientService: service((request) async {
          if (request.method == 'PUT') {
            return profile(address: 'Updated address');
          }
          return pending.future;
        }),
      );
      addTearDown(provider.dispose);
      final oldRead = provider.loadProfile(null);
      await pumpEventQueue();
      expect(await provider.saveProfile(address: 'Updated address'), isTrue);
      pending.complete(profile());
      await oldRead;
      expect(provider.patient!.address, 'Updated address');
      expect(provider.isLoading, isFalse);
    },
  );

  test('maps obstetric profile fields from canonical and encounter fallback keys', () async {
    final result = await service((_) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': patientId,
            'fullName': 'Patient profile test',
            'phone': '0900000000',
            'heightCm': 158,
            'gestationalAgeWeeks': 20,
            'gestationalAgeDays': 5,
            'paraCode': '4121',
            'lastMenstrualPeriod': '2026-11-11',
            'expectedDueDate': '2027-08-18',
            'obstetricHistory': ' ',
            'menstrualCycle': 'Đều (28 - 30 ngày)',
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }).getMyProfile();

    expect(result!.heightCm, 158);
    expect(result.gestationalWeeks, 20);
    expect(result.gestationalDays, 5);
    expect(result.para, '4121');
    expect(result.lmp, '2026-11-11');
    expect(result.edd, '2027-08-18');
    expect(result.obstetricHistory, isNull);
    expect(result.menstrualCycle, 'Đều (28 - 30 ngày)');
  });
}
