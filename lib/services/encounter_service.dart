import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/encounter_summary_model.dart';

class EncounterService {
  final ApiClient _apiClient;

  EncounterService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Gets the patient-facing status summary for a specific encounter (both Walk-in and Online)
  /// BE Endpoint: GET /api/v1/encounters/{id}/status
  Future<EncounterSummaryModel?> getEncounterStatusSummary(String encounterId) async {
    if (encounterId.isEmpty) return null;
    try {
      final response = await _apiClient.get<EncounterSummaryModel?>(
        ApiEndpoints.encounterStatus(encounterId),
        fromJsonT: (json) {
          if (json == null || json is! Map<String, dynamic>) return null;
          return EncounterSummaryModel.fromJson(json);
        },
      );

      return response.data;
    } catch (_) {
      // If encounter not found or error, return null safely
      return null;
    }
  }

  /// Gets the active encounter summary for a patient
  /// BE Endpoint: GET /api/v1/encounters/patient/{patientId}/active
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(String patientId) async {
    if (patientId.isEmpty) return null;
    try {
      final response = await _apiClient.get<EncounterSummaryModel?>(
        ApiEndpoints.activeEncounterByPatient(patientId),
        fromJsonT: (json) {
          if (json == null || json is! Map<String, dynamic>) return null;
          return EncounterSummaryModel.fromJson(json);
        },
      );

      return response.data;
    } catch (_) {
      return null;
    }
  }
}
