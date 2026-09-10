import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final ApiClient _apiClient;

  AppointmentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Checks if the patient identified by phone has an active online appointment
  Future<AppointmentCheckModel> checkAppointmentByPhone(String phone) async {
    final response = await _apiClient.get<AppointmentCheckModel>(
      ApiEndpoints.appointmentCheck,
      queryParameters: {'phone': phone},
      fromJsonT: (json) => AppointmentCheckModel.fromJson(json as Map<String, dynamic>),
    );

    return response.data ?? const AppointmentCheckModel(hasAppointment: false);
  }

  /// Gets all appointments for a specific patient
  Future<List<AppointmentModel>> getAppointmentsByPatient(String patientId) async {
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
      queryParameters: {
        'serviceTypeId': serviceTypeId,
        'date': date,
      },
      fromJsonT: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((item) => AppointmentSlotModel.fromJson(item))
              .toList();
        }
        return <AppointmentSlotModel>[];
      },
    );

    return response.data ?? <AppointmentSlotModel>[];
  }

  /// Creates a new appointment
  Future<AppointmentModel> createAppointment({
    required String patientId,
    required String serviceTypeId,
    required DateTime scheduledTime,
    int status = 1, // Confirmed
    int source = 0, // Online
  }) async {
    final response = await _apiClient.post<AppointmentModel>(
      ApiEndpoints.appointments,
      body: {
        'patientId': patientId,
        'serviceTypeId': serviceTypeId,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'status': status,
        'source': source,
      },
      fromJsonT: (json) => AppointmentModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.data == null) {
      final msg = response.message;
      throw Exception(msg != null && msg.isNotEmpty ? msg : 'Không thể tạo lịch hẹn.');
    }

    return response.data!;
  }
}
