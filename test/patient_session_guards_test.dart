import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/core/network/api_exceptions.dart';

void main() {
  tearDown(() => ApiClient.setAuthToken(null));

  for (final method in ['POST', 'PUT', 'PATCH']) {
    test(
      'a restricted read-only session blocks $method before sending',
      () async {
        ApiClient.setAuthToken('restricted-token', readOnlyDemo: true);
        var requests = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            requests++;
            return http.Response(
              jsonEncode({'success': true, 'data': {}}),
              200,
            );
          }),
        );
        final future = switch (method) {
          'PUT' => api.put('/patients/id'),
          'PATCH' => api.patch('/notifications/id/read'),
          _ => api.post('/appointments'),
        };
        await expectLater(future, throwsA(isA<ForbiddenException>()));
        expect(requests, 0);
        api.close();
      },
    );
  }
}
