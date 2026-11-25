import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';

class PatientChatReply {
  final String answer;
  final bool emergency;
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> cards;

  PatientChatReply.fromJson(Map<String, dynamic> json)
    : answer = json['answer'] as String,
      emergency = json['emergency'] as bool? ?? false,
      sources = (json['sources'] as List? ?? []).cast<Map<String, dynamic>>(),
      cards = (json['cards'] as List? ?? []).cast<Map<String, dynamic>>();
}

class PatientChatService {
  final ApiClient _client;
  PatientChatService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<PatientChatReply> ask(String message, String sessionId) async {
    final response = await _client.post<PatientChatReply>(
      '/patients/me/chat',
      body: {'message': message, 'sessionId': sessionId},
      fromJsonT: (json) =>
          PatientChatReply.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException('Trợ lý chưa trả lời. Vui lòng thử lại.');
    }
    return response.data!;
  }
}
