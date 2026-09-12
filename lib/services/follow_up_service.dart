import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/follow_up_order_model.dart';

class FollowUpService {
  final ApiClient _apiClient;

  FollowUpService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Gets pending follow-up orders for a patient
  Future<List<FollowUpOrderModel>> getFollowUpOrdersByPatient(String patientId) async {
    try {
      final response = await _apiClient.get<List<FollowUpOrderModel>>(
        ApiEndpoints.followUpOrdersByPatient(patientId),
        fromJsonT: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((item) => FollowUpOrderModel.fromJson(item))
                .toList();
          }
          return <FollowUpOrderModel>[];
        },
      );

      return response.data ?? <FollowUpOrderModel>[];
    } catch (_) {
      // Fallback empty list if BE offline or patient has no orders
      return <FollowUpOrderModel>[];
    }
  }
}
