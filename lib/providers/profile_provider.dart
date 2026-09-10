import 'package:flutter/foundation.dart';
import '../models/patient_model.dart';
import '../services/patient_service.dart';
import '../services/patient_session_service.dart';

class ProfileProvider extends ChangeNotifier {
  final PatientService _patientService;
  final PatientSessionService _sessionService;

  ProfileProvider({
    PatientService? patientService,
    PatientSessionService? sessionService,
  })  : _patientService = patientService ?? PatientService(),
        _sessionService = sessionService ?? PatientSessionService();

  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  PatientModel? _patient;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  PatientModel? get patient => _patient;
  String get currentPhone => _sessionService.currentPhone;

  Future<void> loadProfile(String phone, {bool isRefresh = false}) async {
    if (phone.isEmpty) {
      _patient = null;
      _errorMessage = null;
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
      return;
    }

    try {
      _patient = await _patientService.searchPatientByPhone(phone);
      if (_patient != null) {
        _sessionService.setPatientId(_patient!.id);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Không thể tải hồ sơ bệnh nhân: ${e.toString()}';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void updatePhone(String newPhone) {
    _sessionService.setPhone(newPhone);
    loadProfile(newPhone);
  }

  Future<bool> saveProfileDetails({
    required String fullName,
    required String phone,
    String? dob,
    String? gender,
    String? address,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_patient != null && _patient!.id.isNotEmpty) {
        _patient = await _patientService.updatePatient(
          id: _patient!.id,
          fullName: fullName,
          phone: phone,
          dob: dob,
          gender: gender,
          address: address,
        );
      } else {
        _patient = await _patientService.createPatient(
          fullName: fullName,
          phone: phone,
          dob: dob,
          gender: gender,
          address: address,
        );
      }
      _sessionService.setPhone(phone);
      if (_patient != null) {
        _sessionService.setPatientId(_patient!.id);
      }
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi lưu thông tin: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _sessionService.clearSession();
    _patient = null;
    _errorMessage = null;
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  void retry() {
    loadProfile(_sessionService.currentPhone);
  }
}
