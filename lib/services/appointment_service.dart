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
    try {
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

      if (response.data != null && response.data!.isNotEmpty) {
        return response.data!;
      }
    } catch (_) {
      // Backend does not have /appointments/slots endpoint; generate clinic business hours slots dynamically
    }

    return _generateDefaultSlots(date);
  }

  List<AppointmentSlotModel> _generateDefaultSlots(String dateStr) {
    final targetDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final now = DateTime.now();

    final slotRanges = [
      (7, 30, 8, 30, '07:30 - 08:30'),
      (8, 30, 9, 30, '08:30 - 09:30'),
      (9, 30, 10, 30, '09:30 - 10:30'),
      (10, 30, 11, 30, '10:30 - 11:30'),
      (13, 30, 14, 30, '13:30 - 14:30'),
      (14, 30, 15, 30, '14:30 - 15:30'),
      (15, 30, 16, 30, '15:30 - 16:30'),
      (16, 30, 17, 30, '16:30 - 17:30'),
      (17, 30, 18, 30, '17:30 - 18:30'),
      (18, 30, 19, 30, '18:30 - 19:30'),
      (19, 30, 20, 30, '19:30 - 20:30'),
    ];

    return slotRanges.map((s) {
      final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, s.$1, s.$2);
      final endTime = DateTime(targetDate.year, targetDate.month, targetDate.day, s.$3, s.$4);
      final isAvailable = startTime.isAfter(now) || (targetDate.day != now.day);

      return AppointmentSlotModel(
        timeRange: s.$5,
        startTime: startTime,
        endTime: endTime,
        isAvailable: isAvailable,
      );
    }).toList();
  }

  /// Creates a new appointment
  Future<AppointmentModel> createAppointment({
    required String patientId,
    required String serviceTypeId,
    required DateTime scheduledTime,
    int status = 1, // Confirmed
    int source = 0, // Online
    String? followUpOrderId,
    String? doctorId,
    String? doctorScheduleId,
    String? departmentId,
  }) async {
    final Map<String, dynamic> body = {
      'patientId': patientId,
      'serviceTypeId': serviceTypeId,
      'scheduledTime': scheduledTime.toUtc().toIso8601String(),
      'status': status,
      'source': source,
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
      fromJsonT: (json) => AppointmentModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.data == null) {
      final msg = response.message;
      throw Exception(msg != null && msg.isNotEmpty ? msg : 'Không thể tạo lịch hẹn.');
    }

    return response.data!;
  }
}
