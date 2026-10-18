import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/patient_registration.dart';

class PatientLogin {
  final String token, patientId, userName;
  final DateTime expiresAt;
  final bool isDemo;
  final String? patientPhone;
  const PatientLogin({
    required this.token,
    required this.patientId,
    required this.userName,
    required this.expiresAt,
    this.isDemo = false,
    this.patientPhone,
  });
}

class AuthService {
  final ApiClient _client;
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<({String token, DateTime expiresAt, Map<String, dynamic> profile})>
  _authenticate(String userName, String password) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      requiresAuth: false,
      body: {'userName': userName.trim(), 'password': password},
      fromJsonT: (json) => Map<String, dynamic>.from(json as Map),
    );
    final token = response.data?['accessToken']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(
      response.data?['expiresAt']?.toString() ?? '',
    );
    if (token.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now())) {
      throw ApiException(
        'Phiên đăng nhập trả về không hợp lệ. Vui lòng thử lại.',
      );
    }
    // The provisional token is not shared until role and PatientId are verified.
    final profile = await _client.get<Map<String, dynamic>>(
      '/auth/me',
      requiresAuth: false,
      headers: {'Authorization': 'Bearer $token'},
      fromJsonT: (json) => Map<String, dynamic>.from(json as Map),
    );
    if (profile.data == null) {
      throw ApiException('Không xác minh được phiên đăng nhập.');
    }
    return (token: token, expiresAt: expiresAt, profile: profile.data!);
  }

  Future<PatientLogin> login(String userName, String password) async {
    final session = await _authenticate(userName, password);
    final profile = session.profile;
    final roles =
        (profile['roles'] as List?)?.map((r) => r.toString().toUpperCase()) ??
        [];
    final patientId = profile['patientId']?.toString() ?? '';
    if (!roles.contains('PATIENT')) {
      throw ForbiddenException(
        'Ứng dụng dành cho tài khoản bệnh nhân. Vui lòng dùng tài khoản Patient.',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(patientId) ||
        patientId == '00000000-0000-0000-0000-000000000000') {
      throw ForbiddenException(
        'Tài khoản chưa được liên kết hồ sơ bệnh nhân. Vui lòng liên hệ bệnh viện.',
      );
    }
    return PatientLogin(
      token: session.token,
      patientId: patientId,
      userName: profile['userName']?.toString() ?? userName.trim(),
      expiresAt: session.expiresAt,
    );
  }

  // Registration creates the account on BE. Login remains a separate step, so
  // a failed login/profile read can never cause the registration POST to replay.
  Future<String> register(PatientRegistration registration) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/register',
        requiresAuth: false,
        body: registration.toJson(),
        fromJsonT: (json) => Map<String, dynamic>.from(json as Map),
      );
      final userName = response.data?['userName']?.toString();
      final patientId = response.data?['patientId']?.toString() ?? '';
      if (userName != registration.phone.trim() ||
          !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
              .hasMatch(patientId) ||
          patientId == '00000000-0000-0000-0000-000000000000') {
        throw ApiException(
          'Chưa xác minh được tài khoản vừa tạo. Hãy thử đăng nhập bằng số '
          'điện thoại và mật khẩu vừa nhập trước khi đăng ký lại.',
        );
      }
      return userName!;
    } on ServerException catch (error) {
      final data = error.data;
      final errors = data is Map ? data['errors'] : null;
      final codes = errors is List
          ? errors.map((item) => item.toString()).toSet()
          : <String>{};
      if (codes.contains('PATIENT_LINK_VERIFICATION_REQUIRED')) {
        throw ApiException(
          'Số điện thoại đã có hồ sơ tại bệnh viện. Liên hệ quầy tiếp đón '
          'để xác minh và cấp tài khoản cho hồ sơ này.',
          statusCode: 409,
        );
      }
      if (error.statusCode == 409) {
        throw ApiException(
          'Tài khoản hoặc hồ sơ đã tồn tại. Hãy đăng nhập; nếu chưa được '
          'cấp tài khoản hoặc quên mật khẩu, liên hệ quầy tiếp đón.',
          statusCode: 409,
        );
      }
      throw ApiException(
        'Chưa xác nhận được việc tạo tài khoản. Hãy thử đăng nhập bằng số '
        'điện thoại và mật khẩu vừa nhập trước khi đăng ký lại.',
      );
    } on NetworkException {
      throw ApiException(
        'Mất kết nối khi đăng ký. Hãy thử đăng nhập bằng số điện thoại và '
        'mật khẩu vừa nhập trước khi đăng ký lại.',
      );
    } on TimeoutException {
      throw ApiException(
        'Đăng ký chưa có phản hồi. Hãy thử đăng nhập bằng số điện thoại và '
        'mật khẩu vừa nhập trước khi đăng ký lại.',
      );
    }
  }
}
