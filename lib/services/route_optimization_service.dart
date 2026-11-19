import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/route_optimization_model.dart';
import 'patient_session_service.dart';

class RouteOptimizationService {
  final ApiClient _api;
  RouteOptimizationService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  void close() => _api.close();
  void _checkPatient(String patientId) {
    final session = PatientSessionService();
    if (session.isDemo ||
        !session.isAuthenticated ||
        session.patientId != patientId) {
      throw ForbiddenException();
    }
  }

  String _path(String id) =>
      '/encounters/${Uri.encodeComponent(id)}/paraclinical-plan';

  Future<RouteOptimizationEligibility> eligibility(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final response = await _api.get<RouteOptimizationEligibility>(
      '${_path(encounterId)}/optimize/eligibility',
      fromJsonT: (json) =>
          RouteOptimizationEligibility.fromJson(json as Map<String, dynamic>),
    );
    _checkPatient(patientId);
    return response.data ??
        (throw ApiException('Chưa tải được điều kiện tối ưu.'));
  }

  Future<RouteOptimizationEligibility> requestOptimization(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final session = PatientSessionService().version;
    final response = await _api.post<RouteOptimizationEligibility>(
      '${_path(encounterId)}/optimize/request',
      fromJsonT: (json) =>
          RouteOptimizationEligibility.fromJson(json as Map<String, dynamic>),
    );
    if (session != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _checkPatient(patientId);
    return response.data ??
        (throw ApiException('Chưa tải được phương án tối ưu.'));
  }

  Future<ParaclinicalPlanModel> accept(
    String encounterId,
    String patientId,
    String proposedPlanId,
  ) async {
    _checkPatient(patientId);
    final session = PatientSessionService().version;
    final response = await _api.post<ParaclinicalPlanModel>(
      '${_path(encounterId)}/optimize',
      body: {'proposedPlanId': proposedPlanId},
      fromJsonT: (json) =>
          ParaclinicalPlanModel.fromJson(json as Map<String, dynamic>),
    );
    if (session != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _checkPatient(patientId);
    final plan = response.data;
    if (plan == null ||
        plan.id != proposedPlanId ||
        plan.encounterId != encounterId ||
        (plan.status != 'Active' &&
            !(plan.isProposed && plan.acceptedOfferSavedMinutes != null))) {
      throw ApiException('Chưa xác nhận được lộ trình đã áp dụng.');
    }
    return plan;
  }

  Future<RouteOptimizationEligibility> decline(
    String encounterId,
    String patientId,
    String proposedPlanId,
    String reason,
  ) async {
    final session = PatientSessionService().version;
    final latest = await eligibility(encounterId, patientId);
    if (session != PatientSessionService().version) {
      throw SessionChangedException();
    }
    if (!latest.canOptimize ||
        latest.proposedPlanId != proposedPlanId ||
        latest.offer?.id != proposedPlanId ||
        latest.offer?.encounterId != encounterId ||
        latest.expiresAt?.isAfter(DateTime.now()) == false) {
      throw ApiException(
        'Đề xuất đã thay đổi.',
        data: {
          'errors': ['OFFER_STALE'],
        },
      );
    }
    final response = await _api.post<RouteOptimizationEligibility>(
      '${_path(encounterId)}/optimize/decline',
      body: {'reason': reason.trim(), 'proposedPlanId': proposedPlanId},
      fromJsonT: (json) =>
          RouteOptimizationEligibility.fromJson(json as Map<String, dynamic>),
    );
    if (session != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _checkPatient(patientId);
    return response.data ??
        (throw ApiException('Chưa xác nhận được phản hồi.'));
  }
}
