import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/models/patient_model.dart';
import 'package:flowcare_mobile/providers/profile_provider.dart';
import 'package:flowcare_mobile/services/patient_service.dart';
import 'package:flowcare_mobile/services/patient_session_service.dart';
import 'package:flowcare_mobile/widgets/patient_profile_editor.dart';

const id = 'e7ea7eca-203b-41ef-aa4c-af3566190a7a';
const patient = PatientModel(
  id: id,
  fullName: 'Nguyễn Thị A',
  phone: '0901234567',
  dob: '1997-07-18',
  gender: 'Female',
  address: 'Địa chỉ cũ',
);
void main() {
  setUp(() {
    PatientSessionService().bindPatient(patientId: id, userName: patient.phone);
    ApiClient.setAuthToken('patient-token');
  });
  tearDown(() {
    PatientSessionService().clearSession();
    ApiClient.setAuthToken(null);
  });
  testWidgets(
    'identity stays read-only for an existing visit while clearing the address sends only that field',
    (tester) async {
      final bodies = <Map>[];
      final provider = ProfileProvider(
        patientService: PatientService(
          apiClient: ApiClient(
            baseUrl: 'http://test/api/v1',
            client: MockClient((request) async {
              expect(request.url.path, '/api/v1/patients/me');
              bodies.add(jsonDecode(request.body) as Map);
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'id': id,
                    'fullName': patient.fullName,
                    'phone': patient.phone,
                    'address': null,
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => PatientProfileEditor(
                    patient: patient,
                    provider: provider,
                    identityLocked: true,
                  ),
                ),
                child: const Text('Sửa'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-full-name')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-gender')))
            .enabled,
        isFalse,
      );
      await tester.enterText(find.byKey(const Key('profile-address')), '');
      await tester.ensureVisible(find.text('Lưu hồ sơ'));
      await tester.tap(find.text('Lưu hồ sơ'));
      await tester.pumpAndSettle();
      expect(bodies, [
        {'address': ''},
      ]);
      expect(provider.errorMessage, isNull);
      expect(find.byType(PatientProfileEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
