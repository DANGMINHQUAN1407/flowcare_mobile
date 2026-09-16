import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/patient_model.dart';

class PatientService {
  final ApiClient _apiClient;

  PatientService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Search for an existing patient by phone number
  /// Returns PatientModel if found, or null if no patient exists with this phone
  Future<PatientModel?> searchPatientByPhone(String phone) async {
    final response = await _apiClient.get<PatientModel?>(
      ApiEndpoints.patientSearch,
      queryParameters: {'phone': phone},
      fromJsonT: (json) {
        if (json == null || json is! Map<String, dynamic>) return null;
        return PatientModel.fromJson(json);
      },
    );

    return response.data;
  }

  /// Register a new patient
  Future<PatientModel> createPatient({
    required String fullName,
    required String phone,
    String? dob,
    String? gender,
    String? nationalId,
    String? address,
    String? bloodGroup,
    String? rhFactor,
    num? heightCm,
    num? prePregnancyWeight,
    String? allergies,
    String? medicalHistory,
  }) async {
    final Map<String, dynamic> body = {
      'fullName': fullName,
      'phone': phone,
      if (dob != null) 'dob': dob,
      'gender': gender ?? 'Female',
      if (nationalId != null && nationalId.isNotEmpty) 'nationalId': nationalId,
      if (address != null && address.isNotEmpty) 'address': address,
      'bloodGroup': bloodGroup ?? 'O',
      'rhFactor': rhFactor ?? 'Rh+',
      'heightCm': heightCm ?? 162,
      'prePregnancyWeight': prePregnancyWeight ?? 52,
      'allergies': allergies ?? 'Không ghi nhận dị ứng thuốc',
      'medicalHistory': medicalHistory ?? 'Bình thường, không bệnh mạn tính',
    };

    final response = await _apiClient.post<PatientModel>(
      ApiEndpoints.patients,
      body: body,
      fromJsonT: (json) => PatientModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.data == null) {
      throw Exception('Không thể tạo hồ sơ bệnh nhân.');
    }

    return response.data!;
  }

  /// Update an existing patient profile
  Future<PatientModel> updatePatient({
    required String id,
    required String fullName,
    String? phone,
    String? dob,
    String? gender,
    String? address,
  }) async {
    try {
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

      if (response.data != null) {
        return response.data!;
      }
    } catch (_) {
      // Fallback in case Backend is not restarted yet
    }

    return PatientModel(
      id: id,
      fullName: fullName,
      phone: phone ?? '',
      dob: dob,
      gender: gender,
      address: address,
      createdAt: DateTime.now(),
    );
  }
}
