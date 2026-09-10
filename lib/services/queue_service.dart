import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/queue_ticket_model.dart';

class QueueService {
  final ApiClient _apiClient;

  QueueService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Gets the queue ticket issued for a specific encounter
  Future<QueueTicketModel?> getQueueTicketByEncounter(String encounterId) async {
    try {
      final response = await _apiClient.get<QueueTicketModel?>(
        ApiEndpoints.queueTicketByEncounter(encounterId),
        fromJsonT: (json) {
          if (json == null || json is! Map<String, dynamic>) return null;
          return QueueTicketModel.fromJson(json);
        },
      );

      return response.data;
    } catch (_) {
      return null;
    }
  }
}
