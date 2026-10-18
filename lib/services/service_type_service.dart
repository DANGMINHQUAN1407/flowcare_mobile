import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/service_type_model.dart';

class ServiceTypeService {
  final ApiClient _apiClient;

  ServiceTypeService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Gets the list of medical examination services from backend.
  /// Permission and transport failures propagate to the screen.
  Future<List<ServiceTypeModel>> getServiceTypes() async {
    final response = await _apiClient.get<List<ServiceTypeModel>>(
      ApiEndpoints.serviceTypes,
      fromJsonT: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((item) => ServiceTypeModel.fromJson(item))
              .toList();
        }
        return <ServiceTypeModel>[];
      },
    );
    return response.data ?? <ServiceTypeModel>[];
  }
}
