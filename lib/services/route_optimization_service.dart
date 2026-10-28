import 'dart:math';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/paraclinical_plan_model.dart';
import '../models/route_assistance_model.dart' show RouteComparison;
import '../models/route_optimization_model.dart';
import 'patient_session_service.dart';

class RouteOptimizationService {
  final ApiClient _api;
  final Map<String, String> _requestIds = {};
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

  Future<ParaclinicalPlanModel> optimize(
    String encounterId,
    String patientId,
  ) async {
    _checkPatient(patientId);
    final apiVersion = ApiClient.sessionVersion;
    final patientVersion = PatientSessionService().version;
    final requestId = _requestIds.putIfAbsent(encounterId, () {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    });
    final response = await _api.post<ParaclinicalPlanModel>(
      '${_path(encounterId)}/optimize',
      body: const {},
      headers: {'Idempotency-Key': requestId},
      fromJsonT: (json) =>
          ParaclinicalPlanModel.fromJson(json as Map<String, dynamic>),
    );
    if (apiVersion != ApiClient.sessionVersion ||
        patientVersion != PatientSessionService().version) {
      throw SessionChangedException();
    }
    _checkPatient(patientId);
    final plan = response.data;
    if (plan == null ||
        plan.id.isEmpty ||
        plan.encounterId != encounterId ||
        plan.status.toLowerCase() != 'active' ||
        !const {'Optimized', 'Adjusted'}.contains(plan.mode)) {
      throw ApiException(
        'Chưa xác nhận được lộ trình tối ưu đã áp dụng. Vui lòng cập nhật trạng thái.',
      );
    }
    _requestIds.remove(encounterId);
    return plan;
  }

  Future<RouteComparison> compare(String encounterId, String patientId) async {
    _checkPatient(patientId);
    final response = await _api.get<RouteComparison>(
      '${_path(encounterId)}/compare-preview',
      fromJsonT: (json) =>
          RouteComparison.fromJson(json as Map<String, dynamic>),
    );
    _checkPatient(patientId);
    if (response.data == null || response.data!.encounterId != encounterId) {
      throw ApiException('So sánh không khớp lượt khám.');
    }
    return response.data!;
  }
}
