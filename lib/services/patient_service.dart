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
    } on PasswordChangeRequiredException {
      rethrow;
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
    String? fullName,
    String? dob,
    String? gender,
    String? address,
  }) async {
    final session = PatientSessionService();
    final id = session.patientId;
    final version = session.version;
    if (id == null || id.isEmpty) throw UnauthorizedException();
    final response = await _apiClient.put<PatientModel>(
      '/patients/me',
      body: {
        'fullName': ?fullName,
        'dob': ?dob,
        'gender': ?gender,
        'address': ?address,
      },
      fromJsonT: (json) => PatientModel.fromJson(json as Map<String, dynamic>),
    );
    if (version != session.version) throw SessionChangedException();
    final patient = response.data;
    if (patient == null || patient.id != id) {
      throw ApiException('Máy chủ chưa xác nhận lưu hồ sơ.');
    }
    return patient;
  }
}
