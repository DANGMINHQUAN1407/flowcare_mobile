import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowcare_mobile/core/network/api_client.dart';
import 'package:flowcare_mobile/services/patient_chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => ApiClient.setAuthToken(null));

  test('sends an authenticated patient question and reads the reply', () async {
    ApiClient.setAuthToken('patient-token');
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/patients/me/chat');
        expect(request.headers['authorization'], 'Bearer patient-token');
        expect(jsonDecode(request.body), {
          'message': 'Tôi khám ở đâu?',
          'sessionId': 'session-1',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'answer': 'Phòng 1',
              'emergency': true,
              'sources': [
                {'doc': 'Hướng dẫn', 'snippet': 'Thông tin'},
              ],
              'cards': [
                {'type': 'queue', 'number': 3},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final reply = await PatientChatService(client: client)
        .ask('Tôi khám ở đâu?', 'session-1');
    expect(reply.answer, 'Phòng 1');
    expect(reply.emergency, isTrue);
    expect(reply.cards.single['number'], 3);
    expect(reply.sources.single['doc'], 'Hướng dẫn');
    client.close();
  });
}
