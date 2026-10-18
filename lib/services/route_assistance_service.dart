import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/route_assistance_model.dart';
import 'patient_session_service.dart';

class RouteAssistanceService {
  final ApiClient _api;
  RouteAssistanceService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  void close() => _api.close();
  void _checkPatient(String patientId) {
    final session = PatientSessionService();
    if (session.isDemo ||
        session.patientId != patientId ||
        !session.isAuthenticated) {
      throw ForbiddenException();
    }
  }

  String _path(String id) => '/encounters/${Uri.encodeComponent(id)}';
  Future<AssistanceEligibility> eligibility(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final response = await _api.get<AssistanceEligibility>(
      '${_path(encounterId)}/assistance-requests/eligibility',
      fromJsonT: (json) =>
          AssistanceEligibility.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        (throw ApiException('Chưa có điều kiện hỗ trợ từ máy chủ.'));
  }

  Future<RouteAssistanceRequest?> status(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final response = await _api.get<RouteAssistanceRequest>(
      '${_path(encounterId)}/assistance-requests/status',
      fromJsonT: (json) =>
          RouteAssistanceRequest.fromJson(json as Map<String, dynamic>),
    );
    return _validate(response.data, encounterId, patientId);
  }

  Future<RouteAssistanceRequest> request(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final session = ApiClient.sessionVersion;
    final patientSession = PatientSessionService().version;
    final current = await eligibility(encounterId, patientId);
    if (!current.canRequest || current.remainingOrders < 2) {
      throw ApiException(current.reason ?? 'Chưa đủ điều kiện gửi yêu cầu.');
    }
    if (session != ApiClient.sessionVersion ||
        patientSession != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _checkPatient(patientId);
    final response = await _api.post<RouteAssistanceRequest>(
      '${_path(encounterId)}/assistance-requests',
      body: {'reason': 'Nhờ hỗ trợ tối ưu các y lệnh còn lại trong lượt khám.'},
      fromJsonT: (json) =>
          RouteAssistanceRequest.fromJson(json as Map<String, dynamic>),
    );
    return _validate(response.data, encounterId, patientId) ??
        (throw ApiException('Chưa xác nhận được yêu cầu đã gửi.'));
  }

  Future<RouteComparison> compare(String encounterId, String patientId) async {
    _checkPatient(patientId);
    final response = await _api.get<RouteComparison>(
      '${_path(encounterId)}/paraclinical-plan/compare-preview',
      fromJsonT: (json) =>
          RouteComparison.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null || response.data!.encounterId != encounterId) {
      throw ApiException('So sánh không khớp lượt khám.');
    }
    return response.data!;
  }

  RouteAssistanceRequest? _validate(
    RouteAssistanceRequest? row,
    String encounterId,
    String patientId,
  ) {
    if (row != null &&
        (row.encounterId != encounterId ||
            row.patientId != patientId ||
            row.id.isEmpty)) {
      throw ApiException('Yêu cầu hỗ trợ không khớp hồ sơ bệnh nhân.');
    }
    return row;
  }
}
