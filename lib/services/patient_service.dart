import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/patient_model.dart';
import 'patient_session_service.dart';

class PatientService {
  final ApiClient _apiClient;
  PatientService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PatientModel?> getMyProfile() async {
    final session = PatientSessionService();
    final id = session.patientId;
    final version = session.version;
    if (id == null || id.isEmpty) throw UnauthorizedException();
    try {
      final response = await _apiClient.get<PatientModel>(
        '/patients/me',
        fromJsonT: (json) =>
            PatientModel.fromJson(json as Map<String, dynamic>),
      );
      final patient = response.data;
      if (version != session.version || session.patientId != id) {
        throw SessionChangedException();
      }
      if (patient == null || patient.id != id) {
        throw ApiException('Hồ sơ trả về không khớp tài khoản đang đăng nhập.');
      }
      return patient;
    } on ForbiddenException {
      throw ForbiddenException(
        'Không xác minh được quyền xem hồ sơ của bạn. Vui lòng đăng nhập lại; nếu vẫn lỗi, liên hệ bệnh viện.',
      );
    } on NotFoundException {
      throw NotFoundException(
        'Chưa tìm thấy hồ sơ liên kết với tài khoản. Vui lòng liên hệ quầy tiếp đón để kiểm tra.',
      );
    }
  }

  Future<PatientModel> updatePatient({
    required String id,
    required String fullName,
    String? phone,
    String? dob,
    String? gender,
    String? address,
  }) async {
    if (id != PatientSessionService().patientId) throw ForbiddenException();
    final response = await _apiClient.put<PatientModel>(
      '/patients/$id',
      body: {
        'fullName': fullName,
        'dob': ?dob,
        'gender': ?gender,
        'address': ?address,
      },
      fromJsonT: (json) => PatientModel.fromJson(json as Map<String, dynamic>),
    );
    final patient = response.data;
    if (patient == null || patient.id != id) {
      throw ApiException('Máy chủ chưa xác nhận lưu hồ sơ.');
    }
    return patient;
  }
}
