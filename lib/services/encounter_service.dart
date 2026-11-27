import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/encounter_summary_model.dart';
import '../models/journey_queue_status_model.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/patient_visit_model.dart';
import '../models/visit_summary_model.dart';

class EncounterService {
  final ApiClient _apiClient;

  EncounterService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Gets the patient-facing status summary for a specific encounter (both Walk-in and Online)
  /// BE Endpoint: GET /api/v1/encounters/{id}/status
  Future<EncounterSummaryModel?> getEncounterStatusSummary(
    String encounterId,
  ) async {
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
    } on NotFoundException {
      return null;
    }
  }

  /// Gets the active encounter summary for a patient
  /// BE Endpoint: GET /api/v1/encounters/patient/{patientId}/active
  Future<EncounterSummaryModel?> getActiveEncounterByPatient(
    String patientId,
  ) async {
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
    } on NotFoundException {
      return null;
    }
  }

  Future<List<PatientVisitModel>?> getPatientHistory(String patientId) async {
    try {
      final response = await _apiClient.get<List<PatientVisitModel>>(
        ApiEndpoints.encounterHistoryByPatient(patientId),
        fromJsonT: (json) => (json as List)
            .whereType<Map<String, dynamic>>()
            .map(PatientVisitModel.fromJson)
            .toList(),
      );
      return response.data ?? [];
    } on NotFoundException {
      // Older servers still support a known encounter or an order-linked visit.
      return null;
    }
  }

  Future<ParaclinicalPlanModel?> getParaclinicalPlan(String encounterId) async {
    final response = await _apiClient.get<ParaclinicalPlanModel>(
      ApiEndpoints.paraclinicalPlan(encounterId),
      fromJsonT: (json) =>
          ParaclinicalPlanModel.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<VisitSummaryModel> getVisitSummary(String encounterId) async {
    final response = await _apiClient.get<VisitSummaryModel>(
      ApiEndpoints.myVisitSummary(encounterId),
      fromJsonT: (json) =>
          VisitSummaryModel.fromJson(json as Map<String, dynamic>),
    );
    final summary = response.data;
    if (summary == null || summary.encounterId != encounterId) {
      throw ApiException('Tóm tắt trả về không khớp với lượt khám đã chọn.');
    }
    return summary;
  }

  Future<JourneyQueueStatus?> getJourneyQueueStatus(String encounterId) async {
    final response = await _apiClient.get<JourneyQueueStatus>(
      ApiEndpoints.journeyStatus(encounterId),
      fromJsonT: (json) =>
          JourneyQueueStatus.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<DownloadedFile> downloadVisitAttachment(String attachmentId) =>
      _apiClient.download(
        '/attachments/${Uri.encodeComponent(attachmentId)}/download',
        queryParameters: const {'inline': false},
      );

  Future<List<Map<String, dynamic>>> getNotifications(
    String encounterId,
  ) async {
    final response = await _apiClient.get<List<Map<String, dynamic>>>(
      '/encounters/${Uri.encodeComponent(encounterId)}/notifications',
      fromJsonT: (json) => json is List
          ? json.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
    return response.data ?? [];
  }
}
