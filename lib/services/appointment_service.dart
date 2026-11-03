import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/appointment_model.dart';
import '../core/network/api_exceptions.dart';

class AppointmentService {
  final ApiClient _apiClient;

  AppointmentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Gets all appointments for a specific patient
  Future<List<AppointmentModel>> getAppointmentsByPatient(
    String patientId,
  ) async {
    final response = await _apiClient.get<List<AppointmentModel>>(
      ApiEndpoints.appointmentByPatient(patientId),
      fromJsonT: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((item) => AppointmentModel.fromJson(item))
              .toList();
        }
        return <AppointmentModel>[];
      },
    );

    return response.data ?? <AppointmentModel>[];
  }

  /// Gets available time slots for a given service type and date
  /// [serviceTypeId] UUID of the service
  /// [date] Date formatted as yyyy-MM-dd
  Future<List<AppointmentSlotModel>> getAvailableSlots({
    required String serviceTypeId,
    required String date,
  }) async {
    final response = await _apiClient.get<List<AppointmentSlotModel>>(
      ApiEndpoints.appointmentSlots,
      queryParameters: {'serviceTypeId': serviceTypeId, 'date': date},
      fromJsonT: (json) => (json as List)
          .whereType<Map<String, dynamic>>()
          .map(AppointmentSlotModel.fromJson)
          .toList(),
    );
    return response.data ?? [];
  }

  /// Creates a new appointment
  Future<AppointmentModel> createAppointment({
    required String patientId,
    required String serviceTypeId,
    required DateTime scheduledTime,
    String? followUpOrderId,
    String? doctorId,
    String? doctorScheduleId,
    String? departmentId,
  }) async {
    final Map<String, dynamic> body = {
      'patientId': patientId,
      'serviceTypeId': serviceTypeId,
      'scheduledTime': scheduledTime.toUtc().toIso8601String(),
    };

    if (followUpOrderId != null && followUpOrderId.isNotEmpty) {
      body['followUpOrderId'] = followUpOrderId;
    }
    if (doctorId != null && doctorId.isNotEmpty) {
      body['doctorId'] = doctorId;
    }
    if (doctorScheduleId != null && doctorScheduleId.isNotEmpty) {
      body['doctorScheduleId'] = doctorScheduleId;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      body['departmentId'] = departmentId;
    }

    final response = await _apiClient.post<AppointmentModel>(
      ApiEndpoints.appointments,
      body: body,
      fromJsonT: (json) =>
          AppointmentModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.data == null) {
      final msg = response.message;
      throw Exception(
        msg != null && msg.isNotEmpty ? msg : 'Không thể tạo lịch hẹn.',
      );
    }

    return response.data!;
  }

  Future<AppointmentModel> cancelAppointment(
    String id, {
    String? reason,
  }) async {
    if (id.isEmpty || (reason?.trim().length ?? 0) > 500) {
      throw ValidationException('Lý do hủy lịch tối đa 500 ký tự.');
    }
    final response = await _apiClient.post<AppointmentModel>(
      '/appointments/${Uri.encodeComponent(id)}/cancel',
      body: {
        'reason': reason?.trim().isNotEmpty == true ? reason!.trim() : null,
      },
      fromJsonT: (json) =>
          AppointmentModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data?.id != id ||
        response.data?.status.toLowerCase() != 'cancelled') {
      throw ApiException(
        'Máy chủ chưa xác nhận hủy đúng lịch hẹn. Tải lại danh sách trước khi thử lại.',
      );
    }
    return response.data!;
  }
}
